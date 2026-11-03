import CoreAudio
import Combine
import AppKit
import os

private let logger = Logger(subsystem: "com.wisprduck", category: "MicMonitor")

final class MicMonitor: ObservableObject {
    // Ensure NSMicrophoneUsageDescription is present if the app requests mic access.
    @Published private(set) var isMicActive: Bool = false
    @Published private(set) var shouldTriggerDuck: Bool = false
    @Published private(set) var monitoringIssue: String?

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

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            defaultDeviceListenerBlock!
        )
        guard status == noErr else {
            reportIssue("WisprDuck could not monitor the default microphone: \(describeOSStatus(status))")
            defaultDeviceListenerBlock = nil
            return
        }
        clearIssue()
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            block
        )
        if status != noErr {
            logger.error("Could not stop monitoring the default microphone: \(describeOSStatus(status))")
        }
        defaultDeviceListenerBlock = nil
    }

    // MARK: - Default Input Device "Is Running" Monitoring
    //
    // Mic use is decided from per-process input state (kAudioProcessPropertyIsRunningInput).
    // The default input device listener is only a hint to re-check it. WisprDuck does
    // not scan or query every audio device: its own private aggregate devices can hold
    // a HAL lock while their tap starts, and querying them blocked the listener queue
    // indefinitely, which left audio ducked.

    private func bindToCurrentInputDevice() {
        removeDeviceListener()

        guard let deviceID = getDefaultInputDevice() else {
            reportIssue("WisprDuck could not find a default microphone. Choose an input device in System Settings.")
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

        let status = AudioObjectAddPropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            deviceListenerBlock!
        )
        guard status == noErr else {
            reportIssue("WisprDuck could not monitor microphone activity: \(describeOSStatus(status))")
            deviceListenerBlock = nil
            return
        }
        clearIssue()
    }

    private func removeDeviceListener() {
        guard currentDeviceID != kAudioObjectUnknown, let block = deviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectRemovePropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            block
        )
        if status != noErr {
            logger.error("Could not stop monitoring microphone activity: \(describeOSStatus(status))")
        }
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

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            processListListenerBlock!
        )
        guard status == noErr else {
            reportIssue("WisprDuck could not monitor audio process activity: \(describeOSStatus(status))")
            processListListenerBlock = nil
            return
        }
        clearIssue()
    }

    private func removeProcessListListener() {
        guard let block = processListListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            block
        )
        if status != noErr {
            logger.error("Could not stop monitoring audio process activity: \(describeOSStatus(status))")
        }
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

    /// Per-process properties that change whether a process uses the mic.
    /// The input device list changes when an app starts or stops reading a
    /// real mic without "running input" changing (e.g. a tap reader that
    /// also opens the mic).
    private static let perProcessAddresses = [
        AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        ),
        AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyDevices,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        ),
    ]

    private func addPerProcessListener(_ objectID: AudioObjectID) {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.reevaluateTriggerState()
        }

        var addresses = Self.perProcessAddresses
        let status = AudioObjectAddPropertyListenerBlock(objectID, &addresses[0], listenerQueue, block)
        guard status == noErr else {
            reportIssue("WisprDuck could not monitor an app's microphone activity: \(describeOSStatus(status))")
            return
        }
        // The device-list listener is a hint only; "running input" stays the main signal.
        let deviceStatus = AudioObjectAddPropertyListenerBlock(objectID, &addresses[1], listenerQueue, block)
        if deviceStatus != noErr {
            logger.debug("Could not monitor input devices for process \(objectID): \(describeOSStatus(deviceStatus))")
        }
        perProcessListenerBlocks[objectID] = block
        clearIssue()
    }

    private func removePerProcessListener(_ objectID: AudioObjectID) {
        guard let block = perProcessListenerBlocks.removeValue(forKey: objectID) else { return }
        var addresses = Self.perProcessAddresses
        let status = AudioObjectRemovePropertyListenerBlock(objectID, &addresses[0], listenerQueue, block)
        // Fails harmlessly when the device-list listener was never added.
        _ = AudioObjectRemovePropertyListenerBlock(objectID, &addresses[1], listenerQueue, block)
        if status != noErr {
            // Expected when the process has exited: its audio object is already gone.
            logger.debug("Could not stop monitoring app microphone activity \(objectID): \(describeOSStatus(status))")
        }
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

    func refreshTriggerState() {
        listenerQueue.async { [weak self] in
            self?.reevaluateTriggerState()
        }
    }

    /// Device "is running" changes are only a hint to re-check per-process
    /// input; the device flag itself is not used as a trigger.
    private func updateMicStatus() {
        reevaluateTriggerState()
    }

    /// Central re-evaluation: checks which processes are using the mic input
    /// and whether any of them match the trigger app list.
    ///
    /// Always called on `listenerQueue` — either directly from CoreAudio listener
    /// callbacks or dispatched from `triggerSettingsDidChange()`. Reads CoreAudio
    /// state on the listener queue, then dispatches to main to read configuration
    /// and publish the result.
    private func reevaluateTriggerState() {
        // Gather process-level data on the listener queue (fast, thread-safe Core Audio reads)
        let objectIDs = getAudioProcessObjectIDs()
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Collect bundle IDs for mic-using processes and their app ancestors.
        // Wispr Flow can do input work in helper processes that do not expose
        // their own NSRunningApplication identity.
        var seenInputBundleIDs = Set<String>()
        var inputBundleIDs: [String] = []
        var inputProcessCount = 0
        for objectID in objectIDs {
            guard let pid = pidForProcessObject(objectID), pid != myPID else { continue }
            guard isProcessUsingMic(objectID) else { continue }
            inputProcessCount += 1
            for bundleID in appBundleIDsForProcessAncestry(pid) where seenInputBundleIDs.insert(bundleID).inserted {
                inputBundleIDs.append(bundleID)
            }
        }

        // Dispatch to main to safely read configuration and publish result
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isMicActive = inputProcessCount > 0
            let resolver = self.rootBundleIDResolver
            let shouldTrigger = TriggerMatcher.shouldTrigger(
                inputProcessCount: inputProcessCount,
                inputBundleIDs: inputBundleIDs,
                triggerAllApps: self.triggerAllApps,
                triggerBundleIDs: self.triggerBundleIDs,
                resolveRoot: { resolver?($0) ?? $0 }
            )
            if shouldTrigger != self.shouldTriggerDuck {
                logger.info("Trigger \(shouldTrigger ? "active" : "idle", privacy: .public); mic apps: \(inputBundleIDs.joined(separator: ", "), privacy: .public)")
            }
            self.shouldTriggerDuck = shouldTrigger
        }
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

    private func reportIssue(_ message: String) {
        logger.error("\(message)")
        DispatchQueue.main.async { [weak self] in
            self?.monitoringIssue = message
        }
    }

    private func clearIssue() {
        DispatchQueue.main.async { [weak self] in
            self?.monitoringIssue = nil
        }
    }
}

// MARK: - Trigger Source Abstraction

/// The mic-trigger signal DuckController depends on. MicMonitor is the live
/// implementation; tests drive DuckController with a fake.
protocol MicTriggerSource: AnyObject {
    var shouldTriggerDuck: Bool { get }
    var shouldTriggerDuckPublisher: AnyPublisher<Bool, Never> { get }
    var stateWillChangePublisher: AnyPublisher<Void, Never> { get }
    var monitoringIssue: String? { get }
    var triggerAllApps: Bool { get set }
    var triggerBundleIDs: Set<String> { get set }
    var rootBundleIDResolver: ((String) -> String)? { get set }
    func refreshTriggerState()
}

extension MicMonitor: MicTriggerSource {
    var shouldTriggerDuckPublisher: AnyPublisher<Bool, Never> {
        $shouldTriggerDuck.eraseToAnyPublisher()
    }

    var stateWillChangePublisher: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
}
