import AVFoundation
import Foundation

// WisprDuck Test Mic: opens the default input device for N seconds, like a
// dictation app does while you hold the dictation key. It runs inside an app
// bundle (com.wisprduck.testmic), so duck-check.sh can select it as the one
// trigger app. It prints the epoch time when the mic starts and stops.
//
// Usage: MicHold <seconds>

setvbuf(stdout, nil, _IOLBF, 0)
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "4") ?? 4

if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
    let answered = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: .audio) { _ in answered.signal() }
    _ = answered.wait(timeout: .now() + 120)
}
guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
    print("error: microphone access is not granted to WisprDuck Test Mic")
    exit(3)
}

let engine = AVAudioEngine()
let input = engine.inputNode
input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { _, _ in }
do {
    try engine.start()
} catch {
    print("error: mic failed to start: \(error)")
    exit(1)
}
print(String(format: "mic-on %.3f", Date().timeIntervalSince1970))
Thread.sleep(forTimeInterval: seconds)
engine.stop()
print(String(format: "mic-off %.3f", Date().timeIntervalSince1970))
