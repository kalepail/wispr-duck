import Foundation
import CoreAudio
import os

private let logger = Logger(subsystem: "com.wisprduck", category: "ProcessTap")

/// Manages a single Core Audio process tap: intercepts one process's audio output,
/// scales it by a duck factor, and plays it to the real output device.
/// Requires Screen & System Audio Recording permission and NSAudioCaptureUsageDescription.
///
/// Lifecycle: init → start() → updateDuckLevel() → stop() → deinit
/// Cleanup order: AudioDeviceStop → DestroyIOProcID → DestroyAggregateDevice → DestroyProcessTap
final class ProcessTap: DuckTap {
    let processObjectID: AudioObjectID
    let pid: pid_t
    private(set) var lastError: String?

    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private let tapUUID = UUID()
    private let aggregateUUID = UUID()
    private let ioQueue = DispatchQueue(label: "com.wisprduck.processtap.io", qos: .userInitiated)
    private var isRunning = false
    /// A stopped tap is never restarted: its teardown may still be pending.
    private var hasStopped = false
    private var tapFormatIsFloat32 = true

    /// Volume ramp state. Read and written only on `ioQueue` once the device starts.
    private var ramp = LinearGainRamp(level: 1.0, stepPerFrame: LinearGainRamp.stepPerFrame(sampleRate: 48_000))

    init(processObjectID: AudioObjectID, pid: pid_t) {
        self.processObjectID = processObjectID
        self.pid = pid
    }

    deinit {
        // A started tap is retained by its IO proc block until teardown finishes,
        // so by the time deinit runs every Core Audio resource is already released.
        // A tap that failed to start cleaned up synchronously in start().
    }

    // MARK: - Public API

    /// Start intercepting audio. Returns true on success.
    /// - Parameters:
    ///   - outputDeviceUID: UID of the output device to route audio through
    ///   - duckLevel: Volume factor 0.0–1.0 (e.g., 0.2 for 20%)
    func start(outputDeviceUID: String, duckLevel: Float) -> Bool {
        guard !isRunning else { return true }
        guard !hasStopped else {
            lastError = "Internal error: a stopped tap for PID \(pid) cannot be restarted."
            return false
        }
        lastError = nil

        // Start at duck level — no ramp on duck-in to avoid silence→pop
        ramp = LinearGainRamp(level: duckLevel, stepPerFrame: ramp.stepPerFrame)

        // 1. Create tap description
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDesc.uuid = tapUUID
        tapDesc.name = "WisprDuck-\(pid)"
        tapDesc.muteBehavior = .mutedWhenTapped
        tapDesc.isPrivate = true

        // 2. Create process tap
        var status = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        guard status == noErr else {
            let message = "Could not create system audio tap for PID \(pid): \(describeOSStatus(status))"
            lastError = message
            logger.error("\(message)")
            return false
        }

        // 3. Read the tap format (sample type and fallback sample rate)
        let tapSampleRate = readTapFormat(tapID: tapID)

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
            let message = "Could not create aggregate audio device for PID \(pid): \(describeOSStatus(status))"
            lastError = message
            logger.error("\(message)")
            cleanupTap()
            return false
        }

        // The IO proc runs at the aggregate device's rate (clocked by the output
        // device), so derive the per-frame ramp step from that rate.
        let ioSampleRate = nominalSampleRate(deviceID: aggregateDeviceID) ?? tapSampleRate
        ramp.stepPerFrame = LinearGainRamp.stepPerFrame(sampleRate: ioSampleRate)

