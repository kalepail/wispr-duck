import Foundation
import Combine
import CoreAudio

final class DuckController: ObservableObject {
    @Published private(set) var isDucked: Bool = false
    @Published private(set) var audioApps: [AudioApp] = []
    @Published private(set) var triggerEligibleApps: [AudioApp] = []

    let micMonitor = MicMonitor()
    private let tapManager = ProcessTapManager()
    private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings

        // Wire the root bundle ID resolver so MicMonitor can resolve helper bundle IDs
        micMonitor.rootBundleIDResolver = { [weak self] bundleID in
            self?.tapManager.rootAppBundleID(for: bundleID) ?? bundleID
        }

        // Sync trigger settings from AppSettings to MicMonitor
        syncTriggerSettings()

        // Populate initial audio process list and start always-on monitoring.
        // The listener is a single CoreAudio callback (no polling) that fires
        // only when processes start/stop producing audio.
        let initialProcesses = tapManager.enumerateAudioProcesses()
        audioApps = tapManager.audioApps(from: initialProcesses)
        triggerEligibleApps = tapManager.audioApps(from: initialProcesses, includeAccessory: true)

        tapManager.setProcessListChangedHandler { [weak self] processes in
            guard let self = self else { return }
            self.audioApps = self.tapManager.audioApps(from: processes)
            self.triggerEligibleApps = self.tapManager.audioApps(from: processes, includeAccessory: true)
        }
        tapManager.startProcessListMonitoring()

        // Forward micMonitor changes so views observing DuckController
        // also see MicMonitor property updates (e.g., isMicActive for status text).
        // Needed because @ObservedObject doesn't observe nested ObservableObjects.
        micMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // React to filtered trigger signal instead of raw mic state
        micMonitor.$shouldTriggerDuck
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldDuck in
                self?.handleTriggerStateChange(shouldDuck: shouldDuck)
            }
            .store(in: &cancellables)

        // React to settings changes — restore if disabled while ducked,
        // and sync trigger settings to MicMonitor
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.settings.isEnabled && self.isDucked {
                    self.restore()
                }
                self.syncTriggerSettings()
            }
            .store(in: &cancellables)
    }

    // MARK: - Settings Sync

    private func syncTriggerSettings() {
        micMonitor.triggerAllApps = settings.triggerAllApps
        micMonitor.triggerBundleIDs = settings.triggerBundleIDs
    }

    // MARK: - Trigger State Handling

    private func handleTriggerStateChange(shouldDuck: Bool) {
        guard settings.isEnabled else { return }

        if shouldDuck {
            if !isDucked {
                duck()
            }
        } else {
            if isDucked {
                restore()
            }
        }
    }

    private func duck() {
        let duckLevel = Float(settings.duckLevel) / 100.0
        let selectedBundleIDs = settings.enabledBundleIDs
        let duckAll = settings.duckAllAudio

        tapManager.duck(
            bundleIDs: selectedBundleIDs,
            duckAll: duckAll,
            duckLevel: duckLevel
        )
        isDucked = true
    }

    private func restore() {
        tapManager.restoreAllWithFade()
        isDucked = false
    }

    /// Update duck level on active taps when the slider changes.
    func updateDuckLevel(_ level: Int) {
        tapManager.updateDuckLevel(Float(level) / 100.0)
    }

    func restoreAndStop() {
        // Always clean up — taps may still be alive during a fade-out even when isDucked is false
        tapManager.restoreAll()
        isDucked = false
    }
}
