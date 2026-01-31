# WisprDuck CODEX Audit
Date: 2026-01-31
Scope: macOS app (Swift/SwiftUI + CoreAudio). Static code review only (no runtime profiling or device tests).

## Executive Summary
WisprDuck’s architecture is solid and aligns with macOS 14.2+ Core Audio process taps. The code is clean and focused, with good attention to crash-safe behavior and event-driven monitoring. Most of the core logic is efficient and avoids polling. I found a small number of correctness and performance risks worth addressing before production, plus a few production-hardening gaps (permissions UX and test coverage).

Overall readiness: **Mostly production-ready**, pending the high-severity concurrency fix and a couple of performance/UX improvements.

## Version Requirements Check
- macOS target is **14.2** (Xcode build setting), matching documented requirements. (`WisprDuck.xcodeproj/project.pbxproj`)
- Permissions present: `NSAudioCaptureUsageDescription` and `NSMicrophoneUsageDescription` in `Info.plist`.

## Strengths
- Event-driven CoreAudio listeners; no polling loops.
- Clean process grouping and helper resolution logic.
- Safe audio restoration via `mutedWhenTapped` and explicit restore on quit.
- Fade logic avoids abrupt jumps and supports re-duck during fade-out.

## Findings (Ordered by Severity)

### High
1) **Potential data race in MicMonitor when settings change**
   - `triggerAllApps` / `triggerBundleIDs` call `reevaluateTriggerState()` on whatever thread sets them (often main), while CoreAudio listeners also mutate/read `currentDeviceID` and other state on the listener queue.
   - Risk: non-deterministic reads of `currentDeviceID` and device state; possible missed or spurious triggers.
   - Evidence: `MicMonitor.swift:11-18`, `MicMonitor.swift:23`, `MicMonitor.swift:97-128`, `MicMonitor.swift:205-209`.
   - Recommendation: funnel **all** CoreAudio reads and listener mutations through the `listenerQueue` (e.g., wrap `reevaluateTriggerState` calls with `performOnListenerQueue`), and only publish results on main.

### Medium
2) **Process enumeration happens on main thread during audio process changes**
   - `handleProcessListChanged()` is dispatched to main and then calls `enumerateAudioProcesses()` (CoreAudio calls + NSRunningApplication lookup).
   - Risk: occasional UI hitch or menu bar latency when audio process list churns.
   - Evidence: `ProcessTapManager.swift:295-299`, `ProcessTapManager.swift:376-379`.
   - Recommendation: perform enumeration on `listenerQueue`, then publish results to main.

3) **Non-Float32 tap format falls back to pass-through (no ducking)**
   - Ducking is skipped for non-Float32 formats; audio is passed through unscaled.
   - Risk: user observes no ducking on specific devices or formats, with no visible warning.
   - Evidence: `ProcessTap.swift:141-173`, `ProcessTap.swift:200-226`.
   - Recommendation: add format conversion (preferred) or explicit UI/console warning when falling back.

### Low
4) **Permissions UX could be clearer for microphone access**
   - UI opens Screen & System Audio Recording settings, but does not guide users to microphone privacy settings.
   - Risk: users who deny mic access may not understand why ducking doesn’t trigger.
   - Evidence: `MenuBarView.swift:127-140`, `Utilities.swift:5`.
   - Recommendation: add a link/button for microphone privacy settings or show a banner when mic access is denied.

5) **No automated tests or basic smoke checks**
   - No unit tests or UI tests are present.
   - Risk: regressions in tap management, process matching, or settings sync could go unnoticed.
   - Evidence: repository has no test targets or test files.
   - Recommendation: add small unit tests for bundle ID resolution, settings persistence, and duck/restore state transitions; add a simple integration smoke test for tap creation on a simulator/dev box.

## Performance & Efficiency Notes
- CoreAudio listeners and per-process callbacks are event-driven and efficient.
- Ducking is per-process and only active during mic use, minimizing overhead.
- Potential main-thread work during process list changes is the primary perf risk.

## Production Hardening Checklist
- [ ] Serialize MicMonitor state changes to avoid data races.
- [ ] Move process enumeration off main thread.
- [ ] Add non-Float32 handling or user-visible warning.
- [ ] Improve permissions UX for microphone access.
- [ ] Add minimal automated tests.

## Files Reviewed
- `WisprDuck/WisprDuckApp.swift`
- `WisprDuck/AppSettings.swift`
- `WisprDuck/DuckController.swift`
- `WisprDuck/MicMonitor.swift`
- `WisprDuck/ProcessTapManager.swift`
- `WisprDuck/ProcessTap.swift`
- `WisprDuck/MenuBarView.swift`
- `WisprDuck/WelcomeView.swift`
- `WisprDuck/Utilities.swift`
- `WisprDuck/Info.plist`
- `WisprDuck/WisprDuck.entitlements`

## Readiness Assessment
If the high-severity MicMonitor concurrency fix and the medium-level main-thread enumeration issue are addressed, this app is in strong shape for production on macOS 14.2+.
