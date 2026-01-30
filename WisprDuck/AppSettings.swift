import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("isEnabled") var isEnabled: Bool = true
    @AppStorage("duckLevel") var duckLevel: Int = 20
    @AppStorage("duckAllAudio") var duckAllAudio: Bool = true
    @AppStorage("enabledBundleIDs") private var enabledBundleIDsJSON: String = "[]"

    /// Bundle IDs the user has selected for ducking (used when duckAllAudio is false).
    var enabledBundleIDs: Set<String> {
        get {
            guard let data = enabledBundleIDsJSON.data(using: .utf8),
                  let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                enabledBundleIDsJSON = json
            }
        }
    }

    func isBundleIDEnabled(_ bundleID: String) -> Bool {
        enabledBundleIDs.contains(bundleID)
    }

    func toggleBundleID(_ bundleID: String) {
        var ids = enabledBundleIDs
        if ids.contains(bundleID) {
            ids.remove(bundleID)
        } else {
            ids.insert(bundleID)
        }
        enabledBundleIDs = ids
        objectWillChange.send()
    }
}
