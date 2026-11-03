import CoreAudio
import Foundation

// WisprDuck Test Harness level meter. For each LABEL=pid it creates an
// unmuted, private process tap and prints the RMS level of that process's
// output as CSV:  epoch,LABEL1,LABEL2,...
// A value is a dBFS number, "silent" (the tap runs but the process plays
// nothing), or "none" (no tap yet). Taps need System Audio Recording, so
// this binary runs inside an app bundle (com.wisprduck.testharness).
//
// Usage: Meter <seconds> <interval seconds> LABEL=pid ...

setvbuf(stdout, nil, _IOLBF, 0)
let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3, let seconds = Double(arguments[0]), let interval = Double(arguments[1]) else {
    print("usage: Meter <seconds> <interval> LABEL=pid ...")
    exit(2)
}
let targets: [(label: String, pid: pid_t)] = arguments.dropFirst(2).compactMap { argument in
    let parts = argument.split(separator: "=")
    guard parts.count == 2, let pid = pid_t(parts[1]) else { return nil }
    return (String(parts[0]), pid)
}

func processObject(for pid: pid_t) -> AudioObjectID? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var pid = pid
    var object = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address,
        UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object
    )
    return status == noErr && object != kAudioObjectUnknown ? object : nil
}

final class Meter {
    let label: String
    let pid: pid_t
    private let lock = NSLock()
    private var sumSquares = 0.0
    private var sampleCount = 0
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var running = false

    init(label: String, pid: pid_t) {
        self.label = label
        self.pid = pid
    }

    /// Starts the tap once the process is known to Core Audio. Safe to call repeatedly.
    func startIfNeeded() {
        guard !running, let object = processObject(for: pid) else { return }

        let description = CATapDescription(stereoMixdownOfProcesses: [object])
        description.muteBehavior = .unmuted
        description.isPrivate = true
        let tapUUID = UUID()
        description.uuid = tapUUID
        guard AudioHardwareCreateProcessTap(description, &tapID) == noErr else { return }

        // A tap-only device: with the output device as a sub-device, a duplex
        // interface (e.g. a Scarlett 2i2) would also run its mic input, and
        // WisprDuck's trigger-all mode would see this meter as a mic user.
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "WisprDuck meter \(label)",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUUID.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        guard AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID) == noErr else {
            stop()
            return
        }

        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, DispatchQueue(label: "meter.\(label)")) {
            [weak self] _, input, _, _, _ in
            // The tap is the only input stream of the device.
            let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard let tap = inputs.last, let data = tap.mData else { return }
            let count = Int(tap.mDataByteSize) / MemoryLayout<Float>.size
            let samples = data.assumingMemoryBound(to: Float.self)
            var sum = 0.0
            for index in 0..<count { sum += Double(samples[index] * samples[index]) }
            self?.add(sum: sum, count: count)
        }
        guard status == noErr, AudioDeviceStart(aggregateID, ioProcID) == noErr else {
            stop()
            return
        }
        running = true
    }

    private func add(sum: Double, count: Int) {
        lock.lock()
        sumSquares += sum
        sampleCount += count
        lock.unlock()
    }

    func takeReading() -> String {
        lock.lock()
        defer {
            sumSquares = 0
            sampleCount = 0
            lock.unlock()
        }
        guard running else { return "none" }
        guard sampleCount > 0, sumSquares > 0 else { return "silent" }
        return String(format: "%.1f", 10 * log10(sumSquares / Double(sampleCount)))
    }

    func stop() {
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        running = false
    }
}

let meters = targets.map { Meter(label: $0.label, pid: $0.pid) }
print((["epoch"] + meters.map(\.label)).joined(separator: ","))
let deadline = Date().addingTimeInterval(seconds)
while Date() < deadline {
    meters.forEach { $0.startIfNeeded() }
    Thread.sleep(forTimeInterval: interval)
    let readings = meters.map { $0.takeReading() }
    print(([String(format: "%.3f", Date().timeIntervalSince1970)] + readings).joined(separator: ","))
}
meters.forEach { $0.stop() }
