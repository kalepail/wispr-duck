# macOS Per-App Audio Ducking: Research & Approaches

## Overview

This document captures research on how to control per-app audio volume on macOS, specifically for ducking background audio when a microphone becomes active. This is relevant for adding browser ducking (YouTube, Spotify Web, etc.) and arbitrary app ducking beyond the current AppleScript-based music app control.

## Current Implementation (v2)

WisprDuck now uses **Core Audio process taps** (macOS 14.2+) for per‑app ducking, as described below. This replaces the earlier AppleScript-only approach and supports any app that appears in the Core Audio process list.

### Historical Notes (Deprecated)
- Early versions used AppleScript volume control for select music apps (Spotify, Apple Music, VLC, Vox). That approach is no longer the primary implementation.

## Approach 1: Core Audio Process Taps (macOS 14.2+)

**This is the recommended path for future per-app granular control.**

### What It Is

Apple introduced `AudioHardwareCreateProcessTap` in macOS 14.2. It allows tapping into another process's audio stream, reading the samples, and optionally muting the original output. You can then scale the samples (for volume control) and play them to the real output device.

### Architecture

```
[WisprDuck Menu Bar App]
    |
    |-- Monitor mic via kAudioDevicePropertyDeviceIsRunningSomewhere
    |
    |-- When mic becomes active:
    |     1. Enumerate running audio processes via kAudioHardwarePropertyProcessObjectList
    |     2. For each process to duck:
    |        a. Create CATapDescription with process PIDs
    |        b. Set muteBehavior to muted (silence original output)
    |        c. Create process tap via AudioHardwareCreateProcessTap
    |        d. Create aggregate device with tap (kAudioAggregateDeviceTapListKey)
    |        e. In IO callback: scale audio samples by duck factor (e.g., 0.2)
    |        f. Play scaled audio to real output device
    |
    |-- When mic becomes inactive:
    |     1. Destroy taps, restore normal audio flow
```

### Key API Flow

```swift
// 1. Create tap description
let tapDescription = CATapDescription(processes: processesToDuck)
tapDescription.setMuteBehavior(.muted) // silence original audio at speakers

// 2. Create the process tap
var tapID: AudioObjectID = kAudioObjectUnknown
AudioHardwareCreateProcessTap(&tapDescription, &tapID)

// 3. Create aggregate device with the tap
let aggregateDesc: [String: Any] = [
    kAudioAggregateDeviceMainSubDeviceKey: realOutputDeviceUID,
    kAudioAggregateDeviceTapListKey: [tapID],
    // ...
]
var aggregateID: AudioObjectID = kAudioObjectUnknown
AudioHardwareCreateAggregateDevice(&aggregateDesc, &aggregateID)

// 4. Attach IO callback
AudioDeviceCreateIOProcID(aggregateID, ioCallback, context, &ioProcID)
AudioDeviceStart(aggregateID, ioProcID)

// 5. In ioCallback: scale samples
func ioCallback(..., ioData: UnsafeMutablePointer<AudioBufferList>, ...) -> OSStatus {
    // Scale each sample by duckFactor (e.g., 0.2 for 20% volume)
    for buffer in ioData.pointee.mBuffers {
        let samples = buffer.mData?.assumingMemoryBound(to: Float32.self)
        for i in 0..<(buffer.mDataByteSize / 4) {
            samples?[Int(i)] *= duckFactor
        }
    }
    return noErr
}
```

### Permissions Required

- **Screen & System Audio Recording** permission in System Settings > Privacy & Security. Apple documents this pane and notes that users can allow audio-only access.
- Add `NSAudioCaptureUsageDescription` to Info.plist. The AudioCap sample uses this key for the system-audio capture permission prompt (and notes it is not exposed in Xcode’s plist key dropdown), and also notes there is no public API to request/check that permission.

References:
- https://support.apple.com/guide/mac-help/mchld6aa7d23/mac
- https://github.com/insidegui/AudioCap

### Reference Implementations

