import XCTest

final class ProcessTapManagerTests: XCTestCase {
    private var system: FakeAudioSystem!
    private var manager: ProcessTapManager!

    override func setUp() {
        super.setUp()
        system = FakeAudioSystem.withKnownApps()
        manager = ProcessTapManager(environment: system.environment)
    }

    override func tearDown() {
        manager.restoreAll()
        manager = nil
        system = nil
        super.tearDown()
    }

    func testDuckTapsOnlySelectedAppsIncludingHelpers() {
        system.processes = [Fixtures.spotify, Fixtures.chromeHelper, Fixtures.granolaHelper, Fixtures.cliPlayer]

        let ducked = manager.duck(bundleIDs: ["com.google.Chrome"], duckAll: false, duckLevel: 0.1)

        XCTAssertTrue(ducked)
        XCTAssertEqual(system.liveTaps.map(\.process.pid), [Fixtures.chromeHelper.pid])
        XCTAssertEqual(system.liveTaps.first?.startLevel, 0.1)
    }

    func testDuckAllTapsPlayingAppsButNotDaemons() {
        // Processes with no app identity (e.g. arkaudiod) are never tapped.
        system.processes = [Fixtures.spotify, Fixtures.cliPlayer]

        XCTAssertTrue(manager.duck(bundleIDs: [], duckAll: true, duckLevel: 0.2))
        XCTAssertEqual(system.liveTaps.map(\.process.pid), [Fixtures.spotify.pid])
    }

    func testDuckAllSkipsIdleProcessesUntilTheyPlay() {
        let pausedChrome = Fixtures.process(102, "com.google.Chrome.helper", playing: false)
        system.processes = [Fixtures.spotify, pausedChrome]

        XCTAssertTrue(manager.duck(bundleIDs: [], duckAll: true, duckLevel: 0.1))
        XCTAssertEqual(system.liveTaps.map(\.process.pid), [Fixtures.spotify.pid])

        // Chrome starts playing; the next reconcile ducks it.
        var playingChrome = pausedChrome
        playingChrome.isRunningOutput = true
        system.processes = [Fixtures.spotify, playingChrome]
        manager.reconcileActiveTaps(bundleIDs: [], duckAll: true, duckLevel: 0.1)
        XCTAssertEqual(Set(system.liveTaps.map(\.process.pid)), [Fixtures.spotify.pid, pausedChrome.pid])
    }

    func testSelectedAppsAreTappedEvenWhenPaused() {
        // Pre-tapping a paused target means it is ducked the moment it resumes.
        let pausedSpotify = Fixtures.process(101, "com.spotify.client", playing: false)
        system.processes = [pausedSpotify]

        XCTAssertTrue(manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.1))
    }

    func testDuckWithNoMatchingAppsReportsNoTapsButKeepsSessionOpen() {
        system.processes = [Fixtures.granolaHelper]

        XCTAssertFalse(manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.1))
        XCTAssertTrue(manager.isSessionActive)

        // A target that starts during the session is ducked.
        system.processes.append(Fixtures.spotify)
        manager.handleProcessListChanged(with: system.processes)
        XCTAssertNotNil(system.liveTap(pid: Fixtures.spotify.pid))
    }

    func testEndedSessionDoesNotTapAppsThatStartLater() {
        system.processes = []
        manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.1)
        manager.restoreAllWithFade()
        XCTAssertFalse(manager.isSessionActive)

        system.processes = [Fixtures.spotify]
        manager.handleProcessListChanged(with: system.processes)
        XCTAssertTrue(system.createdTaps.isEmpty)
    }

    func testProcessListChangeDropsTapsForDepartedProcesses() {
        system.processes = [Fixtures.spotify]
        manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.1)
        let tap = system.liveTap(pid: Fixtures.spotify.pid)

        system.processes = []
        manager.handleProcessListChanged(with: [])

        XCTAssertEqual(tap?.stopped, true)
        XCTAssertEqual(manager.activeTapCount, 0)
    }

    func testReconcileStopsTapsForDeselectedApps() {
        system.processes = [Fixtures.spotify, Fixtures.chromeHelper]
        manager.duck(bundleIDs: ["com.spotify.client", "com.google.Chrome"], duckAll: false, duckLevel: 0.1)
        XCTAssertEqual(system.liveTaps.count, 2)

        manager.reconcileActiveTaps(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.3)

        XCTAssertEqual(system.liveTaps.map(\.process.pid), [Fixtures.spotify.pid])
        XCTAssertEqual(system.liveTap(pid: Fixtures.spotify.pid)?.levelUpdates.last, 0.3)
    }

    func testFadeRampsToFullThenDestroysTaps() {
        system.processes = [Fixtures.spotify]
        manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.5)
        let tap = system.liveTap(pid: Fixtures.spotify.pid)

        manager.restoreAllWithFade()
        XCTAssertEqual(tap?.levelUpdates.last, 1.0)
        XCTAssertEqual(tap?.stopped, false, "Taps stay alive while the volume ramps up")

        // (1 - 0.5) * 1 s + 0.05 s cushion
        runMainLoop(for: 0.7)
        XCTAssertEqual(tap?.stopped, true)
        XCTAssertEqual(manager.activeTapCount, 0)
    }

    /// Regression: each repeated restore restarted the fade, so steady trigger
    /// re-evaluations could postpone tap teardown indefinitely.
    func testRepeatedRestoreDoesNotPostponeTeardown() {
        system.processes = [Fixtures.spotify]
        manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.5)
        let tap = system.liveTap(pid: Fixtures.spotify.pid)

        manager.restoreAllWithFade()
        runMainLoop(for: 0.35)
        manager.restoreAllWithFade()
        runMainLoop(for: 0.35)

        // 0.55 s fade from 50%: done 0.7 s after the first restore.
        XCTAssertEqual(tap?.stopped, true)
    }

    func testDuckDuringFadeReusesTaps() {
        system.processes = [Fixtures.spotify]
        manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.5)
        manager.restoreAllWithFade()

        manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.5)
        runMainLoop(for: 0.7)

        XCTAssertEqual(system.createdTaps.count, 1)
        XCTAssertNotNil(system.liveTap(pid: Fixtures.spotify.pid))
        XCTAssertEqual(system.liveTap(pid: Fixtures.spotify.pid)?.levelUpdates.last, 0.5)
    }

    func testTapStartFailureIsReported() {
        system.processes = [Fixtures.spotify]
        system.tapsStartSucceed = false
        var messages: [String] = []
        manager.setErrorHandler { messages.append($0) }

        XCTAssertFalse(manager.duck(bundleIDs: ["com.spotify.client"], duckAll: false, duckLevel: 0.1))
        drainMainQueue()

        XCTAssertEqual(messages, ["Fake tap failed for PID \(Fixtures.spotify.pid)"])
    }

    func testMissingOutputDeviceIsReported() {
        system.outputDeviceUID = nil
        var messages: [String] = []
        manager.setErrorHandler { messages.append($0) }

        XCTAssertFalse(manager.duck(bundleIDs: [], duckAll: true, duckLevel: 0.1))
        drainMainQueue()

        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].contains("output device"))
    }

    func testRootBundleIDResolutionUsesInjectedLookup() {
        XCTAssertEqual(manager.rootAppBundleID(for: "com.granola.app.helper"), "com.granola.app")
    }
}
