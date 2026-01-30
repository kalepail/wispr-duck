import Foundation
import AppKit

struct MusicApp: Identifiable, Hashable {
    let id: String
    let displayName: String
    let processName: String
    let bundleID: String

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    var getVolumeScript: String {
        switch id {
        case "spotify":
            return "tell application \"Spotify\" to get sound volume"
        case "appleMusic":
            return "tell application \"Music\" to get sound volume"
        case "vlc":
            return """
            tell application "VLC"
                set vol to audio volume
                return round (vol / 2.56)
            end tell
            """
        case "vox":
            return "tell application \"Vox\" to get player volume"
        default:
            return ""
        }
    }

    func setVolumeScript(volume: Int) -> String {
        let clamped = max(0, min(100, volume))
        switch id {
        case "spotify":
            return "tell application \"Spotify\" to set sound volume to \(clamped)"
        case "appleMusic":
            return "tell application \"Music\" to set sound volume to \(clamped)"
        case "vlc":
            let vlcVol = Int(round(Double(clamped) * 2.56))
            return "tell application \"VLC\" to set audio volume to \(vlcVol)"
        case "vox":
            return "tell application \"Vox\" to set player volume to \(clamped)"
        default:
            return ""
        }
    }

    static let registry: [MusicApp] = [
        MusicApp(
            id: "spotify",
            displayName: "Spotify",
            processName: "Spotify",
            bundleID: "com.spotify.client"
        ),
        MusicApp(
            id: "appleMusic",
            displayName: "Apple Music",
            processName: "Music",
            bundleID: "com.apple.Music"
        ),
        MusicApp(
            id: "vlc",
            displayName: "VLC",
            processName: "VLC",
            bundleID: "org.videolan.vlc"
        ),
        MusicApp(
            id: "vox",
            displayName: "Vox",
            processName: "Vox",
            bundleID: "com.coppertino.Vox"
        ),
    ]

    static func find(byID id: String) -> MusicApp? {
        registry.first { $0.id == id }
    }
}
