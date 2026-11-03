import SwiftUI

@Observable
final class AppSettings {
    /// UserDefaults keys. Exposed so diagnostics (scripts/mic-probe.sh) read the same values.
    enum Keys {
        static let isEnabled = "isEnabled"
        static let duckLevel = "duckLevel"
        static let duckAllApps = "duckAllApps"
        static let triggerAllApps = "triggerAllApps2"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let duckBundleIDs = "duckBundleIDs3"
        static let triggerBundleIDs = "triggerBundleIDs3"
        static let wisprFlowHelperTriggerMigration = "wisprFlowHelperTriggerMigration1"
    }

    static let wisprFlowBundleID = "com.electron.wispr-flow"
    static let wisprFlowHelperBundleID = "com.electron.wispr-flow.accessibility-mac-app"
    static let duckLevelRange = 0...100

    @ObservationIgnored private let defaults: UserDefaults

    /// Called whenever a setting changes, so non-SwiftUI observers (e.g. DuckController) can react.
    @ObservationIgnored var onSettingsChanged: (() -> Void)?

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled); onSettingsChanged?() }
    }
    var duckLevel: Int {
        didSet {
            let clamped = Self.clampDuckLevel(duckLevel)
            if clamped != duckLevel { duckLevel = clamped }
            defaults.set(clamped, forKey: Keys.duckLevel)
            onSettingsChanged?()
        }
    }
    var duckAllApps: Bool {
        didSet { defaults.set(duckAllApps, forKey: Keys.duckAllApps); onSettingsChanged?() }
    }
    var triggerAllApps: Bool {
        didSet { defaults.set(triggerAllApps, forKey: Keys.triggerAllApps); onSettingsChanged?() }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    static func clampDuckLevel(_ level: Int) -> Int {
        min(duckLevelRange.upperBound, max(duckLevelRange.lowerBound, level))
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

    /// Apps known to do dictation. Shown here for reference and used by
    /// diagnostics; only Wispr Flow is a default trigger, because Granola also
    /// uses the mic for whole-meeting transcription (see README).
    static let knownDictationBundleIDs: Set<String> = [
        wisprFlowBundleID,
        wisprFlowHelperBundleID,
        "com.granola.app",
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        duckLevel = Self.clampDuckLevel(defaults.object(forKey: Keys.duckLevel) as? Int ?? 10)
        duckAllApps = defaults.object(forKey: Keys.duckAllApps) as? Bool ?? false
        triggerAllApps = defaults.object(forKey: Keys.triggerAllApps) as? Bool ?? false
        hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false

        // register(defaults:) provides values only when the key has never been written.
        // No @AppStorage wrapper on these keys, so nothing pre-empts the registration.
        var registered: [String: Any] = [:]
        if let json = Self.encode(Self.defaultDuckBundleIDs) {
            registered[Keys.duckBundleIDs] = json
        }
        if let json = Self.encode(Self.defaultTriggerBundleIDs) {
            registered[Keys.triggerBundleIDs] = json
        }
        defaults.register(defaults: registered)
        migrateWisprFlowHelperTriggerSelection()
    }

    // MARK: - Duck Target Bundle IDs

    var enabledBundleIDs: Set<String> {
        get { decodeBundleIDs(key: Keys.duckBundleIDs) }
        set { encodeBundleIDs(newValue, key: Keys.duckBundleIDs) }
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
        get { decodeBundleIDs(key: Keys.triggerBundleIDs) }
        set { encodeBundleIDs(newValue, key: Keys.triggerBundleIDs) }
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

    /// Decode a stored bundle ID set. Shared with diagnostics.
    static func decodeBundleIDs(json: String?) -> Set<String>? {
        guard let json,
              let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return nil
        }
        return ids
    }

    /// Encode with sorted keys so the stored JSON is stable across launches.
    static func encode(_ ids: Set<String>) -> String? {
        guard let data = try? JSONEncoder().encode(ids.sorted()) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeBundleIDs(key: String) -> Set<String> {
        Self.decodeBundleIDs(json: defaults.string(forKey: key)) ?? []
    }

    private func encodeBundleIDs(_ ids: Set<String>, key: String) {
        if let json = Self.encode(ids) {
            defaults.set(json, forKey: key)
        }
    }

    private func migrateWisprFlowHelperTriggerSelection() {
        guard !defaults.bool(forKey: Keys.wisprFlowHelperTriggerMigration) else { return }

        var ids = triggerBundleIDs
        if ids.contains(Self.wisprFlowBundleID), !ids.contains(Self.wisprFlowHelperBundleID) {
            ids.insert(Self.wisprFlowHelperBundleID)
            triggerBundleIDs = ids
        }

        defaults.set(true, forKey: Keys.wisprFlowHelperTriggerMigration)
    }
}
