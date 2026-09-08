import Foundation
import Combine

final class DuckController: ObservableObject {
    @Published private(set) var isDucked: Bool = false
    @Published private(set) var audioApps: [AudioApp] = []
    @Published private(set) var triggerEligibleApps: [AudioApp] = []
    @Published private(set) var audioStatusMessage: String?
    let micMonitor = MicMonitor()
    private let tapManager = ProcessTapManager()
    private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var triggerReevaluationTimer: DispatchSourceTimer?

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
            guard let self else { return }
            self.audioApps = self.tapManager.audioApps(from: processes)
            self.triggerEligibleApps = self.tapManager.audioApps(from: processes, includeAccessory: true)
        }
        tapManager.setErrorHandler { [weak self] message in
            self?.audioStatusMessage = message
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
            .sink { [weak self] _ in
                self?.refreshAudioPaths()
            }
            .store(in: &cancellables)

        // React to settings changes — restore if disabled while ducked,
        // and sync trigger settings to MicMonitor
        settings.onSettingsChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }

                self.syncTriggerSettings()

                guard self.settings.isEnabled else {
                    self.restoreAndStop()
                    return
                }

                self.refreshAudioPaths()
                self.micMonitor.refreshTriggerState()
            }
        }
        refreshAudioPaths()
    }

    /// Keep selected paths at unity while idle; only mic activity lowers gain.
    private func refreshAudioPaths() {
        guard settings.isEnabled else { return }
        let shouldDuck = micMonitor.shouldTriggerDuck
        if shouldDuck {
            startTriggerReevaluationTimer()
        } else {
            stopTriggerReevaluationTimer()
        }
        let hasTaps = tapManager.reconcileActiveTaps(
            bundleIDs: settings.enabledBundleIDs,
            duckAll: settings.duckAllApps,
            duckLevel: shouldDuck ? Float(settings.duckLevel) / 100.0 : 1.0
        )
        isDucked = shouldDuck && hasTaps
        if hasTaps { audioStatusMessage = nil }
    }

    // MARK: - Settings Sync

    private func syncTriggerSettings() {
        micMonitor.triggerAllApps = settings.triggerAllApps
        micMonitor.triggerBundleIDs = settings.triggerBundleIDs
    }

    func restoreAndStop() {
        // Disabling monitoring and quitting release the idle paths too.
        stopTriggerReevaluationTimer()
        tapManager.restoreAll()
        isDucked = false
    }

    func requestSystemAudioPermissionPrompt() -> String? {
        tapManager.requestSystemAudioPermissionPrompt()
    }

    var currentIssueMessage: String? {
        audioStatusMessage ?? micMonitor.monitoringIssue
    }

    private func startTriggerReevaluationTimer() {
        guard triggerReevaluationTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.25, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            self?.refreshWhileTriggered()
        }
        triggerReevaluationTimer = timer
        timer.resume()
    }

    private func stopTriggerReevaluationTimer() {
        triggerReevaluationTimer?.cancel()
        triggerReevaluationTimer = nil
    }

    private func refreshWhileTriggered() {
        micMonitor.refreshTriggerState()

        guard settings.isEnabled, micMonitor.shouldTriggerDuck else { return }

        refreshAudioPaths()
    }
}
