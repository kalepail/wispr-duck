import CoreAudio
import Combine
import AppKit

final class MicMonitor: ObservableObject {
    // Ensure NSMicrophoneUsageDescription is present if the app requests mic access.
    @Published private(set) var isMicActive: Bool = false
    @Published private(set) var shouldTriggerDuck: Bool = false

    /// When true, any app using the mic triggers ducking.
    var triggerAllApps: Bool = true {
        didSet { triggerSettingsDidChange() }
    }

    /// Bundle IDs that should trigger ducking when using the mic.
    var triggerBundleIDs: Set<String> = [] {
        didSet { triggerSettingsDidChange() }
    }

    /// Optional resolver to map helper bundle IDs to their root app bundle ID.
    var rootBundleIDResolver: ((String) -> String)?

    private var currentDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var processListListenerBlock: AudioObjectPropertyListenerBlock?
    private var perProcessListenerBlocks: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private let listenerQueue = DispatchQueue(label: "com.wisprduck.micmonitor", qos: .userInitiated)
    private let listenerQueueKey = DispatchSpecificKey<Void>()

    init() {
        listenerQueue.setSpecific(key: listenerQueueKey, value: ())
        performOnListenerQueue {
            setupDefaultDeviceListener()
            setupProcessListListener()
            bindToCurrentInputDevice()
            refreshPerProcessListeners()
        }
    }

    // deinit calls performOnListenerQueue which may block via sync. This is safe
    // because MicMonitor is owned by DuckController (a @StateObject released on
    // the main thread, never on the listener queue). If ownership changes, audit
    // for potential deadlock.
    deinit {
        performOnListenerQueue {
            removeDeviceListener()
            removeDefaultDeviceListener()
            removeProcessListListener()
            removeAllPerProcessListeners()
        }
    }

    private func performOnListenerQueue(_ work: () -> Void) {
        if DispatchQueue.getSpecific(key: listenerQueueKey) != nil {
            work()
        } else {
            listenerQueue.sync(execute: work)
        }
    }

