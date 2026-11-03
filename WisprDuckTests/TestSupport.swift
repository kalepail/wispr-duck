import Combine
import CoreAudio
import Foundation
import XCTest

// The test bundle compiles the app's non-UI sources directly, so app types are
// available here without @testable import and without launching the app.

/// Records what ProcessTapManager asks a tap to do, without touching Core Audio.
final class FakeTap: DuckTap {
    let process: AudioProcess
    var lastError: String?
    private let startSucceeds: Bool
    private(set) var started = false
    private(set) var stopped = false
    private(set) var startLevel: Float?
    private(set) var levelUpdates: [Float] = []

    init(process: AudioProcess, startSucceeds: Bool) {
        self.process = process
        self.startSucceeds = startSucceeds
    }

    var isLive: Bool { started && !stopped }

    func start(outputDeviceUID: String, duckLevel: Float) -> Bool {
        started = startSucceeds
        startLevel = duckLevel
        if !startSucceeds { lastError = "Fake tap failed for PID \(process.pid)" }
        return startSucceeds
    }

    func stop() { stopped = true }

    func updateDuckLevel(_ level: Float) { levelUpdates.append(level) }
}

/// A scriptable stand-in for Core Audio + Launch Services.
final class FakeAudioSystem {
    var processes: [AudioProcess] = []
    var outputDeviceUID: String? = "fake-output-device"
    var tapsStartSucceed = true
    var applicationURLs: [String: URL] = [:]
    private(set) var createdTaps: [FakeTap] = []

    var liveTaps: [FakeTap] { createdTaps.filter(\.isLive) }

    func liveTap(pid: pid_t) -> FakeTap? { liveTaps.first { $0.process.pid == pid } }

    var environment: AudioSystemEnvironment {
        AudioSystemEnvironment(
            enumerateProcesses: { [self] in processes },
            defaultOutputDeviceUID: { [self] in outputDeviceUID },
            makeTap: { [self] process in
                let tap = FakeTap(process: process, startSucceeds: tapsStartSucceed)
                createdTaps.append(tap)
                return tap
            },
            applicationURL: { [self] in applicationURLs[$0] },
            observesSystemChanges: false
        )
    }

    /// Launch Services layout for the apps used in these tests, matching the
    /// real bundle structure on disk.
    static func withKnownApps() -> FakeAudioSystem {
        let system = FakeAudioSystem()
        system.applicationURLs = [
            "com.granola.app": URL(fileURLWithPath: "/Applications/Granola.app"),
            "com.granola.app.helper": URL(fileURLWithPath: "/Applications/Granola.app/Contents/Frameworks/Granola Helper.app"),
            "com.granola.app.helper.Renderer": URL(fileURLWithPath: "/Applications/Granola.app/Contents/Frameworks/Granola Helper (Renderer).app"),
            "com.electron.wispr-flow": URL(fileURLWithPath: "/Applications/Wispr Flow.app"),
            "com.electron.wispr-flow.accessibility-mac-app": URL(fileURLWithPath: "/Applications/Wispr Flow.app/Contents/Resources/swift-helper-app-dist/Wispr Flow.app"),
            "com.google.Chrome": URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            "com.google.Chrome.helper": URL(fileURLWithPath: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app"),
            "com.spotify.client": URL(fileURLWithPath: "/Applications/Spotify.app"),
        ]
        return system
    }
}

/// A trigger signal the test controls directly.
final class FakeTriggerSource: MicTriggerSource {
    private let subject = CurrentValueSubject<Bool, Never>(false)
    private let changes = PassthroughSubject<Void, Never>()

    var shouldTriggerDuck: Bool { subject.value }
    var shouldTriggerDuckPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    var stateWillChangePublisher: AnyPublisher<Void, Never> { changes.eraseToAnyPublisher() }
    var monitoringIssue: String?
    var triggerAllApps = false
    var triggerBundleIDs: Set<String> = []
    var rootBundleIDResolver: ((String) -> String)?
    private(set) var refreshCount = 0

    func refreshTriggerState() { refreshCount += 1 }

    func setTriggered(_ triggered: Bool) {
        changes.send()
        subject.send(triggered)
    }
}

enum Fixtures {
    static func process(_ pid: pid_t, _ bundleID: String?, name: String? = nil, playing: Bool = true) -> AudioProcess {
        AudioProcess(
            pid: pid,
            objectID: AudioObjectID(1000 + pid),
            bundleID: bundleID,
            name: name ?? bundleID ?? "PID \(pid)",
            isRunningOutput: playing
        )
    }

    static let spotify = process(101, "com.spotify.client", name: "Spotify")
    static let chromeHelper = process(102, "com.google.Chrome.helper", name: "Google Chrome Helper")
    static let granolaHelper = process(103, "com.granola.app.helper", name: "Granola Helper")
    static let cliPlayer = process(104, nil)
    static let idleDaemon = process(105, nil, name: "coreaudiod client", playing: false)
}

extension XCTestCase {
    /// A fresh, isolated UserDefaults suite that is removed after the test.
    func makeIsolatedDefaults(file: StaticString = #filePath, line: UInt = #line) -> UserDefaults {
        let suiteName = "com.wisprduck.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create defaults suite", file: file, line: line)
            return .standard
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    /// Run the main run loop so queued main-queue work (Combine receive(on:),
    /// asyncAfter fades, timers) executes.
    func runMainLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Process everything already queued on the main queue.
    func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async {
            DispatchQueue.main.async { drained.fulfill() }
        }
        wait(for: [drained], timeout: 2)
    }
}
