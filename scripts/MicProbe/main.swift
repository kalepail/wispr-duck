import AppKit
import CoreAudio
import Foundation

// mic-probe: show which processes use the microphone, which app bundle IDs
// WisprDuck sees for them, and whether WisprDuck's trigger settings would duck.
// Uses the app's own matching code (TriggerMatching.swift, Utilities.swift).
//
// Usage: scripts/mic-probe.sh [--seconds N] [--trigger BUNDLE_ID ...]

struct Options {
    var seconds: Double = 30
    var extraTriggers: Set<String> = []
}

func parseOptions() -> Options {
    var options = Options()
    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = args.next() {
        switch arg {
        case "--seconds":
            if let value = args.next(), let seconds = Double(value) { options.seconds = seconds }
        case "--trigger":
            if let value = args.next() { options.extraTriggers.insert(value) }
        case "-h", "--help":
            print("Usage: mic-probe [--seconds N] [--trigger BUNDLE_ID ...]")
            exit(0)
        default:
            FileHandle.standardError.write("Unknown argument: \(arg)\n".data(using: .utf8)!)
            exit(2)
        }
    }
    return options
}

func processObjectIDs() -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
          size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
        return []
    }
    return ids
}

func executableName(_ pid: pid_t) -> String {
    var buffer = [CChar](repeating: 0, count: 4096)
    guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return "?" }
    return URL(fileURLWithPath: String(cString: buffer)).lastPathComponent
}

func savedTriggerSettings() -> (triggerAll: Bool, ids: Set<String>) {
    let defaults = UserDefaults(suiteName: "com.wisprduck.WisprDuck")
    let triggerAll = defaults?.object(forKey: AppSettings.Keys.triggerAllApps) as? Bool ?? false
    let ids = AppSettings.decodeBundleIDs(json: defaults?.string(forKey: AppSettings.Keys.triggerBundleIDs))
        ?? AppSettings.defaultTriggerBundleIDs
    return (triggerAll, ids)
}

let options = parseOptions()
let saved = savedTriggerSettings()
let triggers = saved.ids.union(options.extraTriggers)
let lookup: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
let resolve: (String) -> String = { BundleIDResolution.rootAppBundleID(for: $0, applicationURL: lookup) }

print("WisprDuck trigger-all: \(saved.triggerAll)")
print("Trigger apps: \(triggers.sorted().joined(separator: ", "))")
print("Watching mic input for \(Int(options.seconds)) s. Start and stop dictation now.\n")

let formatter = DateFormatter()
formatter.dateFormat = "HH:mm:ss.SSS"
let myPID = ProcessInfo.processInfo.processIdentifier
var lastSnapshot = ""
let deadline = Date().addingTimeInterval(options.seconds)

while Date() < deadline {
    var lines: [String] = []
    var inputBundleIDs: [String] = []
    var seen = Set<String>()
    var inputProcessCount = 0

    for objectID in processObjectIDs() {
        guard let pid = pidForProcessObject(objectID), pid != myPID, isProcessUsingMic(objectID) else { continue }
        inputProcessCount += 1
        let ancestry = appBundleIDsForProcessAncestry(pid)
        for id in ancestry where seen.insert(id).inserted { inputBundleIDs.append(id) }
        let roots = Set(ancestry.map(resolve)).sorted()
        lines.append("  pid \(pid) \(executableName(pid))\n    ancestry: \(ancestry.joined(separator: " → "))\n    root app: \(roots.joined(separator: ", "))")
    }

    let duck = TriggerMatcher.shouldTrigger(
        inputProcessCount: inputProcessCount,
        inputBundleIDs: inputBundleIDs,
        triggerAllApps: saved.triggerAll,
        triggerBundleIDs: triggers,
        resolveRoot: resolve
    )
    let snapshot = lines.joined(separator: "\n") + "\(duck)"
    if snapshot != lastSnapshot {
        lastSnapshot = snapshot
        let header = lines.isEmpty ? "mic idle" : "mic in use by \(lines.count) process(es)"
        print("[\(formatter.string(from: Date()))] \(header) → WisprDuck would \(duck ? "DUCK" : "not duck")")
        if !lines.isEmpty { print(lines.joined(separator: "\n")) }
        fflush(stdout)
    }
    Thread.sleep(forTimeInterval: 0.1)
}
