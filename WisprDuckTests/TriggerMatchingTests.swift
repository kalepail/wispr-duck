import AppKit
import XCTest

final class BundleIDResolutionTests: XCTestCase {
    private let system = FakeAudioSystem.withKnownApps()

    private func root(_ bundleID: String) -> String {
        BundleIDResolution.rootAppBundleID(for: bundleID, applicationURL: { self.system.applicationURLs[$0] })
    }

    func testGranolaHelpersResolveToGranolaApp() {
        XCTAssertEqual(root("com.granola.app.helper"), "com.granola.app")
        XCTAssertEqual(root("com.granola.app.helper.Renderer"), "com.granola.app")
        XCTAssertEqual(root("com.granola.app"), "com.granola.app")
    }

    func testWisprFlowNestedHelperResolvesToMainApp() {
        // The Swift helper lives inside Wispr Flow.app, so it is not a top-level app.
        XCTAssertEqual(root("com.electron.wispr-flow.accessibility-mac-app"), "com.electron.wispr-flow")
    }

    func testChromeHelperResolvesToChrome() {
        XCTAssertEqual(root("com.google.Chrome.helper"), "com.google.Chrome")
        XCTAssertEqual(root("com.google.Chrome.helper.Renderer"), "com.google.Chrome")
    }

    func testUnknownAndShortIDsReturnThemselves() {
        XCTAssertEqual(root("org.example.unknown.tool"), "org.example.unknown.tool")
        XCTAssertEqual(root("com.example"), "com.example")
    }

    func testTopLevelAppDetection() {
        XCTAssertTrue(BundleIDResolution.isTopLevelApp(URL(fileURLWithPath: "/Applications/Granola.app")))
        XCTAssertFalse(BundleIDResolution.isTopLevelApp(
            URL(fileURLWithPath: "/Applications/Granola.app/Contents/Frameworks/Granola Helper.app")
        ))
    }

    /// Uses the real Launch Services database. Skipped where Granola is not installed (CI).
    func testLiveGranolaInstallResolvesHelpers() throws {
        let workspace = NSWorkspace.shared
        try XCTSkipIf(
            workspace.urlForApplication(withBundleIdentifier: "com.granola.app") == nil,
            "Granola is not installed"
        )
        let lookup: (String) -> URL? = { workspace.urlForApplication(withBundleIdentifier: $0) }
        XCTAssertEqual(BundleIDResolution.rootAppBundleID(for: "com.granola.app.helper", applicationURL: lookup), "com.granola.app")
        XCTAssertEqual(BundleIDResolution.rootAppBundleID(for: "com.granola.app.helper.Renderer", applicationURL: lookup), "com.granola.app")
    }
}

final class TriggerMatcherTests: XCTestCase {
    private let system = FakeAudioSystem.withKnownApps()

    private func shouldTrigger(
        inputProcessCount: Int? = nil,
        inputs: [String],
        triggerAll: Bool = false,
        triggers: Set<String>
    ) -> Bool {
        TriggerMatcher.shouldTrigger(
            inputProcessCount: inputProcessCount ?? (inputs.isEmpty ? 0 : 1),
            inputBundleIDs: inputs,
            triggerAllApps: triggerAll,
            triggerBundleIDs: triggers,
            resolveRoot: { BundleIDResolution.rootAppBundleID(for: $0, applicationURL: { self.system.applicationURLs[$0] }) }
        )
    }

    // Granola Voice Typing captures the mic in an Electron helper. MicMonitor
    // reports the helper plus its app ancestors.
    func testGranolaDictationTriggersWhenGranolaSelected() {
        XCTAssertTrue(shouldTrigger(inputs: ["com.granola.app.helper", "com.granola.app"], triggers: ["com.granola.app"]))
    }

    func testGranolaHelperAloneStillTriggers() {
        XCTAssertTrue(shouldTrigger(inputs: ["com.granola.app.helper"], triggers: ["com.granola.app"]))
    }

