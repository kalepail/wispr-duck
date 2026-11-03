import Foundation

/// A linear, constant-rate volume ramp for real-time audio.
///
/// The ramp advances once per audio *frame*, not once per sample, so an
/// interleaved stereo buffer ramps at the same speed as a mono one and both
/// channels of a frame always get the same gain. A full 0→1 sweep takes
/// `fullSweepDuration` seconds; partial sweeps are proportional.
struct LinearGainRamp {
    /// The gain applied to the most recent frame.
    var level: Float
    /// The gain the ramp moves toward.
    var target: Float
    /// Maximum gain change per frame.
    var stepPerFrame: Float

    init(level: Float, target: Float? = nil, stepPerFrame: Float) {
        let clamped = Self.clamp(level)
        self.level = clamped
        self.target = Self.clamp(target ?? clamped)
        self.stepPerFrame = stepPerFrame
    }

    static func clamp(_ level: Float) -> Float {
        guard level.isFinite else { return 1.0 }
        return max(0.0, min(1.0, level))
    }

    /// Gain change per frame for a full 0→1 sweep in `fullSweepDuration` seconds.
    static func stepPerFrame(sampleRate: Double, fullSweepDuration: Double = 1.0) -> Float {
        guard sampleRate.isFinite, sampleRate > 0,
              fullSweepDuration.isFinite, fullSweepDuration > 0 else {
            return Float(1.0 / 44_100.0)
        }
        return Float(1.0 / (sampleRate * fullSweepDuration))
    }

    /// Seconds needed to move from `from` to `to` at the given step and sample rate.
    static func duration(from: Float, to: Float, stepPerFrame: Float, sampleRate: Double) -> Double {
        guard stepPerFrame > 0, sampleRate > 0 else { return 0 }
        let frames = (abs(clamp(to) - clamp(from)) / stepPerFrame).rounded(.up)
        return Double(frames) / sampleRate
    }

    /// Scale one interleaved buffer, starting from `level`, without changing the ramp state.
    /// Call it for each buffer of a render cycle, then store the returned level once,
    /// so that every buffer in the cycle shares the same gain curve.
    ///
    /// - Returns: The gain reached at the end of the buffer.
    func scale(
        _ input: UnsafePointer<Float>,
        into output: UnsafeMutablePointer<Float>,
        sampleCount: Int,
        channelsPerFrame: Int
    ) -> Float {
        let channels = max(1, channelsPerFrame)
        let frameCount = sampleCount / channels
        var current = level
        var index = 0

        for _ in 0..<frameCount {
            current += max(-stepPerFrame, min(stepPerFrame, target - current))
            for _ in 0..<channels {
                output[index] = input[index] * current
                index += 1
            }
        }

        // A trailing partial frame should not happen, but never leave output unwritten.
        while index < sampleCount {
            output[index] = input[index] * current
            index += 1
        }

        return current
    }
}