    // MARK: - Default Input Device Change Monitoring

    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        defaultDeviceListenerBlock = { [weak self] _, _ in
            self?.bindToCurrentInputDevice()
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            defaultDeviceListenerBlock!
        )
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            block
        )
        defaultDeviceListenerBlock = nil
    }

    // MARK: - Input Device "Is Running" Monitoring

    private func bindToCurrentInputDevice() {
        removeDeviceListener()

        guard let deviceID = getDefaultInputDevice() else {
            DispatchQueue.main.async {
                self.isMicActive = false
                self.shouldTriggerDuck = false
            }
            return
        }

        currentDeviceID = deviceID
        updateMicStatus()

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        deviceListenerBlock = { [weak self] _, _ in
            self?.updateMicStatus()
        }

        AudioObjectAddPropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            deviceListenerBlock!
        )
    }

    private func removeDeviceListener() {
        guard currentDeviceID != kAudioObjectUnknown, let block = deviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            block
        )
        deviceListenerBlock = nil
    }

    // MARK: - Process Object List Monitoring

    private func setupProcessListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        processListListenerBlock = { [weak self] _, _ in
            self?.refreshPerProcessListeners()
            self?.reevaluateTriggerState()
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            processListListenerBlock!
        )
    }

    private func removeProcessListListener() {
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

    // MARK: - Per-Process IsRunning Listeners

    private func refreshPerProcessListeners() {
        let objectIDs = Set(getAudioProcessObjectIDs())
        let tracked = Set(perProcessListenerBlocks.keys)

        // Remove listeners for processes that left
        for objectID in tracked.subtracting(objectIDs) {
            removePerProcessListener(objectID)
        }

        // Add listeners for new processes
        for objectID in objectIDs.subtracting(tracked) {
            addPerProcessListener(objectID)
        }
    }

    private func addPerProcessListener(_ objectID: AudioObjectID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.reevaluateTriggerState()
        }

        let status = AudioObjectAddPropertyListenerBlock(
            objectID,
            &address,
            listenerQueue,
            block
        )

        if status == noErr {
            perProcessListenerBlocks[objectID] = block
        }
    }

    private func removePerProcessListener(_ objectID: AudioObjectID) {
        guard let block = perProcessListenerBlocks.removeValue(forKey: objectID) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            objectID,
            &address,
            listenerQueue,
            block
        )
    }

    private func removeAllPerProcessListeners() {
        for objectID in Array(perProcessListenerBlocks.keys) {
            removePerProcessListener(objectID)
        }
    }

    // MARK: - Trigger Evaluation

    /// Called from didSet of trigger settings (main thread). Dispatches to the
    /// listener queue so CoreAudio reads (currentDeviceID, process state) are
    /// serialized with listener callbacks that write the same state.
    private func triggerSettingsDidChange() {
        listenerQueue.async { [weak self] in
            self?.reevaluateTriggerState()
        }
    }

    private func updateMicStatus() {
        let micActive = isDeviceRunningSomewhere()
        DispatchQueue.main.async {
            self.isMicActive = micActive
        }
        reevaluateTriggerState(micActive: micActive)
    }

    /// Central re-evaluation: checks which processes are using the mic input
    /// and whether any of them match the trigger app list.
    ///
    /// Always called on `listenerQueue` — either directly from CoreAudio listener
    /// callbacks or dispatched from `triggerSettingsDidChange()`. Reads CoreAudio
    /// state on the listener queue, then dispatches to main to read configuration
    /// and publish the result.
    private func reevaluateTriggerState(micActive: Bool? = nil) {
        // Read CoreAudio state on the current (listener) queue — these are fast, thread-safe reads
        let deviceActive = micActive ?? isDeviceRunningSomewhere()

        // Early out: if device-level mic is not active, skip process enumeration
        guard deviceActive else {
            DispatchQueue.main.async {
                self.shouldTriggerDuck = false
            }
            return
        }

        // Gather process-level data while still on the listener queue
        let objectIDs = getAudioProcessObjectIDs()
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Collect (resolved bundle ID) for each process currently using mic input
        var inputBundleIDs: [String] = []
        for objectID in objectIDs {
            guard isProcessRunningInput(objectID) else { continue }
            guard let pid = pidForProcessObject(objectID), pid != myPID else { continue }
            if let bundleID = bundleIDForProcess(pid) {
                inputBundleIDs.append(bundleID)
            }
        }

        // Dispatch to main to safely read configuration and publish result
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.triggerAllApps {
                self.shouldTriggerDuck = !inputBundleIDs.isEmpty
                return
            }
            let resolver = self.rootBundleIDResolver
            let triggerIDs = self.triggerBundleIDs
            self.shouldTriggerDuck = inputBundleIDs.contains { bundleID in
                let resolved = resolver?(bundleID) ?? bundleID
                return triggerIDs.contains(resolved)
            }
        }
    }

    private func isDeviceRunningSomewhere() -> Bool {
        guard currentDeviceID != kAudioObjectUnknown else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &isRunning)
        return status == noErr && isRunning != 0
    }

    // MARK: - Audio Process Helpers

    private func getAudioProcessObjectIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size
        )
        guard status == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &objectIDs
        )
        guard status == noErr else { return [] }
        return objectIDs
    }

    private func isProcessRunningInput(_ objectID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &isRunning)
        return status == noErr && isRunning != 0
    }

    private func bundleIDForProcess(_ pid: pid_t) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid) {
            if let bid = app.bundleIdentifier { return bid }
        }
        // Walk up to parent for helper processes
        if let ppid = parentPID(of: pid),
           let parentApp = NSRunningApplication(processIdentifier: ppid) {
            return parentApp.bundleIdentifier
        }
        return nil
    }

    // MARK: - Device Helpers

    private func getDefaultInputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
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

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
}
