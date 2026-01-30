import Foundation
import AppKit
import CoreAudio

final class VolumeController {
    private var originalVolumes: [String: Int] = [:]
    private var originalSystemVolume: Int?
    private let savedStateKey = "savedOriginalVolumes"
    private let savedSystemVolumeKey = "savedOriginalSystemVolume"
    private let isDuckedKey = "isCurrentlyDucked"

    // MARK: - AppleScript Helpers

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
            return false
        }
        return true
    }

    private func runAppleScriptReturningInt(_ source: String) -> Int? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
            return nil
        }
        return Int(result.int32Value)
    }

    // MARK: - Volume Control

    func getVolume(for app: MusicApp) -> Int? {
        guard app.isRunning else { return nil }
        return runAppleScriptReturningInt(app.getVolumeScript)
    }

    func setVolume(for app: MusicApp, volume: Int) {
        guard app.isRunning else { return }
        runAppleScript(app.setVolumeScript(volume: volume))
    }

    // MARK: - System Volume

    /// Check if the current output device supports software volume control.
    /// Runs AppleScript — call sparingly, not on every frame.
    func checkSystemVolumeAvailable() -> Bool {
        getSystemVolume() != nil
    }

    /// Read the name of the current default output device via CoreAudio.
    func readDefaultOutputDeviceName() -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return "Unknown" }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)

        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0, nil,
            &nameSize,
            &name
        )
        guard nameStatus == noErr else { return "Unknown" }
        return name as String
    }

    func getSystemVolume() -> Int? {
        // AppleScript returns "missing value" for output volume when the device
        // doesn't support software volume control. Handle it in the script itself
        // to avoid descriptor type ambiguity in NSAppleEventDescriptor.
        let script = """
        set vol to output volume of (get volume settings)
        if vol is missing value then
            return -1
        else
            return vol
        end if
        """
        guard let result = runAppleScriptReturningInt(script), result >= 0 else { return nil }
        return result
    }

    func setSystemVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        runAppleScript("set volume output volume \(clamped)")
    }

    private func duckSystemVolume(duckLevel: Int) {
        if originalSystemVolume == nil {
            originalSystemVolume = getSystemVolume()
        }
        setSystemVolume(duckLevel)
    }

    private func restoreSystemVolume() {
        if let original = originalSystemVolume {
            setSystemVolume(original)
            originalSystemVolume = nil
        }
    }

    // MARK: - Duck / Restore

    func duckAll(apps: [MusicApp], duckLevel: Int, duckSystem: Bool) {
        for app in apps {
            guard app.isRunning else { continue }
            if originalVolumes[app.id] == nil {
                if let currentVol = getVolume(for: app) {
                    originalVolumes[app.id] = currentVol
                }
            }
            setVolume(for: app, volume: duckLevel)
        }
        if duckSystem {
            duckSystemVolume(duckLevel: duckLevel)
        }
        persistState()
    }

    func restoreAll() {
        for (appID, volume) in originalVolumes {
            guard let app = MusicApp.find(byID: appID), app.isRunning else { continue }
            setVolume(for: app, volume: volume)
        }
        originalVolumes.removeAll()
        restoreSystemVolume()
        clearPersistedState()
    }

    // MARK: - Crash Recovery Persistence

    private func persistState() {
        UserDefaults.standard.set(originalVolumes, forKey: savedStateKey)
        if let sysVol = originalSystemVolume {
            UserDefaults.standard.set(sysVol, forKey: savedSystemVolumeKey)
        }
        UserDefaults.standard.set(true, forKey: isDuckedKey)
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: savedStateKey)
        UserDefaults.standard.removeObject(forKey: savedSystemVolumeKey)
        UserDefaults.standard.set(false, forKey: isDuckedKey)
    }

    var wasLeftDucked: Bool {
        UserDefaults.standard.bool(forKey: isDuckedKey)
    }

    func restoreFromSavedState() {
        let savedApps = UserDefaults.standard.dictionary(forKey: savedStateKey) as? [String: Int]
        let savedSysVol = UserDefaults.standard.object(forKey: savedSystemVolumeKey) as? Int

        guard savedApps != nil || savedSysVol != nil else {
            clearPersistedState()
            return
        }

        if let savedApps = savedApps {
            originalVolumes = savedApps
        }
        if let savedSysVol = savedSysVol {
            originalSystemVolume = savedSysVol
        }
        restoreAll()
    }
}
