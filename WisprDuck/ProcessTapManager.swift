import Foundation
import CoreAudio
import AppKit

/// Identifies an audio-producing process discovered via Core Audio.
struct AudioProcess: Identifiable, Hashable {
    let pid: pid_t
    let objectID: AudioObjectID
    let bundleID: String?
    let name: String

    var id: pid_t { pid }

    static func == (lhs: AudioProcess, rhs: AudioProcess) -> Bool {
        lhs.pid == rhs.pid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
}

/// A deduplicated audio app for the UI, grouped by root app bundle ID.
struct AudioApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

/// Manages per-process audio taps for volume ducking.
/// Enumerates audio-producing processes, creates/destroys ProcessTap instances,
/// and monitors for new audio processes appearing while ducked.
final class ProcessTapManager {
    private var activeTaps: [pid_t: ProcessTap] = [:]
    private var processListListenerBlock: AudioObjectPropertyListenerBlock?
    private let listenerQueue = DispatchQueue(label: "com.wisprduck.processmonitor", qos: .userInitiated)
    private var isDucking = false
    private var currentDuckLevel: Float = 1.0
    private var currentBundleIDs: Set<String> = []
    private var duckAllMode = false
    private var fadeOutTimer: DispatchWorkItem?
    private var onProcessListChanged: (([AudioProcess]) -> Void)?

    /// Cache for bundle ID → root app bundle ID resolution.
    /// Avoids repeated NSWorkspace lookups for the same helper bundle IDs.
    private var rootBundleIDCache: [String: String] = [:]

    // MARK: - Root App Resolution

    /// Resolves a helper/subprocess bundle ID to its parent app's bundle ID.
    /// e.g., "com.google.Chrome.helper.Renderer" → "com.google.Chrome"
    ///
    /// Walks up the bundle ID hierarchy (stripping trailing components) until
    /// it finds a top-level app. Helper apps embedded inside a parent .app
    /// (e.g., Chrome Helper.app inside Chrome.app) are skipped — only the
    /// outermost app counts.
    func rootAppBundleID(for bundleID: String) -> String {
        if let cached = rootBundleIDCache[bundleID] {
            return cached
        }

        var components = bundleID.split(separator: ".").map(String.init)

        // Try progressively shorter prefixes until we find a top-level app
        while components.count > 2 {
            let candidate = components.joined(separator: ".")
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate),
               isTopLevelApp(url) {
                rootBundleIDCache[bundleID] = candidate
                return candidate
            }
            components.removeLast()
        }

        // No parent app found — use original
        rootBundleIDCache[bundleID] = bundleID
        return bundleID
    }

    /// Check if an app URL is a top-level app (not nested inside another .app bundle).
    /// e.g., "/Applications/Chrome.app" → true
    ///       "/Applications/Chrome.app/Contents/Frameworks/Chrome Helper.app" → false
    private func isTopLevelApp(_ url: URL) -> Bool {
        let appExtensions = url.pathComponents.filter { $0.hasSuffix(".app") }
        return appExtensions.count <= 1
    }

    // MARK: - Process Enumeration

