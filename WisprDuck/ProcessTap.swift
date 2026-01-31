import Foundation
import CoreAudio

/// Manages a single Core Audio process tap: intercepts one process's audio output,
/// scales it by a duck factor, and plays it to the real output device.
/// Requires Screen & System Audio Recording permission and NSAudioCaptureUsageDescription.
///
/// Lifecycle: init → start() → updateDuckLevel() → stop() → deinit
/// Cleanup order: AudioDeviceStop → DestroyIOProcID → DestroyAggregateDevice → DestroyProcessTap
final class ProcessTap {
    let processObjectID: AudioObjectID
    let pid: pid_t

    private var tapID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private let tapUUID = UUID()
    private let aggregateUUID = UUID()
    private let ioQueue = DispatchQueue(label: "com.wisprduck.processtap.io", qos: .userInitiated)
    private var isRunning = false
    private var tapFormatIsFloat32 = true

    // Lock-free volume communication between main thread and audio IO queue.
    // Float is atomic-width (32-bit) on ARM64/x86_64 — no torn reads possible.
    // nonisolated(unsafe) opts out of Swift concurrency checks for cross-isolation access.
    nonisolated(unsafe) private var _targetLevel: Float = 1.0
    nonisolated(unsafe) private var _currentLevel: Float = 1.0
    nonisolated(unsafe) private var _rampRate: Float = 0.0 // Max change per sample (linear ramp)

    init(processObjectID: AudioObjectID, pid: pid_t) {
        self.processObjectID = processObjectID
        self.pid = pid
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
        _currentLevel = duckLevel // Start at duck level — no ramp on duck-in to avoid silence→pop

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

        // 3. Compute linear ramp rate from tap's sample rate
        _rampRate = computeRampRate(tapID: tapID)

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
                    continue
                }
                let bytes = min(Int(inputs[inputIndex].mDataByteSize), Int(output.mDataByteSize))
                memcpy(outData, inData, bytes)
            }
            return
        }

        let target = _targetLevel
        var current = _currentLevel
        let rate = _rampRate

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
                // Linear ramp: move toward target at a fixed rate per sample.
                // A full 0→1 sweep takes exactly 1 second. Partial sweeps are proportional.
                let delta = target - current
                current += max(-rate, min(rate, delta))
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

    /// Compute the linear ramp rate (max volume change per sample) for 1-second transitions.
    /// At 48kHz: rate = 1/48000 ≈ 0.00002. A full 0→1 sweep takes exactly 1s.
    /// Partial sweeps are proportional (e.g., 0.1→1.0 takes 0.9s).
    private func computeRampRate(tapID: AudioObjectID) -> Float {
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
        let sampleRate: Float = (status == noErr && format.mSampleRate > 0)
            ? Float(format.mSampleRate)
            : 44100.0 // Fallback

        let rampDuration: Float = 1.0 // Full 0→1 sweep in 1 second
        return 1.0 / (sampleRate * rampDuration)
    }
}
