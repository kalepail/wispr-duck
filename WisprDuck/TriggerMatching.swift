import Foundation

/// Pure bundle-ID logic shared by mic trigger matching and duck target grouping.
/// Kept free of Core Audio and AppKit state so it can be unit tested.
enum BundleIDResolution {
    /// Resolves a helper/subprocess bundle ID to its parent app's bundle ID.
    /// e.g., "com.google.Chrome.helper.Renderer" → "com.google.Chrome"
    ///       "com.granola.app.helper" → "com.granola.app"
    ///
    /// Walks up the bundle ID hierarchy (stripping trailing components) until
    /// it finds a top-level app. Helper apps embedded inside a parent .app
    /// (e.g., Chrome Helper.app inside Chrome.app) are skipped — only the
    /// outermost app counts. Returns the original ID when no parent app exists.
    static func rootAppBundleID(for bundleID: String, applicationURL: (String) -> URL?) -> String {
        var components = bundleID.split(separator: ".").map(String.init)

        while components.count > 2 {
            let candidate = components.joined(separator: ".")
            if let url = applicationURL(candidate), isTopLevelApp(url) {
                return candidate
            }
            components.removeLast()
        }

        return bundleID
    }

    /// Check if an app URL is a top-level app (not nested inside another .app bundle).
    /// e.g., "/Applications/Chrome.app" → true
    ///       "/Applications/Chrome.app/Contents/Frameworks/Chrome Helper.app" → false
    static func isTopLevelApp(_ url: URL) -> Bool {
        url.pathComponents.filter { $0.hasSuffix(".app") }.count <= 1
    }
}

enum MicInputClassifier {
    /// Decide whether a process that Core Audio reports as "running input"
    /// really uses a microphone.
    ///
    /// Reading a process tap (recording other apps' audio) also sets
    /// kAudioProcessPropertyIsRunningInput, but such a process lists no input
    /// device. Screen recorders, meeting recorders, and audio meters would
    /// otherwise trigger ducking with no mic in use.
    ///
    /// - Parameters:
    ///   - isRunningInput: kAudioProcessPropertyIsRunningInput.
    ///   - inputDeviceCount: Devices in kAudioProcessPropertyDevices (input
    ///     scope), or nil when the query failed. A failed query counts as mic
    ///     use, so a real dictation is never missed.
    static func isUsingMic(isRunningInput: Bool, inputDeviceCount: Int?) -> Bool {
        guard isRunningInput else { return false }
        guard let inputDeviceCount else { return true }
        return inputDeviceCount > 0
    }
}

enum TriggerMatcher {
    /// Decide whether the current mic activity should duck other audio.
    ///
    /// - Parameters:
    ///   - inputProcessCount: Processes (other than WisprDuck) running mic input,
    ///     including ones with no app bundle, such as CLI recorders.
    ///   - inputBundleIDs: Bundle IDs of processes using mic input, plus their app ancestors.
    ///   - triggerAllApps: When true, any mic use triggers ducking.
    ///   - triggerBundleIDs: The user's selected trigger apps.
    ///   - resolveRoot: Maps a helper bundle ID to its root app bundle ID.
    static func shouldTrigger(
        inputProcessCount: Int,
        inputBundleIDs: [String],
        triggerAllApps: Bool,
        triggerBundleIDs: Set<String>,
        resolveRoot: (String) -> String
    ) -> Bool {
        if triggerAllApps {
            // Use per-process input only. The device-level "running somewhere"
            // flag is also set by playback on duplex interfaces (e.g. a
            // Scarlett 2i2) and by WisprDuck's own aggregate devices, which
            // made trigger-all mode duck on playback and never restore.
            return inputProcessCount > 0 || !inputBundleIDs.isEmpty
        }

        // Match the raw ID as well as the resolved root, so an explicitly
        // selected helper ID (e.g. Wispr Flow's nested accessibility app)
        // still matches if Launch Services resolves it differently.
        return inputBundleIDs.contains { bundleID in
            triggerBundleIDs.contains(bundleID) || triggerBundleIDs.contains(resolveRoot(bundleID))
        }
    }
}
