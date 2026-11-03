import XCTest

final class GainRampTests: XCTestCase {
    private let sampleRate = 48_000.0

    /// Runs `frames` frames of a constant 1.0 signal through the ramp, in
    /// render-sized chunks like the IO proc does, and returns the output.
    private func render(_ ramp: inout LinearGainRamp, frames: Int, channels: Int, chunkFrames: Int = 512) -> [Float] {
        var output: [Float] = []
        output.reserveCapacity(frames * channels)
        var remaining = frames
        while remaining > 0 {
            let chunk = min(chunkFrames, remaining)
            let input = [Float](repeating: 1.0, count: chunk * channels)
            var out = [Float](repeating: 0, count: chunk * channels)
            let end = input.withUnsafeBufferPointer { inBuf in
                out.withUnsafeMutableBufferPointer { outBuf in
                    ramp.scale(inBuf.baseAddress!, into: outBuf.baseAddress!, sampleCount: chunk * channels, channelsPerFrame: channels)
                }
            }
            ramp.level = end
            output += out
            remaining -= chunk
        }
        return output
    }

    func testStepPerFrameGivesOneSecondFullSweep() {
        XCTAssertEqual(LinearGainRamp.stepPerFrame(sampleRate: 48_000), Float(1.0 / 48_000.0), accuracy: 1e-12)
        XCTAssertEqual(LinearGainRamp.stepPerFrame(sampleRate: 0), Float(1.0 / 44_100.0), accuracy: 1e-12)
        XCTAssertEqual(LinearGainRamp.stepPerFrame(sampleRate: .nan), Float(1.0 / 44_100.0), accuracy: 1e-12)
    }

    /// Core Audio process taps deliver interleaved stereo Float32. The ramp must
    /// advance per frame, so half a second of stereo audio is half of a full sweep.
    func testInterleavedStereoRampsAtOneSecondPerFullSweep() {
        var ramp = LinearGainRamp(level: 0, target: 1, stepPerFrame: LinearGainRamp.stepPerFrame(sampleRate: sampleRate))
        _ = render(&ramp, frames: Int(sampleRate / 2), channels: 2)
        XCTAssertEqual(ramp.level, 0.5, accuracy: 0.001)

        _ = render(&ramp, frames: Int(sampleRate / 2), channels: 2)
        XCTAssertEqual(ramp.level, 1.0, accuracy: 0.001)
    }

    func testMonoAndStereoRampAtTheSameSpeed() {
        let step = LinearGainRamp.stepPerFrame(sampleRate: sampleRate)
        var mono = LinearGainRamp(level: 0.1, target: 1, stepPerFrame: step)
        var stereo = LinearGainRamp(level: 0.1, target: 1, stepPerFrame: step)
        _ = render(&mono, frames: 10_000, channels: 1)
        _ = render(&stereo, frames: 10_000, channels: 2)
        XCTAssertEqual(mono.level, stereo.level, accuracy: 1e-5)
    }

    func testBothChannelsOfAFrameGetTheSameGain() {
        var ramp = LinearGainRamp(level: 0, target: 1, stepPerFrame: LinearGainRamp.stepPerFrame(sampleRate: sampleRate))
        let output = render(&ramp, frames: 2_048, channels: 2)
        for frame in 0..<2_048 {
            XCTAssertEqual(output[frame * 2], output[frame * 2 + 1], "frame \(frame)")
        }
    }

    /// Restoring from the default 10% duck level takes 0.9 s, which is what
    /// ProcessTapManager waits before destroying taps.
    func testPartialSweepFromDefaultDuckLevelTakesPointNineSeconds() {
        let step = LinearGainRamp.stepPerFrame(sampleRate: sampleRate)
        var ramp = LinearGainRamp(level: 0.1, target: 1, stepPerFrame: step)

        _ = render(&ramp, frames: Int(sampleRate * 0.85), channels: 2)
        XCTAssertLessThan(ramp.level, 0.99)

        _ = render(&ramp, frames: Int(sampleRate * 0.05) + 1, channels: 2)
        XCTAssertEqual(ramp.level, 1.0, accuracy: 1e-4)

        XCTAssertEqual(LinearGainRamp.duration(from: 0.1, to: 1.0, stepPerFrame: step, sampleRate: sampleRate), 0.9, accuracy: 0.001)
    }

    func testRampDownStopsAtTargetWithoutOvershoot() {
        var ramp = LinearGainRamp(level: 1, target: 0.2, stepPerFrame: LinearGainRamp.stepPerFrame(sampleRate: sampleRate))
        let output = render(&ramp, frames: Int(sampleRate), channels: 2)
        XCTAssertEqual(ramp.level, 0.2, accuracy: 1e-6)
        XCTAssertGreaterThanOrEqual(output.min() ?? 0, 0.2 - 1e-6)
    }

    func testScaleIsPureUntilLevelIsStored() {
        let ramp = LinearGainRamp(level: 0.5, target: 1, stepPerFrame: 0.01)
        let input: [Float] = [1, 1, 1, 1]
        var output = [Float](repeating: 0, count: 4)
        let end = input.withUnsafeBufferPointer { inBuf in
            output.withUnsafeMutableBufferPointer { outBuf in
                ramp.scale(inBuf.baseAddress!, into: outBuf.baseAddress!, sampleCount: 4, channelsPerFrame: 2)
            }
        }
        XCTAssertEqual(ramp.level, 0.5)
        XCTAssertEqual(end, 0.52, accuracy: 1e-6)
        for (actual, expected) in zip(output, [Float(0.51), 0.51, 0.52, 0.52]) {
            XCTAssertEqual(actual, expected, accuracy: 1e-6)
        }
    }

    func testClampHandlesOutOfRangeAndNaN() {
        XCTAssertEqual(LinearGainRamp.clamp(-0.5), 0)
        XCTAssertEqual(LinearGainRamp.clamp(2), 1)
        XCTAssertEqual(LinearGainRamp.clamp(.nan), 1)
        XCTAssertEqual(LinearGainRamp(level: 3, stepPerFrame: 0.1).level, 1)
    }
}
