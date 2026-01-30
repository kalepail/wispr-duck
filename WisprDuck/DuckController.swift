import Foundation
import Combine
import CoreAudio

final class DuckController: ObservableObject {
    @Published private(set) var isDucked: Bool = false
    @Published private(set) var audioApps: [AudioApp] = []

    let micMonitor = MicMonitor()
    private let tapManager = ProcessTapManager()
    private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings

        // Populate initial audio process list and start always-on monitoring.
        // The listener is a single CoreAudio callback (no polling) that fires
        // only when processes start/stop producing audio.
        let initialProcesses = tapManager.enumerateAudioProcesses()
        audioApps = tapManager.audioApps(from: initialProcesses)

        tapManager.setProcessListChangedHandler { [weak self] processes in
            guard let self = self else { return }
            self.audioApps = self.tapManager.audioApps(from: processes)
        }
        tapManager.startProcessListMonitoring()

        // React to mic state changes
        micMonitor.$isMicActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.handleMicStateChange(active: active)
            }
            .store(in: &cancellables)

        // React to isEnabled changes — restore if disabled while ducked
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.settings.isEnabled && self.isDucked {
                    self.restore()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Mic State Handling

    private func handleMicStateChange(active: Bool) {
        guard settings.isEnabled else { return }

        if active {
            // Duck immediately — if fading out, this cancels the fade and reuses taps
            if !isDucked {
                duck()
            }
        } else {
            // Restore with fade — the 1s ramp acts as a natural buffer
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
