import Foundation
import CoreAudio

/// URL for System Settings > Privacy & Security > Screen & System Audio Recording.
/// macOS allows audio-only access in this pane.
let privacySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!

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
