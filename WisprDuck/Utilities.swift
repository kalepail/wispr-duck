import Foundation
import CoreAudio
import AppKit

/// URL for System Settings > Privacy & Security > Screen & System Audio Recording.
/// macOS allows audio-only access in this pane.
let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
let microphonePrivacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!

/// Human-readable Core Audio status for logs and user-facing diagnostics.
func describeOSStatus(_ status: OSStatus) -> String {
    guard status != noErr else { return "noErr" }

    let code = UInt32(bitPattern: status)
    let bytes = [
        UInt8((code >> 24) & 0xff),
        UInt8((code >> 16) & 0xff),
        UInt8((code >> 8) & 0xff),
        UInt8(code & 0xff),
    ]

    if bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) {
        return "\(status) ('\(String(bytes: bytes, encoding: .ascii) ?? "")')"
    }

    return "\(status)"
}

/// Get the PID for a Core Audio process object.
func pidForProcessObject(_ objectID: AudioObjectID) -> pid_t? {
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

/// Input devices that Core Audio says a process uses
/// (kAudioProcessPropertyDevices, input scope). Returns nil when the query fails.
func inputDeviceIDsForProcessObject(_ objectID: AudioObjectID) -> [AudioObjectID]? {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyDevices,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) == noErr else { return nil }
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    guard count > 0 else { return [] }
    var deviceIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
    guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &deviceIDs) == noErr else { return nil }
    return Array(deviceIDs.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
}

/// True when a process runs input on a real input device. Reading a process
/// tap also counts as "running input" in Core Audio; see MicInputClassifier.
func isProcessUsingMic(_ objectID: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunningInput,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let isRunningInput = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &isRunning) == noErr
        && isRunning != 0
    guard isRunningInput else { return false }
    return MicInputClassifier.isUsingMic(
        isRunningInput: true,
        inputDeviceCount: inputDeviceIDsForProcessObject(objectID)?.count
    )
}

/// Get the parent PID of a process via sysctl.
func parentPID(of pid: pid_t) -> pid_t? {
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else {
        return nil
    }
    let ppid = info.kp_eproc.e_ppid
    return ppid > 1 ? ppid : nil
}

struct ProcessAppIdentity {
    let pid: pid_t
    let bundleID: String
    let name: String?
}

/// Find the nearest app identity for a process or one of its ancestors.
/// Electron/native-helper apps often do audio work in child processes that
/// have no NSRunningApplication entry of their own.
func appIdentityForProcessOrAncestor(_ pid: pid_t, maxDepth: Int = 12) -> ProcessAppIdentity? {
    var currentPID = pid
    var visited = Set<pid_t>()

    for _ in 0..<maxDepth {
        guard visited.insert(currentPID).inserted else { break }

        if let app = NSRunningApplication(processIdentifier: currentPID),
           let bundleID = app.bundleIdentifier {
            return ProcessAppIdentity(
                pid: currentPID,
                bundleID: bundleID,
                name: app.localizedName
            )
        }

        guard let parent = parentPID(of: currentPID) else { break }
        currentPID = parent
    }

    return nil
}

/// Return all app bundle IDs visible on a process's ancestry path.
/// This is intentionally broader than appIdentityForProcessOrAncestor so
/// trigger matching can survive nested helpers with distinct bundle IDs.
func appBundleIDsForProcessAncestry(_ pid: pid_t, maxDepth: Int = 12) -> [String] {
    var currentPID = pid
    var visitedPIDs = Set<pid_t>()
    var seenBundleIDs = Set<String>()
    var bundleIDs: [String] = []

    for _ in 0..<maxDepth {
        guard visitedPIDs.insert(currentPID).inserted else { break }

        if let app = NSRunningApplication(processIdentifier: currentPID),
           let bundleID = app.bundleIdentifier,
           seenBundleIDs.insert(bundleID).inserted {
            bundleIDs.append(bundleID)
        }

        guard let parent = parentPID(of: currentPID) else { break }
        currentPID = parent
    }

    return bundleIDs
}
