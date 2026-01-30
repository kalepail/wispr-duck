import Foundation
import CoreAudio

/// Manages a single Core Audio process tap: intercepts one process's audio output,
/// scales it by a duck factor, and plays it to the real output device.
///
/// Lifecycle: init → start() → updateDuckLevel() → stop() → deinit
/// Cleanup order: AudioDeviceStop → DestroyIOProcID → DestroyAggregateDevice → DestroyProcessTap
final class ProcessTap {
    let processObjectID: AudioObjectID
    let pid: pid_t
    let bundleID: String?

    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private let tapUUID = UUID()
    private let aggregateUUID = UUID()
    private let ioQueue = DispatchQueue(label: "com.wisprduck.processtap.io", qos: .userInitiated)
    private var isRunning = false

    // Lock-free volume communication between main thread and audio IO queue.
    // Float is atomic-width (32-bit) on ARM64/x86_64 — no torn reads possible.
    // nonisolated(unsafe) opts out of Swift concurrency checks for cross-isolation access.
    nonisolated(unsafe) private var _targetLevel: Float = 1.0
    nonisolated(unsafe) private var _currentLevel: Float = 1.0
    nonisolated(unsafe) private var _rampCoefficient: Float = 0.0

    init(processObjectID: AudioObjectID, pid: pid_t, bundleID: String?) {
        self.processObjectID = processObjectID
        self.pid = pid
        self.bundleID = bundleID
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Start intercepting audio. Returns true on success.
    /// - Parameters:
    ///   - outputDeviceUID: UID of the output device to route audio through
    ///   - duckLevel: Volume factor 0.0–1.0 (e.g., 0.2 for 20%)
    func start(outputDeviceUID: String, duckLevel: Float) -> Bool {
        guard !isRunning else { return true }

        _targetLevel = duckLevel
        _currentLevel = 1.0 // Start at full volume and ramp down for smooth duck-in

        // 1. Create tap description
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDesc.uuid = tapUUID
        tapDesc.name = "WisprDuck-\(pid)"
        tapDesc.muteBehavior = .mutedWhenTapped
        tapDesc.isPrivate = true

        // 2. Create process tap
        var status = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        guard status == noErr else {
            print("ProcessTap: Failed to create tap for PID \(pid): \(status)")
            return false
        }

        // 3. Compute ramp coefficient from tap's sample rate
        _rampCoefficient = computeRampCoefficient(tapID: tapID)

        // 4. Create aggregate device combining real output + tap
        let aggDesc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "WisprDuck-Agg-\(pid)",
            kAudioAggregateDeviceUIDKey: aggregateUUID.uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceClockDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: outputDeviceUID,
                    kAudioSubDeviceDriftCompensationKey: false,
                ]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]

        status = AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggregateDeviceID)
        guard status == noErr else {
            print("ProcessTap: Failed to create aggregate device for PID \(pid): \(status)")
            cleanupTap()
            return false
        }

        // 5. Create IO proc (block-based, dispatched to our serial queue)
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateDeviceID, ioQueue) {
            [self] _, inInputData, _, outOutputData, _ in
            // This block captures self strongly. ProcessTap.stop() must be called
            // before deallocation to break the cycle (stop destroys the IO proc).
            self.processAudioBuffers(input: inInputData, output: outOutputData)
        }
        guard status == noErr else {
            print("ProcessTap: Failed to create IO proc for PID \(pid): \(status)")
            cleanupAggregateDevice()
            cleanupTap()
            return false
        }

        // 6. Start the device
        status = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard status == noErr else {
            print("ProcessTap: Failed to start device for PID \(pid): \(status)")
            cleanupIOProc()
            cleanupAggregateDevice()
            cleanupTap()
            return false
        }

        isRunning = true
        return true
    }

    /// Stop intercepting audio. Cleans up all Core Audio resources.
    /// Safe to call multiple times.
    func stop() {
        guard isRunning else { return }
        isRunning = false

        // Strict cleanup order: Stop → DestroyIOProc → DestroyAggregate → DestroyTap
        if let procID = ioProcID {
            AudioDeviceStop(aggregateDeviceID, procID)
        }
        cleanupIOProc()
        cleanupAggregateDevice()
        cleanupTap()
    }

    /// Update the duck level while the tap is running. Thread-safe (lock-free).
    func updateDuckLevel(_ level: Float) {
        _targetLevel = max(0.0, min(1.0, level))
    }

    // MARK: - Audio Processing

    /// Called on the IO queue for each audio buffer. Scales input samples by the
    /// duck level with a one-pole smoothing ramp to prevent clicks.
    ///
    /// The aggregate device's input buffer layout is:
    ///   [output device's input buffers...] [tap's input buffers...]
    /// If the output device has input channels (e.g. Scarlett 2i2 has mic inputs),
    /// the tap's audio starts AFTER those buffers. We must offset into the correct
    /// position to read the tapped audio rather than the device's mic input.
    private func processAudioBuffers(
        input inInputData: UnsafePointer<AudioBufferList>,
        output outOutputData: UnsafeMutablePointer<AudioBufferList>
    ) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
        let outputs = UnsafeMutableAudioBufferListPointer(outOutputData)

        // Tap buffers are at the END of the input list, after the output device's own inputs.
        let tapOffset = max(0, inputs.count - outputs.count)

        let target = _targetLevel
        var current = _currentLevel
        let ramp = _rampCoefficient

        for (i, output) in outputs.enumerated() {
            let inputIndex = tapOffset + i
            guard inputIndex < inputs.count,
                  let inData = inputs[inputIndex].mData,
                  let outData = output.mData else {
                continue
            }

            let inSamples = inData.assumingMemoryBound(to: Float.self)
            let outSamples = outData.assumingMemoryBound(to: Float.self)
            let sampleCount = Int(output.mDataByteSize) / MemoryLayout<Float>.size

            for j in 0..<sampleCount {
                // One-pole low-pass filter for smooth volume transitions (~1s ramp)
                current += (target - current) * ramp
                outSamples[j] = inSamples[j] * current
            }
        }

        _currentLevel = current
    }

    // MARK: - Cleanup Helpers

    private func cleanupIOProc() {
        guard let procID = ioProcID else { return }
        AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
        ioProcID = nil
    }

    private func cleanupAggregateDevice() {
        guard aggregateDeviceID != kAudioObjectUnknown else { return }
        AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        aggregateDeviceID = kAudioObjectUnknown
    }

    private func cleanupTap() {
        guard tapID != kAudioObjectUnknown else { return }
        AudioHardwareDestroyProcessTap(tapID)
        tapID = kAudioObjectUnknown
    }

    // MARK: - Helpers

    /// Compute the one-pole ramp coefficient for ~1s smoothing at the tap's sample rate.
    /// Time constant = 200ms → 95% at 600ms, 99% at 1s.
    /// Formula: coefficient = 1 - exp(-1 / (sampleRate * timeConstant))
    private func computeRampCoefficient(tapID: AudioObjectID) -> Float {
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        let status = AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &size, &format)
        let sampleRate: Float = (status == noErr && format.mSampleRate > 0)
            ? Float(format.mSampleRate)
            : 44100.0 // Fallback

        let timeConstant: Float = 0.200 // 200ms → ~1s to fully settle
        return 1.0 - expf(-1.0 / (sampleRate * timeConstant))
    }
}
