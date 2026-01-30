import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("isEnabled") var isEnabled: Bool = true
    @AppStorage("duckLevel") var duckLevel: Int = 20
    @AppStorage("debounceDelay") var debounceDelay: Double = 2.0
    @AppStorage("duckSystemVolume") var duckSystemVolume: Bool = false
    @AppStorage("enabledAppIDs") private var enabledAppIDsJSON: String = "[]"

    var enabledAppIDs: Set<String> {
        get {
            guard let data = enabledAppIDsJSON.data(using: .utf8),
                  let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                enabledAppIDsJSON = json
            }
        }
    }

    /// Only installed apps, sorted with running apps first.
    var configuredApps: [MusicApp] {
        MusicApp.registry
            .filter { $0.isInstalled }
            .sorted { lhs, rhs in
                if lhs.isRunning != rhs.isRunning { return lhs.isRunning }
                return lhs.displayName < rhs.displayName
            }
    }

    var enabledApps: [MusicApp] {
        MusicApp.registry.filter { $0.isInstalled && enabledAppIDs.contains($0.id) }
    }

    func isAppEnabled(_ app: MusicApp) -> Bool {
        enabledAppIDs.contains(app.id)
    }

    func toggleApp(_ app: MusicApp) {
        var ids = enabledAppIDs
        if ids.contains(app.id) {
            ids.remove(app.id)
        } else {
            ids.insert(app.id)
        }
        enabledAppIDs = ids
        objectWillChange.send()
    }

    /// Initialize default enabled apps if never set — only installed apps.
    func initializeDefaultsIfNeeded() {
        if enabledAppIDsJSON == "[]" {
            enabledAppIDs = Set(MusicApp.registry.filter(\.isInstalled).map(\.id))
        }
    }
}
