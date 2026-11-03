import XCTest

final class DuckControllerTests: XCTestCase {
    private var system: FakeAudioSystem!
    private var trigger: FakeTriggerSource!
    private var settings: AppSettings!
    private var controller: DuckController!
    private var manager: ProcessTapManager!

    override func setUp() {
        super.setUp()
        system = FakeAudioSystem.withKnownApps()
        trigger = FakeTriggerSource()
        settings = AppSettings(defaults: makeIsolatedDefaults())
        settings.setBundleID("com.spotify.client", enabled: true)
        settings.setTriggerBundleID("com.granola.app", enabled: true)
        manager = ProcessTapManager(environment: system.environment)
        controller = DuckController(settings: settings, micMonitor: trigger, tapManager: manager)
        drainMainQueue()
    }

    override func tearDown() {
        controller.restoreAndStop()
        controller = nil
        manager = nil
        settings = nil
        trigger = nil
        system = nil
        super.tearDown()
    }

    private func setTriggered(_ triggered: Bool) {
        trigger.setTriggered(triggered)
        drainMainQueue()
    }

    func testTriggerDucksTargetsAndRestoresWithFade() {
        system.processes = [Fixtures.spotify]

        setTriggered(true)
        XCTAssertTrue(controller.isDucked)
        let tap = system.liveTap(pid: Fixtures.spotify.pid)
        XCTAssertEqual(tap?.startLevel, 0.1)

        setTriggered(false)
        XCTAssertFalse(controller.isDucked)
        XCTAssertEqual(tap?.levelUpdates.last, 1.0)

        runMainLoop(for: 1.1) // 0.9 s ramp from 10% + cushion
        XCTAssertEqual(tap?.stopped, true)
    }

    func testRepeatedIdleSignalsRestoreOnce() {
        system.processes = [Fixtures.spotify]
        setTriggered(true)
        let tap = system.liveTap(pid: Fixtures.spotify.pid)

        setTriggered(false)
        runMainLoop(for: 0.5)
        setTriggered(false)
        runMainLoop(for: 0.6)

        XCTAssertEqual(tap?.stopped, true, "A repeated idle signal must not restart the 0.9 s fade")
    }

    /// Regression: when dictation started with no target app playing, the duck
    /// session stayed open after the mic went idle. An app that started later
    /// was then ducked with no mic in use.
    func testIdleMicAfterEmptySessionDoesNotDuckAppsThatStartLater() {
        system.processes = []

        setTriggered(true)
        XCTAssertFalse(controller.isDucked)

        setTriggered(false)
        XCTAssertFalse(manager.isSessionActive)

        system.processes = [Fixtures.spotify]
        manager.handleProcessListChanged(with: system.processes)
        XCTAssertTrue(system.liveTaps.isEmpty, "Spotify must not be ducked while the mic is idle")
    }

    /// Regression: dictating with nothing to duck showed a permission warning.
    func testNothingToDuckDoesNotShowPermissionWarning() {
        system.processes = []

        setTriggered(true)
        XCTAssertNil(controller.audioStatusMessage)
        XCTAssertNil(controller.currentIssueMessage)
    }

    func testTapFailureShowsSpecificMessage() {
        system.processes = [Fixtures.spotify]
        system.tapsStartSucceed = false

        setTriggered(true)
        drainMainQueue()

        XCTAssertEqual(controller.audioStatusMessage, "Fake tap failed for PID \(Fixtures.spotify.pid)")
    }

    func testTargetStartingMidDictationIsDucked() {
        system.processes = []
        setTriggered(true)

        system.processes = [Fixtures.spotify]
        manager.handleProcessListChanged(with: system.processes)
        XCTAssertNotNil(system.liveTap(pid: Fixtures.spotify.pid))

        // The re-evaluation timer marks the controller as ducked.
        runMainLoop(for: 0.4)
        XCTAssertTrue(controller.isDucked)
    }

    func testDisablingWhileDuckedRestoresImmediately() {
        system.processes = [Fixtures.spotify]
        setTriggered(true)
        let tap = system.liveTap(pid: Fixtures.spotify.pid)

        settings.isEnabled = false
        drainMainQueue()

        XCTAssertFalse(controller.isDucked)
        XCTAssertEqual(tap?.stopped, true)
        XCTAssertFalse(manager.isSessionActive)
    }

    func testTriggerWhileDisabledDoesNothing() {
        system.processes = [Fixtures.spotify]
        settings.isEnabled = false
        drainMainQueue()

        setTriggered(true)
        XCTAssertFalse(controller.isDucked)
        XCTAssertTrue(system.createdTaps.isEmpty)
    }

    func testTriggerSettingsAreSyncedToTheTriggerSource() {
        XCTAssertTrue(trigger.triggerBundleIDs.contains("com.granola.app"))

        settings.setTriggerBundleID("com.granola.app", enabled: false)
        settings.triggerAllApps = true
        drainMainQueue()

        XCTAssertFalse(trigger.triggerBundleIDs.contains("com.granola.app"))
        XCTAssertTrue(trigger.triggerAllApps)
        XCTAssertEqual(trigger.rootBundleIDResolver?("com.granola.app.helper"), "com.granola.app")
    }

    func testDuckLevelSliderUpdatesLiveTaps() {
        system.processes = [Fixtures.spotify]
        setTriggered(true)

        controller.updateDuckLevel(40)

        XCTAssertEqual(system.liveTap(pid: Fixtures.spotify.pid)?.levelUpdates.last, 0.4)
    }
}