        // 5. Create IO proc (block-based, dispatched to our serial queue)
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateDeviceID, ioQueue) {
            [self] _, inInputData, _, outOutputData, _ in
            // This block captures self strongly. ProcessTap.stop() must be called
            // before deallocation to break the cycle (stop destroys the IO proc).
            self.processAudioBuffers(input: inInputData, output: outOutputData)
        }
        guard status == noErr else {
            let message = "Could not create audio IO callback for PID \(pid): \(describeOSStatus(status))"
            lastError = message
            logger.error("\(message)")
            cleanupAggregateDevice()
            cleanupTap()
            return false
        }

        // 6. Start the device
        status = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard status == noErr else {
            let message = "Could not start aggregate audio device for PID \(pid): \(describeOSStatus(status))"
            lastError = message
            logger.error("\(message)")
            cleanupIOProc()
            cleanupAggregateDevice()
            cleanupTap()
            return false
        }

        isRunning = true
        return true
    }

    /// Serial queue for Core Audio teardown. AudioDeviceStop can block for a long
    /// time when the HAL is busy restarting the aggregate's IO, so teardown never
    /// runs on the main thread (which would freeze the menu bar UI).
    private static let teardownQueue = DispatchQueue(label: "com.wisprduck.processtap.teardown", qos: .userInitiated)

    /// Stop intercepting audio. Cleans up all Core Audio resources asynchronously,
    /// in strict order. Safe to call multiple times.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        hasStopped = true

        // The teardown block keeps `self` alive until the IO proc is destroyed.
        Self.teardownQueue.async { [self] in
            teardown()
        }
    }

    /// Strict cleanup order: Stop → DestroyIOProc → DestroyAggregate → DestroyTap
    private func teardown() {
        if let procID = ioProcID {
            let status = AudioDeviceStop(aggregateDeviceID, procID)
            if status != noErr {
                logger.error("Could not stop aggregate audio device for PID \(self.pid): \(describeOSStatus(status))")
            }
        }
        cleanupIOProc()
        cleanupAggregateDevice()
        cleanupTap()
    }

    /// Update the duck level while the tap is running.
    func updateDuckLevel(_ level: Float) {
        let clampedLevel = LinearGainRamp.clamp(level)
        ioQueue.async { [weak self] in
            self?.ramp.target = clampedLevel
        }
    }

    // MARK: - Audio Processing

    /// Called on the IO queue for each audio buffer. Scales input samples by the
    /// duck level with a linear ramp for smooth, constant-rate volume transitions.
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

        guard tapFormatIsFloat32 else {
            // Pass-through without scaling if the format is not Float32 PCM.
            for (i, output) in outputs.enumerated() {
                let inputIndex = tapOffset + i
                guard inputIndex < inputs.count,
                      let inData = inputs[inputIndex].mData,
                      let outData = output.mData else {
                    if let outData = output.mData {
                        memset(outData, 0, Int(output.mDataByteSize))
                    }
                    continue
                }
                let bytes = min(Int(inputs[inputIndex].mDataByteSize), Int(output.mDataByteSize))
                memcpy(outData, inData, bytes)
            }
            return
        }

        // Every buffer in this render cycle starts from the same gain, so
        // separate channel buffers never drift apart.
        var endLevel = ramp.level
        for (i, output) in outputs.enumerated() {
            let inputIndex = tapOffset + i
            guard inputIndex < inputs.count,
                  let inData = inputs[inputIndex].mData,
                  let outData = output.mData else {
                if let outData = output.mData {
                    memset(outData, 0, Int(output.mDataByteSize))
                }
                continue
            }

            let byteCount = min(Int(inputs[inputIndex].mDataByteSize), Int(output.mDataByteSize))
            endLevel = ramp.scale(
                inData.assumingMemoryBound(to: Float.self),
                into: outData.assumingMemoryBound(to: Float.self),
                sampleCount: byteCount / MemoryLayout<Float>.size,
                channelsPerFrame: Int(inputs[inputIndex].mNumberChannels)
            )
        }

        ramp.level = endLevel
    }

    // MARK: - Cleanup Helpers

    private func cleanupIOProc() {
        guard let procID = ioProcID else { return }
        let status = AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
        if status != noErr {
            logger.error("Could not destroy audio IO callback for PID \(self.pid): \(describeOSStatus(status))")
        }
        ioProcID = nil
    }

    private func cleanupAggregateDevice() {
        guard aggregateDeviceID != kAudioObjectUnknown else { return }
        let status = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        if status != noErr {
            logger.error("Could not destroy aggregate audio device for PID \(self.pid): \(describeOSStatus(status))")
        }
        aggregateDeviceID = kAudioObjectUnknown
    }

    private func cleanupTap() {
        guard tapID != kAudioObjectUnknown else { return }
        let status = AudioHardwareDestroyProcessTap(tapID)
        if status != noErr {
            logger.error("Could not destroy process tap for PID \(self.pid): \(describeOSStatus(status))")
        }
        tapID = kAudioObjectUnknown
    }

    // MARK: - Helpers

    /// Read the tap's stream format. Records whether it is Float32 PCM and
    /// returns its sample rate (or a fallback when unavailable).
    private func readTapFormat(tapID: AudioObjectID) -> Double {
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        let status = AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &size, &format)
        tapFormatIsFloat32 = status == noErr
            && format.mFormatID == kAudioFormatLinearPCM
            && (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
            && format.mBitsPerChannel == 32
        return (status == noErr && format.mSampleRate > 0) ? format.mSampleRate : 44_100.0
    }

    private func nominalSampleRate(deviceID: AudioObjectID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
        return (status == noErr && rate > 0) ? rate : nil
    }
}
