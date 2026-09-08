// Compile the production controller and manager against in-memory audio devices.
// No microphone, system audio capture, or UserDefaults access is needed.
import AppKit
import Combine
import CoreAudio

private enum AudioFixture {
    static var processes: [AudioObjectID: (pid_t, String)] = [101: (900001, "test.music")]
    static var output: AudioDeviceID = 11
    static var listeners: [AudioObjectPropertySelector: AudioObjectPropertyListenerBlock] = [:]
    static func notify(_ selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        listeners[selector]?(1, &address)
        drain()
    }
}

// These module-local functions shadow Core Audio only in this test executable.
func AudioObjectGetPropertyDataSize(_ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UnsafeMutablePointer<UInt32>) -> OSStatus {
    size.pointee = UInt32(AudioFixture.processes.count * MemoryLayout<AudioObjectID>.size)
    return noErr
}
func AudioObjectGetPropertyData(_ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UnsafeMutablePointer<UInt32>, _ data: UnsafeMutableRawPointer) -> OSStatus {
    switch address.pointee.mSelector {
    case kAudioHardwarePropertyProcessObjectList:
        for (index, object) in AudioFixture.processes.keys.sorted().enumerated() {
            data.assumingMemoryBound(to: AudioObjectID.self)[index] = object
        }
    case kAudioHardwarePropertyDefaultOutputDevice:
        data.assumingMemoryBound(to: AudioDeviceID.self).pointee = AudioFixture.output
    case kAudioDevicePropertyDeviceUID:
        data.assumingMemoryBound(to: Unmanaged<CFString>?.self).pointee = .passRetained("output-\(id)" as CFString)
    default: return kAudioHardwareUnknownPropertyError
    }
    return noErr
}
func AudioObjectAddPropertyListenerBlock(_ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ queue: DispatchQueue?, _ block: @escaping AudioObjectPropertyListenerBlock) -> OSStatus {
    AudioFixture.listeners[address.pointee.mSelector] = block
    return noErr
}
func AudioObjectRemovePropertyListenerBlock(_ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ queue: DispatchQueue?, _ block: AudioObjectPropertyListenerBlock) -> OSStatus {
    AudioFixture.listeners.removeValue(forKey: address.pointee.mSelector)
    return noErr
}
func describeOSStatus(_ status: OSStatus) -> String { String(status) }
func pidForProcessObject(_ object: AudioObjectID) -> pid_t? { AudioFixture.processes[object]?.0 }
func appIdentityForProcessOrAncestor(_ pid: pid_t) -> (bundleID: String, name: String)? {
    guard let process = AudioFixture.processes.values.first(where: { $0.0 == pid }) else { return nil }
    return (process.1, process.1)
}

final class ProcessTap {
    static var active: [pid_t: ProcessTap] = [:]
    static var starts = 0
    static var failStarts = false
    let processObjectID: AudioObjectID
    let pid: pid_t
    var lastError: String? { nil }
    var level: Float = 1
    var output = ""
    init(processObjectID: AudioObjectID, pid: pid_t) { self.processObjectID = processObjectID; self.pid = pid }
    func start(outputDeviceUID: String, duckLevel: Float) -> Bool {
        guard !Self.failStarts else { return false }
        level = duckLevel; output = outputDeviceUID
        Self.starts += 1; Self.active[pid] = self
        return true
    }
    func updateDuckLevel(_ value: Float) { level = value }
    func stop() { Self.active.removeValue(forKey: pid) }
}
final class MicMonitor: ObservableObject {
    @Published var shouldTriggerDuck = false
    var rootBundleIDResolver: ((String) -> String)?
    var triggerAllApps = false
    var triggerBundleIDs: Set<String> = []
    var activeApps: Set<String> = []
    var monitoringIssue: String? { nil }
    func refreshTriggerState() {
        let value = triggerAllApps ? !activeApps.isEmpty : !activeApps.isDisjoint(with: triggerBundleIDs)
        if value != shouldTriggerDuck { shouldTriggerDuck = value }
    }
}
final class AppSettings {
    var onSettingsChanged: (() -> Void)?
    var isEnabled = true { didSet { onSettingsChanged?() } }
    var duckLevel = 20 { didSet { onSettingsChanged?() } }
    var duckAllApps = false { didSet { onSettingsChanged?() } }
    var enabledBundleIDs: Set<String> = ["test.music"] { didSet { onSettingsChanged?() } }
    var triggerAllApps = false
    var triggerBundleIDs: Set<String> = ["test.dictation"]
}

