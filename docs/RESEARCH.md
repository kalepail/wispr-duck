# WisprDuck Research Notes (Current + Archived)

This document preserves the research that informed WisprDuck and keeps it aligned with the current implementation. For detailed system-audio ducking approaches, see docs/AUDIO-DUCKING-APPROACHES.md.

## Current Implementation Summary

- **Ducking approach**: Core Audio process taps (macOS 14.2+)
- **Mic activity detection**: CoreAudio listener on `kAudioDevicePropertyDeviceIsRunningSomewhere`
- **Permissions**: Screen & System Audio Recording (system audio capture) and Microphone usage string for privacy compliance

This matches the code in WisprDuck and the audit report in docs/AUDIT-REPORT.md.

## Mic Activity Detection (Rationale)

### Recommended Approach: CoreAudio Property Listener

Monitor the `kAudioDevicePropertyDeviceIsRunningSomewhere` property on the default input device. This property changes when any app starts or stops using the mic.

Important considerations:
- Rebind the listener when the default input device changes (`kAudioHardwarePropertyDefaultInputDevice`).
- If needed, debounce mic-idle transitions to avoid rapid toggling.
- Even if you only inspect device state, include `NSMicrophoneUsageDescription` and test on target macOS versions.

References:
- https://docs.unity.com/ugs/en-us/manual/vivox-core/manual/Core/developer-guide/macos/macos-requirements
- https://support.unity.com/hc/en-us/articles/4431473872020-Vivox-How-to-Request-check-iOS-macOS-microphone-permission-in-Unity

## Archived Notes (Deprecated)

Earlier prototypes considered AppleScript-based per-app volume control and system volume ducking. These approaches are no longer the primary implementation and are kept only for historical context. See docs/AUDIO-DUCKING-APPROACHES.md for a concise comparison.

## References (Selected)

### Apple Documentation
- https://developer.apple.com/documentation/coreaudio/audioobjectaddpropertylistenerblock(_:_:_:_:)
- https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps

### Open Source Projects
- https://github.com/insidegui/AudioCap
- https://github.com/keithah/overhear
- https://github.com/BrianVia/transcriptor
- https://github.com/soulfresh/look-away

### Wispr Flow
- https://wisprflow.ai/
