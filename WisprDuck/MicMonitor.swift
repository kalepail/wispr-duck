import Foundation
import CoreAudio
import Combine

final class MicMonitor: ObservableObject {
    @Published private(set) var isMicActive: Bool = false

    private var currentDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private let listenerQueue = DispatchQueue(label: "com.wisprduck.micmonitor", qos: .userInitiated)

    init() {
        setupDefaultDeviceListener()
        bindToCurrentInputDevice()
    }

    deinit {
        removeDeviceListener()
        removeDefaultDeviceListener()
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
            DispatchQueue.main.async { self.isMicActive = false }
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

    // MARK: - Helpers

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

    private func updateMicStatus() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            currentDeviceID,
            &address,
            0, nil,
            &size,
            &isRunning
        )

        let active = (status == noErr) && (isRunning != 0)
        DispatchQueue.main.async {
            self.isMicActive = active
        }
    }
}
