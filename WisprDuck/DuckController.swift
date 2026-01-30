import Foundation
import Combine
import CoreAudio

final class DuckController: ObservableObject {
    @Published private(set) var isDucked: Bool = false
    @Published private(set) var isSystemVolumeAvailable: Bool = false
    @Published private(set) var outputDeviceName: String = ""

    let micMonitor = MicMonitor()
    private let volumeController = VolumeController()
    private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var restoreTimer: DispatchWorkItem?

    // Output device change monitoring
    private var outputDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private let listenerQueue = DispatchQueue(label: "com.wisprduck.outputmonitor", qos: .userInitiated)

    init(settings: AppSettings) {
        self.settings = settings

        // Crash recovery: restore volumes if app was left in ducked state
        if volumeController.wasLeftDucked {
            volumeController.restoreFromSavedState()
        }

        // Evaluate output device state once at startup
        refreshOutputDeviceState()

        // Monitor output device changes
        setupOutputDeviceListener()

        // React to mic state changes
        micMonitor.$isMicActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.handleMicStateChange(active: active)
            }
            .store(in: &cancellables)

        // React to isEnabled changes — restore volumes if disabled while ducked
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.settings.isEnabled && self.isDucked {
                    self.restoreTimer?.cancel()
                    self.restoreTimer = nil
                    self.restore()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        removeOutputDeviceListener()
    }

    // MARK: - Output Device Monitoring

    private func setupOutputDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        outputDeviceListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshOutputDeviceState()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            outputDeviceListenerBlock!
        )
    }

    private func removeOutputDeviceListener() {
        guard let block = outputDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            block
        )
        outputDeviceListenerBlock = nil
    }

    private func refreshOutputDeviceState() {
        outputDeviceName = volumeController.readDefaultOutputDeviceName()
        let available = volumeController.checkSystemVolumeAvailable()
        isSystemVolumeAvailable = available

        // Auto-disable system volume ducking if the new device doesn't support it
        if !available && settings.duckSystemVolume {
            settings.duckSystemVolume = false
        }
    }

    // MARK: - Mic State Handling

    private func handleMicStateChange(active: Bool) {
        guard settings.isEnabled else { return }

        if active {
            // Cancel any pending restore
            restoreTimer?.cancel()
            restoreTimer = nil

            // Duck immediately if not already ducked
            if !isDucked {
                duck()
            }
        } else {
            // Start debounce timer for restore
            restoreTimer?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async {
                    self?.restore()
                }
            }
            restoreTimer = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + settings.debounceDelay,
                execute: workItem
            )
        }
    }

    private func duck() {
        let useSystemVolume = settings.duckSystemVolume && isSystemVolumeAvailable
        // System volume mode covers everything — skip per-app to avoid double-ducking
        let apps = useSystemVolume ? [] : settings.enabledApps
        volumeController.duckAll(
            apps: apps,
            duckLevel: settings.duckLevel,
            duckSystem: useSystemVolume
        )
        isDucked = true
    }

    private func restore() {
        volumeController.restoreAll()
        isDucked = false
    }

    func restoreAndStop() {
        restoreTimer?.cancel()
        restoreTimer = nil
        if isDucked {
            restore()
        }
    }
}
