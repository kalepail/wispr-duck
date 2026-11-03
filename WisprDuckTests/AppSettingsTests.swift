import XCTest

final class AppSettingsTests: XCTestCase {
    func testFreshInstallDefaults() {
        let settings = AppSettings(defaults: makeIsolatedDefaults())
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.duckLevel, 10)
        XCTAssertFalse(settings.duckAllApps)
        XCTAssertFalse(settings.triggerAllApps)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.triggerBundleIDs, AppSettings.defaultTriggerBundleIDs)
        XCTAssertEqual(settings.enabledBundleIDs, AppSettings.defaultDuckBundleIDs)
    }

    func testGranolaIsNotADefaultTrigger() {
        // Granola also uses the mic for whole-meeting transcription, so it is opt-in.
        XCTAssertFalse(AppSettings.defaultTriggerBundleIDs.contains("com.granola.app"))
        XCTAssertTrue(AppSettings.knownDictationBundleIDs.contains("com.granola.app"))
    }

    func testSelectingGranolaTriggerPersistsAcrossLaunches() {
        let defaults = makeIsolatedDefaults()
        let first = AppSettings(defaults: defaults)
        first.setTriggerBundleID("com.granola.app", enabled: true)

        let relaunched = AppSettings(defaults: defaults)
        XCTAssertTrue(relaunched.isTriggerBundleIDEnabled("com.granola.app"))
        XCTAssertTrue(relaunched.isTriggerBundleIDEnabled(AppSettings.wisprFlowBundleID))
    }

    func testMigrationAddsWisprHelperForExistingWisprSelection() {
        let defaults = makeIsolatedDefaults()
        defaults.set(AppSettings.encode([AppSettings.wisprFlowBundleID, "com.granola.app"]), forKey: AppSettings.Keys.triggerBundleIDs)

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.triggerBundleIDs, [
            AppSettings.wisprFlowBundleID,
            AppSettings.wisprFlowHelperBundleID,
            "com.granola.app",
        ])
    }

    func testMigrationRunsOnlyOnce() {
        let defaults = makeIsolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.setTriggerBundleID(AppSettings.wisprFlowHelperBundleID, enabled: false)

        let relaunched = AppSettings(defaults: defaults)
        XCTAssertFalse(relaunched.isTriggerBundleIDEnabled(AppSettings.wisprFlowHelperBundleID))
    }

    func testMigrationLeavesNonWisprSelectionsAlone() {
        let defaults = makeIsolatedDefaults()
        defaults.set(AppSettings.encode(["com.granola.app"]), forKey: AppSettings.Keys.triggerBundleIDs)

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.triggerBundleIDs, ["com.granola.app"])
    }

    func testOutOfRangeStoredDuckLevelIsClamped() {
        let defaults = makeIsolatedDefaults()
        defaults.set(150, forKey: AppSettings.Keys.duckLevel)
        XCTAssertEqual(AppSettings(defaults: defaults).duckLevel, 100)

        defaults.set(-5, forKey: AppSettings.Keys.duckLevel)
        XCTAssertEqual(AppSettings(defaults: defaults).duckLevel, 0)
    }

    func testSettingDuckLevelClampsAndPersists() {
        let defaults = makeIsolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.duckLevel = 200
        XCTAssertEqual(settings.duckLevel, 100)
        XCTAssertEqual(defaults.integer(forKey: AppSettings.Keys.duckLevel), 100)

        settings.duckLevel = 35
        XCTAssertEqual(AppSettings(defaults: defaults).duckLevel, 35)
    }

    func testCorruptStoredSelectionDecodesAsEmpty() {
        let defaults = makeIsolatedDefaults()
        defaults.set("not json", forKey: AppSettings.Keys.duckBundleIDs)
        XCTAssertEqual(AppSettings(defaults: defaults).enabledBundleIDs, [])
    }

    func testEncodingIsStable() {
        let ids: Set<String> = ["c", "a", "b"]
        XCTAssertEqual(AppSettings.encode(ids), #"["a","b","c"]"#)
        XCTAssertEqual(AppSettings.decodeBundleIDs(json: AppSettings.encode(ids)), ids)
    }

    func testChangesNotifyObserver() {
        let settings = AppSettings(defaults: makeIsolatedDefaults())
        var notifications = 0
        settings.onSettingsChanged = { notifications += 1 }

        settings.toggleTriggerBundleID("com.granola.app")
        settings.isEnabled = false
        settings.duckAllApps = true

        XCTAssertGreaterThanOrEqual(notifications, 3)
    }
}
