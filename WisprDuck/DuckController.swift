import Foundation
import Combine
import os

private let logger = Logger(subsystem: "com.wisprduck", category: "DuckController")

final class DuckController: ObservableObject {
    @Published private(set) var isDucked: Bool = false
    @Published private(set) var audioApps: [AudioApp] = []
    @Published private(set) var triggerEligibleApps: [AudioApp] = []
    @Published private(set) var audioStatusMessage: String?
    private let micMonitor: MicTriggerSource
    private let tapManager: ProcessTapManager
    private var settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var triggerReevaluationTimer: DispatchSourceTimer?

    init(
        settings: AppSettings,
        micMonitor: MicTriggerSource = MicMonitor(),
        tapManager: ProcessTapManager = ProcessTapManager()
    ) {
        self.settings = settings
        self.micMonitor = micMonitor
        self.tapManager = tapManager

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
        micMonitor.stateWillChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // React to filtered trigger signal instead of raw mic state
        // Only react to changes: the source re-publishes the same value on every
        // re-evaluation, and each extra restore would restart the fade-out.
        micMonitor.shouldTriggerDuckPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldDuck in
                self?.handleTriggerStateChange(shouldDuck: shouldDuck)
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

                if self.isDucked {
                    if self.micMonitor.shouldTriggerDuck {
                        self.isDucked = self.tapManager.reconcileActiveTaps(
                            bundleIDs: self.settings.enabledBundleIDs,
                            duckAll: self.settings.duckAllApps,
                            duckLevel: Float(self.settings.duckLevel) / 100.0
                        )
                    } else {
                        self.restore()
                    }
                }
                self.micMonitor.refreshTriggerState()
            }
        }
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
            startTriggerReevaluationTimer()
            if !isDucked {
                duck()
            }
        } else {
            // Always end the session, even when no taps were created. A session
            // can be active with zero taps (no target app was playing when the
            // mic started). Leaving it open made apps that started later get
            // ducked while the mic was idle.
            restore()
        }
    }

    private func duck() {
        let duckLevel = Float(settings.duckLevel) / 100.0
        let selectedBundleIDs = settings.enabledBundleIDs
        let duckAll = settings.duckAllApps

        isDucked = tapManager.duck(
            bundleIDs: selectedBundleIDs,
            duckAll: duckAll,
            duckLevel: duckLevel
        )

        logger.info("Duck requested at \(self.settings.duckLevel)%; active taps: \(self.tapManager.activeTapCount)")

        // No taps is not an error by itself: often no target app is playing.
        // Real failures (no output device, tap start errors) arrive through
        // the tap manager's error handler with a specific message.
        if isDucked {
            audioStatusMessage = nil
            startTriggerReevaluationTimer()
        }
    }

    private func restore() {
        stopTriggerReevaluationTimer()
        if tapManager.isSessionActive || tapManager.activeTapCount > 0 {
            logger.info("Restoring audio; active taps: \(self.tapManager.activeTapCount)")
        }
        tapManager.restoreAllWithFade()
        isDucked = false
    }

    /// Update duck level on active taps when the slider changes.
    func updateDuckLevel(_ level: Int) {
        tapManager.updateDuckLevel(Float(level) / 100.0)
    }

    func restoreAndStop() {
        // Always clean up — taps may still be alive during a fade-out even when isDucked is false
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

        let hasTaps = tapManager.reconcileActiveTaps(
            bundleIDs: settings.enabledBundleIDs,
            duckAll: settings.duckAllApps,
            duckLevel: Float(settings.duckLevel) / 100.0
        )

        if hasTaps {
            isDucked = true
            audioStatusMessage = nil
        }
    }
}