    /// Returns all processes currently producing audio, excluding our own process.
    func enumerateAudioProcesses() -> [AudioProcess] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Get size
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size
        )
        guard status == noErr, size > 0 else { return [] }

        // Get process object IDs
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &objectIDs
        )
        guard status == noErr else { return [] }

        let myPID = ProcessInfo.processInfo.processIdentifier

        return objectIDs.compactMap { objectID -> AudioProcess? in
            guard let pid = pidForProcessObject(objectID), pid != myPID else { return nil }
            let app = NSRunningApplication(processIdentifier: pid)
            var bundleID = app?.bundleIdentifier
            var name = app?.localizedName

            // Many audio-producing processes (e.g. Chrome renderer subprocesses)
            // have no NSRunningApplication entry. Walk up the process tree to
            // inherit the parent app's bundle ID for grouping and selection.
            if bundleID == nil, let ppid = parentPID(of: pid) {
                let parentApp = NSRunningApplication(processIdentifier: ppid)
                bundleID = parentApp?.bundleIdentifier
                if name == nil { name = parentApp?.localizedName }
            }

            return AudioProcess(pid: pid, objectID: objectID, bundleID: bundleID, name: name ?? "PID \(pid)")
        }
    }

    /// Returns deduplicated apps grouped by root app bundle ID.
    /// "Google Chrome Helper (Renderer)" groups under "Google Chrome".
    func audioApps(from processes: [AudioProcess]) -> [AudioApp] {
        var seen = Set<String>()
        var apps: [AudioApp] = []

        for process in processes {
            guard let bid = process.bundleID else { continue }
            let rootBID = rootAppBundleID(for: bid)
            guard !seen.contains(rootBID) else { continue }
            seen.insert(rootBID)

            // Use the root app's name from running applications
            let rootApp = NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == rootBID
            }
            let name = rootApp?.localizedName ?? process.name
            apps.append(AudioApp(bundleID: rootBID, name: name))
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Check if a process's bundle ID matches any of the selected bundle IDs,
    /// resolving helpers to their parent app.
    private func processMatchesSelection(_ process: AudioProcess, selectedBundleIDs: Set<String>) -> Bool {
        guard let bid = process.bundleID else { return false }
        let rootBID = rootAppBundleID(for: bid)
        return selectedBundleIDs.contains(rootBID)
    }

    // MARK: - Duck / Restore

    /// Duck audio for processes matching the given bundle IDs.
    /// If bundleIDs is empty and duckAll is true, ducks all audio processes.
    /// If called during a fade-out, cancels the fade and reuses existing taps.
    func duck(bundleIDs: Set<String>, duckAll: Bool, duckLevel: Float) {
        // Cancel any pending fade-out destruction
        fadeOutTimer?.cancel()
        fadeOutTimer = nil

        guard let outputUID = getDefaultOutputDeviceUID() else {
            print("ProcessTapManager: Could not get output device UID")
            return
        }

        isDucking = true
        currentDuckLevel = duckLevel
        currentBundleIDs = bundleIDs
        duckAllMode = duckAll

        // Update existing taps (e.g. re-ducking after a cancelled fade-out)
        for (_, tap) in activeTaps {
            tap.updateDuckLevel(duckLevel)
        }

        // Create taps for any new matching processes
        let processes = enumerateAudioProcesses()
        let toDuck = processes.filter { process in
            guard activeTaps[process.pid] == nil else { return false }
            if duckAll { return true }
            return processMatchesSelection(process, selectedBundleIDs: bundleIDs)
        }

        for process in toDuck {
            let tap = ProcessTap(
                processObjectID: process.objectID,
                pid: process.pid,
                bundleID: process.bundleID
            )
            if tap.start(outputDeviceUID: outputUID, duckLevel: duckLevel) {
                activeTaps[process.pid] = tap
            }
        }
    }

    /// Restore all ducked processes immediately. Used for app quit where
    /// we can't wait for a fade.
    func restoreAll() {
        isDucking = false
        fadeOutTimer?.cancel()
        fadeOutTimer = nil

        for (_, tap) in activeTaps {
            tap.stop()
        }
        activeTaps.removeAll()
    }

    /// Smoothly restore audio by ramping volume back to 1.0 before destroying taps.
    /// Taps stay in activeTaps during the fade so duck() can cancel and reuse them.
    /// The one-pole ramp (~200ms time constant) settles to 99% in ~1s.
    func restoreAllWithFade() {
        isDucking = false

        // Ramp all taps toward full volume
        for (_, tap) in activeTaps {
            tap.updateDuckLevel(1.0)
        }

        // Schedule tap destruction after the ramp settles.
        // If duck() is called before this fires, it cancels the timer and reuses the taps.
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            for (_, tap) in self.activeTaps {
                tap.stop()
            }
            self.activeTaps.removeAll()
            self.fadeOutTimer = nil
        }
        fadeOutTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    /// Update duck level for all active taps.
    func updateDuckLevel(_ level: Float) {
        currentDuckLevel = level
        for (_, tap) in activeTaps {
            tap.updateDuckLevel(level)
        }
    }

    // MARK: - Process List Monitoring

    /// Start monitoring the audio process list. Always-on for UI updates;
    /// also creates/removes taps dynamically while ducking is active.
    func startProcessListMonitoring() {
        guard processListListenerBlock == nil else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        processListListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleProcessListChanged()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            processListListenerBlock!
        )
    }

    private func stopProcessListMonitoring() {
        guard let block = processListListenerBlock else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            block
        )
        processListListenerBlock = nil
    }

    private func handleProcessListChanged() {
        // Single enumeration, shared between UI update and tap management
        let processes = enumerateAudioProcesses()

        // Always notify UI so the app list stays current
        onProcessListChanged?(processes)

        // Only manage taps while actively ducking
        guard isDucking else { return }

        guard let outputUID = getDefaultOutputDeviceUID() else { return }

        // Create taps for new matching processes
        let toDuck = processes.filter { process in
            guard activeTaps[process.pid] == nil else { return false }
            if duckAllMode { return true }
            return processMatchesSelection(process, selectedBundleIDs: currentBundleIDs)
        }

        for process in toDuck {
            let tap = ProcessTap(
                processObjectID: process.objectID,
                pid: process.pid,
                bundleID: process.bundleID
            )
            if tap.start(outputDeviceUID: outputUID, duckLevel: currentDuckLevel) {
                activeTaps[process.pid] = tap
            }
        }

        // Clean up taps for processes that have stopped producing audio
        let activePIDs = Set(processes.map(\.pid))
        let stalePIDs = activeTaps.keys.filter { !activePIDs.contains($0) }
        for pid in stalePIDs {
            activeTaps[pid]?.stop()
            activeTaps.removeValue(forKey: pid)
        }
    }

    /// Set a callback for when the process list changes (for UI updates).
    /// The callback receives the already-enumerated process list to avoid re-enumeration.
    func setProcessListChangedHandler(_ handler: @escaping ([AudioProcess]) -> Void) {
        onProcessListChanged = handler
    }

    // MARK: - Output Device Helpers

    private func getDefaultOutputDeviceUID() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid)
        guard status == noErr else { return nil }
        return uid as String
    }

    // MARK: - PID Translation

    /// Get the parent PID of a process via sysctl.
    private func parentPID(of pid: pid_t) -> pid_t? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 1 ? ppid : nil
    }

    private func pidForProcessObject(_ objectID: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)

        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &pid)
        guard status == noErr, pid > 0 else { return nil }
        return pid
    }

    deinit {
        stopProcessListMonitoring()
        restoreAll()
    }
}
