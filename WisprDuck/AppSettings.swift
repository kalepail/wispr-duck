import SwiftUI

private let duckBundleIDsKey = "duckBundleIDs3"
private let triggerBundleIDsKey = "triggerBundleIDs3"
private let wisprFlowHelperTriggerMigrationKey = "wisprFlowHelperTriggerMigration1"
private let wisprFlowBundleID = "com.electron.wispr-flow"
private let wisprFlowHelperBundleID = "com.electron.wispr-flow.accessibility-mac-app"

@Observable
final class AppSettings {
    /// Called whenever a setting changes, so non-SwiftUI observers (e.g. DuckController) can react.
    var onSettingsChanged: (() -> Void)?

    var isEnabled: Bool = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled"); onSettingsChanged?() }
    }
    var duckLevel: Int = UserDefaults.standard.object(forKey: "duckLevel") as? Int ?? 10 {
        didSet { UserDefaults.standard.set(duckLevel, forKey: "duckLevel"); onSettingsChanged?() }
    }
    var duckAllApps: Bool = UserDefaults.standard.object(forKey: "duckAllApps") as? Bool ?? false {
        didSet { UserDefaults.standard.set(duckAllApps, forKey: "duckAllApps"); onSettingsChanged?() }
    }
    var triggerAllApps: Bool = UserDefaults.standard.object(forKey: "triggerAllApps2") as? Bool ?? false {
        didSet { UserDefaults.standard.set(triggerAllApps, forKey: "triggerAllApps2"); onSettingsChanged?() }
    }
    var hasCompletedOnboarding: Bool = UserDefaults.standard.object(forKey: "hasCompletedOnboarding") as? Bool ?? false {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Default Selections

    static let defaultDuckBundleIDs: Set<String> = [
        // Music & streaming
        "com.spotify.client",
        "com.apple.Music",
        "com.tidal.desktop",
        "com.amazon.music",
        "com.deezer.deezer-desktop",
        "com.pandora.desktop",

        // Browsers
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",       // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",

        // Video & media
        "org.videolan.vlc",
        "com.colliderli.iina",
        "com.apple.QuickTimePlayerX",

        // Podcasts
        "com.apple.podcasts",
        "fm.overcast.overcast",
        "au.com.shiftyjelly.podcasts",      // Pocket Casts
    ]

    static let defaultTriggerBundleIDs: Set<String> = [
        wisprFlowBundleID,
        wisprFlowHelperBundleID,
    ]

    init() {
        // register(defaults:) provides values only when the key has never been written.
        // No @AppStorage wrapper on these keys, so nothing pre-empts the registration.
        var defaults: [String: Any] = [:]
        if let data = try? JSONEncoder().encode(Self.defaultDuckBundleIDs),
           let json = String(data: data, encoding: .utf8) {
            defaults[duckBundleIDsKey] = json
        }
        if let data = try? JSONEncoder().encode(Self.defaultTriggerBundleIDs),
           let json = String(data: data, encoding: .utf8) {
            defaults[triggerBundleIDsKey] = json
        }
        UserDefaults.standard.register(defaults: defaults)
        migrateWisprFlowHelperTriggerSelection()
    }

    // MARK: - Duck Target Bundle IDs

    var enabledBundleIDs: Set<String> {
        get { decodeBundleIDs(key: duckBundleIDsKey) }
        set { encodeBundleIDs(newValue, key: duckBundleIDsKey) }
    }

    func isBundleIDEnabled(_ bundleID: String) -> Bool {
        enabledBundleIDs.contains(bundleID)
    }

    func toggleBundleID(_ bundleID: String) {
        setBundleID(bundleID, enabled: !enabledBundleIDs.contains(bundleID))
    }

    func setBundleID(_ bundleID: String, enabled: Bool) {
        var ids = enabledBundleIDs
        if enabled {
            ids.insert(bundleID)
        } else {
            ids.remove(bundleID)
        }
        enabledBundleIDs = ids
        onSettingsChanged?()
    }

    // MARK: - Trigger Bundle IDs

    var triggerBundleIDs: Set<String> {
        get { decodeBundleIDs(key: triggerBundleIDsKey) }
        set { encodeBundleIDs(newValue, key: triggerBundleIDsKey) }
    }

    func isTriggerBundleIDEnabled(_ bundleID: String) -> Bool {
        triggerBundleIDs.contains(bundleID)
    }

    func toggleTriggerBundleID(_ bundleID: String) {
        setTriggerBundleID(bundleID, enabled: !triggerBundleIDs.contains(bundleID))
    }

    func setTriggerBundleID(_ bundleID: String, enabled: Bool) {
        var ids = triggerBundleIDs
        if enabled {
            ids.insert(bundleID)
        } else {
            ids.remove(bundleID)
        }
        triggerBundleIDs = ids
        onSettingsChanged?()
    }

    // MARK: - Helpers

    private func decodeBundleIDs(key: String) -> Set<String> {
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return ids
    }

    private func encodeBundleIDs(_ ids: Set<String>, key: String) {
        if let data = try? JSONEncoder().encode(ids),
           let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: key)
        }
    }

    private func migrateWisprFlowHelperTriggerSelection() {
        guard !UserDefaults.standard.bool(forKey: wisprFlowHelperTriggerMigrationKey) else { return }

        var ids = triggerBundleIDs
        if ids.contains(wisprFlowBundleID), !ids.contains(wisprFlowHelperBundleID) {
            ids.insert(wisprFlowHelperBundleID)
            triggerBundleIDs = ids
        }

        UserDefaults.standard.set(true, forKey: wisprFlowHelperTriggerMigrationKey)
    }
}