- **[FineTune](https://github.com/ronitsingh10/FineTune)** — Open-source SwiftUI menu bar app with per-app volume sliders using process taps. Best reference for our use case.
- **[AudioCap](https://github.com/insidegui/AudioCap)** — Sample code demonstrating the tap API.
- **[AudioTee](https://github.com/makeusabrew/audiotee)** — CLI tool for per-process tapping with include/exclude filtering.
- **[Core Audio Tap API gist](https://gist.github.com/sudara/34f00efad69a7e8ceafa078ea0f76f6f)** — Minimal example.

### Pros
- Per-app granular volume control for any app that appears in the Core Audio process list
- Public Core Audio API (no private frameworks required)
- No driver installation, no admin privileges, no restart
- Standard macOS permission prompt for system audio capture

### Cons
- Requires macOS 14.2+
- API is poorly documented (must read C headers: `CoreAudio/AudioHardware.h`)
- More complex implementation (aggregate devices, IO callbacks, audio buffer manipulation)
- Some reported bugs with multi-channel devices

### Implementation Notes

- Enumerate audio processes: `kAudioHardwarePropertyProcessObjectList` on `kAudioObjectSystemObject`
- Get PID from process object: `kAudioProcessPropertyPID`
- Get bundle ID from PID: `NSRunningApplication(processIdentifier:)?.bundleIdentifier`
- The tap captures audio BEFORE it reaches the output device, so you have full control
- Setting `muteBehavior = .muted` silences the original; your callback plays the modified audio
- For ducking (not muting), scale samples by `duckLevel / 100.0`

---

## Approach 2: Virtual Audio Device / HAL Plugin (BackgroundMusic)

### What It Is

Install a custom CoreAudio AudioServerPlugin that acts as a virtual audio device. Set it as the system default output. All app audio routes through it, where you can control per-app volume. Forward the (modified) audio to the real hardware output.

### Reference

- **[BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)** — Open-source, well-documented implementation.
- **[libASPL](https://github.com/gavv/libASPL)** — Library to simplify HAL plugin development.

### Pros
- Works on macOS 10.10+ (wide compatibility)
- Proven approach used by BackgroundMusic for years
- Full per-app volume control

### Cons
- Requires installing driver to `/Library/Audio/Plug-Ins/HAL/` (admin privileges)
- Requires `coreaudiod` restart after installation
- Not App Store compatible
- Complex C/C++ AudioServerPlugin implementation
- Must handle audio routing (virtual device → real output)
- Debugging requires disabling SIP in some cases

**Verdict:** Overkill for WisprDuck. Use Process Taps instead unless we need macOS <14.2 support.

---

## Approach 3: ARK-SDK (Rogue Amoeba)

### What It Is

Rogue Amoeba's commercial Audio Routing Kit SDK. Used by SoundSource. Provides an Objective-C API with Swift sample code for per-app audio capture and control.

### Details
- Licensed SDK: https://www.rogueamoeba.com/licensing/
- No system extension or driver install needed (macOS 14.4+)
- Likely wraps `AudioHardwareCreateProcessTap` internally
- Requires System Audio Access + Microphone permissions

**Verdict:** Commercial dependency. Use Process Taps directly instead.

---

## Approach 4: System Volume Ducking (Optional / Deprecated)

### What It Is

Duck the macOS system output volume globally. Simple, works for all audio.

### Implementation

```swift
// Using AppleScript:
// Get: "output volume of (get volume settings)"
// Set: "set volume output volume X"

// Or using CoreAudio directly:
// Get/set kAudioHardwareServiceDeviceProperty_VirtualMainVolume
// on the default output device
```

### Pros
- Very simple to implement
- Works for ALL audio (browsers, apps, games, everything)
- No additional permissions beyond what we already have
- Works on any macOS version

### Cons
- Not per-app: ducks EVERYTHING including the mic-using app's audio (e.g., the other person in a Zoom call)
- User may not want conferencing audio ducked

**Verdict:** Useful as a fallback for legacy macOS or edge cases, but not the primary implementation.

---

## What NOT To Do

### AppleScript JavaScript Injection (Browser Control)

```applescript
-- DON'T DO THIS
tell application "Google Chrome"
    execute front window's active tab javascript "document.querySelectorAll('video,audio').forEach(e => e.volume = 0.2)"
end tell
```

**Why not:**
- **Chrome disabled this by default** (since Chrome 59). Users must manually enable "Allow JavaScript from Apple Events" in Developer menu.
- **Actively exploited by malware** — Pirrit adware, Bundlore, ClickFix all use this pattern. Security tools will flag your app.
- **Fragile** — depends on page DOM structure, breaks across sites.
- **Safari only** allows it reliably, but only for the active tab of the front window.

References:
- [SentinelOne: How Offensive Actors Use AppleScript](https://www.sentinelone.com/blog/how-offensive-actors-use-applescript-for-attacking-macos/)
- [Chromium AppleScript Policy](https://www.chromium.org/developers/applescript/)

### ScreenCaptureKit for Audio-Only

- Requires screen recording permission (overkill)
- Shows screen recording indicator in menu bar
- Designed for video capture, audio is secondary
- Use Process Taps instead

### Private APIs (AudioDeviceDuck)

- Undocumented, can break between macOS versions
- App Store rejection risk
- No control over ducking parameters

---

## Recommended Roadmap (Updated)

1. **Current:** Core Audio Process Taps for per-app control (macOS 14.2+).
2. **Optional:** System volume ducking as a fallback mode if desired.
3. **Legacy:** AppleScript volume control kept only for historical reference.

## Comparison Table

| Approach | Per-App | Complexity | macOS Version | App Store | Installation |
|----------|---------|-----------|---------------|-----------|-------------|
| **AppleScript (v1)** | Music apps only | Easy | Any | Yes | None |
| **System Volume (v2)** | No (global) | Easy | Any | Yes | None |
| **Process Taps (v3)** | Yes, any app | Medium | 14.2+ | Yes | None (permission only) |
| **HAL Plugin** | Yes, any app | Hard | 10.10+ | No | Admin + restart |
| **ARK-SDK** | Yes, any app | Medium | 11+ | No | Licensed SDK |
| **JS Injection** | Browsers only | Easy | Any | No | Fragile/insecure |
