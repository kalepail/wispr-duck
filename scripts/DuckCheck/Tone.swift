import AVFoundation

// WisprDuck Test Tone: plays a 440 Hz sine so duck-check.sh has a known
// signal to duck. It runs inside an app bundle (com.wisprduck.testtone),
// so WisprDuck sees a bundle ID it can select as a duck target.
//
// Usage: Tone <seconds> <rms level in dBFS>

setvbuf(stdout, nil, _IOLBF, 0)
let arguments = CommandLine.arguments
let seconds = arguments.count > 1 ? Double(arguments[1]) ?? 20 : 20
let levelDB = arguments.count > 2 ? Double(arguments[2]) ?? -30 : -30
// A sine's RMS is its peak / sqrt(2).
let amplitude = levelDB <= -200 ? Float(0) : Float(pow(10, levelDB / 20) * 2.0.squareRoot())

let engine = AVAudioEngine()
let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
let phaseStep = 2 * Double.pi * 440 / sampleRate
var phase = 0.0

let source = AVAudioSourceNode { _, _, frameCount, bufferList in
    let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
    for frame in 0..<Int(frameCount) {
        let value = amplitude * Float(sin(phase))
        phase += phaseStep
        if phase >= 2 * Double.pi { phase -= 2 * Double.pi }
        for buffer in buffers {
            buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
        }
    }
    return noErr
}

let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
engine.attach(source)
engine.connect(source, to: engine.mainMixerNode, format: format)
do {
    try engine.start()
} catch {
    print("tone failed to start: \(error)")
    exit(1)
}
print("tone started pid=\(ProcessInfo.processInfo.processIdentifier) level=\(levelDB)dBFS")
Thread.sleep(forTimeInterval: seconds)
engine.stop()
print("tone stopped")
