# WisprDuck Audit Report (Code + Permissions Research)

Date: 2026-01-31
Scope: Local codebase review + focused permissions research for macOS 14.2+ Core Audio process taps.

## Cross-References
- See docs/RESEARCH.md for mic activity detection rationale and CoreAudio listener approach.
- See docs/AUDIO-DUCKING-APPROACHES.md for process tap architecture and historical permission notes.

## Sources Consulted (Permissions)
- Apple Support: Screen & System Audio Recording settings (screen and/or audio permissions).
- Unity macOS requirements (Vivox): NSMicrophoneUsageDescription required for macOS microphone access.
- Unity Support article (Vivox): app termination if requesting microphone permission without NSMicrophoneUsageDescription.
- AudioCap (insidegui/AudioCap) sample: NSAudioCaptureUsageDescription for system/app audio capture permissions and notes on public API limitations.

(Full URLs are listed in the Sources section below.)

## Summary
The application architecture is consistent with the process-tap approach described in docs/AUDIO-DUCKING-APPROACHES.md and the mic monitoring approach described in docs/RESEARCH.md. The app appears functionally solid, but there are a few correctness and production-readiness issues that should be addressed. The permissions-related findings below were re-validated against published sources listed at the end of this report.

## Findings (Code/Behavior)

### Critical
1) MicMonitor listener state is mutated on multiple threads (main + CoreAudio listener queue) without synchronization.
   - Risk: data races in listener blocks and per-process listener map, potentially leading to crashes or missing listeners.
   - Affected code: MicMonitor.swift
   - Status: fixed by serializing listener setup/teardown on the listener queue.

### High
2) “Ducked” UI state can be true even when no taps are active.
   - If ducking is enabled but there are zero eligible targets, duck() still flips isDucked to true.
   - Affected code: DuckController.swift, ProcessTapManager.swift
   - Status: fixed by making duck() return whether taps exist and updating isDucked accordingly.

3) Output device changes during an active duck session are not handled.
   - Taps are created with the output device UID at duck time; switching outputs can break routing or silence audio.
   - Affected code: ProcessTapManager.swift
   - Status: fixed by monitoring default output changes and rebuilding taps.

### Medium
4) Audio buffer format assumptions in ProcessTap.
   - processAudioBuffers assumes Float32 and directly multiplies samples; if the tap format differs, behavior is undefined.
   - Affected code: ProcessTap.swift
   - Status: mitigated by detecting non-Float32 formats and falling back to pass-through.

5) Trigger-all behavior relies only on device-level mic running state.
   - Some drivers report “running” without a process actively using input; could over-trigger ducking.
   - Affected code: MicMonitor.swift
   - Status: fixed by requiring at least one running input process before ducking.

## Permissions Findings (Fact-Checked)

### 1) Microphone access requires NSMicrophoneUsageDescription
- Unity’s macOS requirements documentation states that NSMicrophoneUsageDescription must be included in the macOS Info.plist for microphone access. (Source: Unity Vivox macOS requirements)
- Unity’s support article for macOS/iOS microphone permission states that if an app requests microphone permission without NSMicrophoneUsageDescription set, the app terminates with an error. (Source: Unity Support)

### 2) System Audio Recording permission exists in macOS and is user-controlled
- Apple Support documents a “Screen & System Audio Recording” privacy pane where users can allow screen and audio recording for an app, and explicitly notes that users can allow screen+audio or audio-only. (Source: Apple Support)

### 3) System audio capture via the CoreAudio process tap API uses NSAudioCaptureUsageDescription in practice
- The AudioCap sample project (insidegui/AudioCap) explicitly states that NSAudioCaptureUsageDescription is used to define the system-audio capture permission prompt, and that there is no public API to request/check that permission. (Source: AudioCap README)
- This is a community sample, not official Apple documentation, but it is a direct, working reference for macOS 14.4+ system audio capture.

## Recommendations

### Immediate (Production Readiness)
1) Consider adding a conversion path for non-Float32 formats if pass-through is undesirable.

## Sources
- Apple Support: “Control access to screen and system audio recording on Mac”
  https://support.apple.com/guide/mac-help/mchld6aa7d23/mac
- Unity Vivox macOS requirements (NSMicrophoneUsageDescription required)
  https://docs.unity.com/ugs/en-us/manual/vivox-core/manual/Core/developer-guide/macos/macos-requirements
- Unity Support: “Vivox: How to Request/check iOS & macOS microphone permission in Unity”
  https://support.unity.com/hc/en-us/articles/4431473872020-Vivox-How-to-Request-check-iOS-macOS-microphone-permission-in-Unity
- AudioCap sample: “NSAudioCaptureUsageDescription” and permission behavior
  https://github.com/insidegui/AudioCap