private func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    print("PASS: \(message)")
}

@main struct AudioLifecycleTests {
    static func main() {
        let settings = AppSettings()
        let controller = DuckController(settings: settings)
        drain()
        let music = ProcessTap.active[900001]!
        expect(music.level == 1 && !controller.isDucked, "selected audio is prepared at unity while idle")
        settings.duckLevel = 30; drain()
        expect(music.level == 1, "changing the duck level while idle does not lower audio")

        controller.micMonitor.activeApps = ["test.dictation"]
        controller.micMonitor.refreshTriggerState(); drain()
        expect(music.level == 0.3 && controller.isDucked, "activation changes the existing tap's gain")
        controller.micMonitor.activeApps = []
        controller.micMonitor.refreshTriggerState(); drain()
        expect(music.level == 1 && ProcessTap.active[900001] === music, "release keeps the same tap at unity")
        for _ in 0..<3 {
            controller.micMonitor.activeApps = ["test.dictation"]
            controller.micMonitor.refreshTriggerState(); drain()
            controller.micMonitor.activeApps = []
            controller.micMonitor.refreshTriggerState(); drain()
        }
        expect(ProcessTap.starts == 1, "repeated dictations never recreate the prepared tap")

        AudioFixture.processes[102] = (900002, "test.other")
        AudioFixture.notify(kAudioHardwarePropertyProcessObjectList)
        expect(ProcessTap.active.count == 1, "unselected audio stays untapped")
        settings.enabledBundleIDs = ["test.other"]; drain()
        expect(ProcessTap.active[900001] == nil && ProcessTap.active[900002]?.level == 1, "idle selection changes release the old path and prepare the new one")
        AudioFixture.output = 12
        AudioFixture.notify(kAudioHardwarePropertyDefaultOutputDevice)
        expect(ProcessTap.active[900002]?.output == "output-12" && ProcessTap.active[900002]?.level == 1, "output switches rebuild idle paths at unity")
        AudioFixture.output = 0
        AudioFixture.notify(kAudioHardwarePropertyDefaultOutputDevice)
        expect(ProcessTap.active.isEmpty, "missing output releases old audio paths")
        AudioFixture.output = 11
        AudioFixture.notify(kAudioHardwarePropertyDefaultOutputDevice)
        expect(ProcessTap.active[900002]?.output == "output-11", "output return restores monitoring without a new dictation")

        settings.isEnabled = false; drain()
        expect(ProcessTap.active.isEmpty, "disabling monitoring destroys idle taps")
        AudioFixture.notify(kAudioHardwarePropertyProcessObjectList)
        expect(ProcessTap.active.isEmpty, "process events cannot restart taps while disabled")
        settings.isEnabled = true; drain()
        expect(ProcessTap.active[900002]?.level == 1, "re-enabling monitoring prepares audio at unity")
        controller.micMonitor.activeApps = ["test.dictation"]
        controller.micMonitor.refreshTriggerState(); drain()
        settings.duckLevel = 40; drain()
        expect(ProcessTap.active[900002]?.level == 0.4, "duck-level changes apply during dictation")
        AudioFixture.output = 12
        AudioFixture.notify(kAudioHardwarePropertyDefaultOutputDevice)
        expect(ProcessTap.active[900002]?.output == "output-12" && ProcessTap.active[900002]?.level == 0.4, "output switches preserve the active duck level")
        settings.isEnabled = false; drain()
        expect(ProcessTap.active.isEmpty && !controller.isDucked, "disabling during dictation restores audio")
        settings.isEnabled = true; drain()
        expect(ProcessTap.active[900002]?.level == 0.4, "re-enabling during dictation restores the active duck level")
        settings.isEnabled = false; drain()
        ProcessTap.failStarts = true
        settings.isEnabled = true; drain()
        expect(ProcessTap.active.isEmpty && !controller.isDucked, "failed tap creation does not report successful ducking")
        ProcessTap.failStarts = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        expect(ProcessTap.active[900002]?.level == 0.4 && controller.isDucked, "active dictation retries after a temporary tap failure")
        controller.restoreAndStop()
        expect(ProcessTap.active.isEmpty, "quit cleanup releases every tap")
    }
}