    func testGranolaDoesNotTriggerWithDefaultWisprTriggers() {
        XCTAssertFalse(shouldTrigger(
            inputs: ["com.granola.app.helper", "com.granola.app"],
            triggers: AppSettings.defaultTriggerBundleIDs
        ))
    }

    func testWisprFlowNestedHelperTriggersWithDefaults() {
        XCTAssertTrue(shouldTrigger(
            inputs: ["com.electron.wispr-flow.accessibility-mac-app"],
            triggers: AppSettings.defaultTriggerBundleIDs
        ))
    }

    func testRawHelperIDMatchesEvenIfResolutionDiffers() {
        let result = TriggerMatcher.shouldTrigger(
            inputProcessCount: 1,
            inputBundleIDs: ["com.electron.wispr-flow.accessibility-mac-app"],
            triggerAllApps: false,
            triggerBundleIDs: ["com.electron.wispr-flow.accessibility-mac-app"],
            resolveRoot: { _ in "something.else.entirely" }
        )
        XCTAssertTrue(result)
    }

    func testNoMicAppsDoesNotTrigger() {
        XCTAssertFalse(shouldTrigger(inputs: [], triggers: ["com.granola.app"]))
    }

    func testUnselectedMicAppDoesNotTrigger() {
        XCTAssertFalse(shouldTrigger(inputs: ["us.zoom.xos"], triggers: ["com.granola.app"]))
    }

    func testTriggerAllAppsFollowsAnyMicActivity() {
        XCTAssertTrue(shouldTrigger(inputs: ["com.granola.app"], triggerAll: true, triggers: []))
        XCTAssertFalse(shouldTrigger(inputs: [], triggerAll: true, triggers: []))
    }

    /// A CLI recorder has no app bundle in its ancestry but still uses the mic.
    func testTriggerAllAppsCountsUnbundledRecorders() {
        XCTAssertTrue(shouldTrigger(inputProcessCount: 1, inputs: [], triggerAll: true, triggers: []))
        XCTAssertFalse(shouldTrigger(inputProcessCount: 1, inputs: [], triggerAll: false, triggers: ["com.granola.app"]))
    }

    /// Regression: playback on a duplex interface (Scarlett 2i2) set the input
    /// device's "running somewhere" flag and triggered ducking in trigger-all
    /// mode. Only processes that run mic input count now.
    func testTriggerAllAppsIgnoresPlaybackWithNoInputProcesses() {
        XCTAssertFalse(shouldTrigger(inputProcessCount: 0, inputs: [], triggerAll: true, triggers: []))
    }
}

final class MicInputClassifierTests: XCTestCase {
    func testProcessThatIsNotRunningInputIsNotAMicUser() {
        XCTAssertFalse(MicInputClassifier.isUsingMic(isRunningInput: false, inputDeviceCount: 1))
        XCTAssertFalse(MicInputClassifier.isUsingMic(isRunningInput: false, inputDeviceCount: nil))
    }

    func testProcessReadingAMicDeviceIsAMicUser() {
        XCTAssertTrue(MicInputClassifier.isUsingMic(isRunningInput: true, inputDeviceCount: 1))
        XCTAssertTrue(MicInputClassifier.isUsingMic(isRunningInput: true, inputDeviceCount: 2))
    }

    /// Regression: an app that only reads a process tap (a system-audio
    /// recorder or level meter) is "running input" with no input device.
    /// In Trigger All mode it ducked audio with no mic in use.
    func testTapOnlyReaderIsNotAMicUser() {
        XCTAssertFalse(MicInputClassifier.isUsingMic(isRunningInput: true, inputDeviceCount: 0))
    }

    func testFailedDeviceQueryStillCountsAsMicUse() {
        XCTAssertTrue(MicInputClassifier.isUsingMic(isRunningInput: true, inputDeviceCount: nil))
    }
}
