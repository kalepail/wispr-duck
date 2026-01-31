import Foundation
import SwiftUI

private let duckBundleIDsKey = "duckBundleIDs3"
private let triggerBundleIDsKey = "triggerBundleIDs3"

final class AppSettings: ObservableObject {
    @AppStorage("isEnabled") var isEnabled: Bool = true
    @AppStorage("duckLevel") var duckLevel: Int = 10
    @AppStorage("duckAllApps") var duckAllAudio: Bool = false
    @AppStorage("triggerAllApps2") var triggerAllApps: Bool = false

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
        "com.electron.wispr-flow",
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
        var ids = enabledBundleIDs
        if ids.contains(bundleID) { ids.remove(bundleID) } else { ids.insert(bundleID) }
        enabledBundleIDs = ids
        objectWillChange.send()
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
        var ids = triggerBundleIDs
        if ids.contains(bundleID) { ids.remove(bundleID) } else { ids.insert(bundleID) }
        triggerBundleIDs = ids
        objectWillChange.send()
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
}
