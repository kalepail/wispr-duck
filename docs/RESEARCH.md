# Wispr Flow Audio Ducking: Research & Implementation Plan

## Problem Statement

When using [Wispr Flow](https://wisprflow.ai/) (a voice-to-text app) on macOS, background music competes with your voice while dictating. The goal is to build a lightweight macOS utility that:

1. **Detects** when the microphone is actively being used (i.e., Wispr Flow is recording)
2. **Ducks** background music volume automatically
3. **Restores** music volume when the mic goes idle

---

## How Wispr Flow Works

Wispr Flow is a cloud-based voice-to-text app for macOS. Key technical details relevant to this project:

- **Activation**: User presses a hotkey (e.g., `Fn` twice) to start recording. Recording stops when the hotkey is released (push-to-talk) or toggled (hands-free mode).
- **Visual indicator**: A "Flow bar" at the bottom of the screen shows animated white level bars while recording.
- **Audio cue**: A "ping" sound plays when recording starts.
- **Microphone access**: Uses standard macOS Core Audio for mic input. Requires microphone permission via System Settings > Privacy & Security > Microphone.
- **No documented public hooks/API for recording state**: As of this research, Wispr Flow does not document an API, AppleScript dictionary, notification, or callback for external apps to detect when it's actively recording.
- **Standard mic usage**: When recording, Wispr Flow opens the default input device through Core Audio like any other app, which means macOS *does* know the mic is in use (orange dot appears).

**Key insight**: We don't need to detect Wispr Flow specifically. We just need to detect when the **system microphone becomes active**. Since Wispr Flow is the primary dictation app, mic-active = ducking time.

---

## Detection: How to Know When the Mic Is Active

### Recommended Approach: CoreAudio Property Listener

The proven, lightweight method is to monitor the `kAudioDevicePropertyDeviceIsRunningSomewhere` property on the default input device. This property changes to `1` when **any** application starts using the mic, and back to `0` when all apps release it.

This is the same technique used by:
- **[OverSight](https://objective-see.org/products/oversight.html)** (Objective-See's mic/camera monitor) — uses `AudioObjectAddPropertyListenerBlock` on each audio device's `kAudioDevicePropertyDeviceIsRunningSomewhere` property, then identifies the process via system log parsing
- **[Overhear](https://github.com/keithah/overhear)** — `MicUsageMonitor.swift` — clean, modern Swift implementation
- **[LookAway](https://github.com/soulfresh/look-away)** — `MicrophoneActivityMonitor.swift` — monitors all input devices
- **[Transcriptor](https://github.com/BrianVia/transcriptor)** — `MicrophoneMonitor.swift` — includes debouncing for brief mic pauses

#### How It Works

```swift
import CoreAudio

// 1. Get the default input device
var deviceID = AudioObjectID()
var size = UInt32(MemoryLayout<AudioObjectID>.size)
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &address, 0, nil, &size, &deviceID
)

// 2. Register a listener for "is running somewhere"
var runningAddress = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
    mScope: kAudioObjectPropertyScopeInput,
    mElement: kAudioObjectPropertyElementMain
)

AudioObjectAddPropertyListenerBlock(deviceID, &runningAddress, DispatchQueue.main) { _, _ in
    // 3. Query current state
    var isRunning: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(deviceID, &runningAddress, 0, nil, &dataSize, &isRunning)

    if isRunning != 0 {
        // Mic is active → duck music
    } else {
        // Mic is idle → restore music
    }
}
```

#### Important Considerations

- **Also monitor default device changes**: If the user switches their input device (e.g., plugs in an external mic), you need to re-register the listener on the new device. Listen for `kAudioHardwarePropertyDefaultInputDevice` changes on `kAudioObjectSystemObject`.
- **Debouncing**: When the mic goes idle, add a short delay (1-3 seconds) before restoring volume. This prevents rapid volume toggling if Wispr Flow briefly releases and re-acquires the mic between dictations.
- **Privacy permission note**: This listener does not access audio samples, but macOS microphone privacy rules still apply to any app that requests mic access or uses APIs that trigger a mic permission prompt. Include `NSMicrophoneUsageDescription` and test on target macOS versions.

References:
- https://docs.unity.com/ugs/en-us/manual/vivox-core/manual/Core/developer-guide/macos/macos-requirements
- https://support.unity.com/hc/en-us/articles/4431473872020-Vivox-How-to-Request-check-iOS-macOS-microphone-permission-in-Unity

### Alternative Approaches (Not Recommended for This Use Case)

| Approach | Pros | Cons |
|----------|------|------|
| **Orange dot detection** (parsing Control Center accessibility tree) | Detects any mic use | Fragile, depends on undocumented UI structure, unreliable timing |
| **AVAudioEngine audio tap** | Can analyze actual audio content | Requires mic permission, adds latency, overkill |
| **Process monitoring** (check if Wispr Flow process has mic open) | Wispr-Flow-specific | Complex, requires log parsing (like OverSight), macOS version dependent |
| **Polling `kAudioDevicePropertyDeviceIsRunningSomewhere`** | Simple | Wastes CPU; event-driven listener is better |

---

## Volume Control: Historical Notes (Deprecated)

### AppleScript via NSAppleScript/Process

The simplest and most effective approach for music apps is AppleScript. Both Apple Music and Spotify expose volume control through their scripting dictionaries.

#### Spotify

```applescript
-- Get current volume
tell application "Spotify" to get sound volume
-- Returns: integer 0-100

-- Set volume
tell application "Spotify" to set sound volume to 20

-- Check if running
tell application "System Events" to (name of processes) contains "Spotify"
```

#### Apple Music

```applescript
-- Get current volume
tell application "Music" to get sound volume
-- Returns: integer 0-100

-- Set volume
tell application "Music" to set sound volume to 20

-- Check if running
tell application "System Events" to (name of processes) contains "Music"
```

#### System Volume (Fallback)

If you want to duck ALL audio rather than targeting specific apps:

```applescript
-- Get current volume (0-100)
output volume of (get volume settings)

-- Set volume
set volume output volume 20

-- Save and restore
set currentVol to output volume of (get volume settings)
set volume output volume 20
-- ... later ...
set volume output volume currentVol
```

#### From Swift

```swift
import Foundation

func runAppleScript(_ script: String) -> String? {
    let appleScript = NSAppleScript(source: script)
    var error: NSDictionary?
    let result = appleScript?.executeAndReturnError(&error)
    return result?.stringValue
}

// Example: duck Spotify to 20%
func duckSpotify() {
    runAppleScript("tell application \"Spotify\" to set sound volume to 20")
}

// Example: restore Spotify to previous volume
func restoreSpotify(to volume: Int) {
    runAppleScript("tell application \"Spotify\" to set sound volume to \(volume)")
}
```

### Alternative Volume Control Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **AppleScript per-app** (recommended) | Simple, no dependencies, targets specific apps | Only works for apps with AppleScript support |
| **System volume** | Universal, trivial | Ducks ALL audio including notifications, system sounds |
| **BackgroundMusic virtual device** | True per-app volume for any app | Requires installing a virtual audio driver, complex, alpha-quality |
| **SoundSource / Sound Control** | Professional per-app control | Commercial ($), not programmatically controllable |
| **Core Audio HAL** | Low-level system volume | Complex C API, no per-app control without virtual device |

---

## Existing Open-Source Reference Projects

### [BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) (18.6k stars)
- Installs a virtual audio device as the system default output
- Intercepts all app audio, provides per-app volume sliders
- Has auto-pause feature: pauses music player when other audio plays
- Architecture: `BGMDriver` (HAL plugin in coreaudiod) + `BGMApp` (menu bar app) + `BGMXPCHelper`
- Written in Objective-C++/C++
- **Relevant but overkill** for our use case — we don't need a virtual audio device

### [OverSight](https://objective-see.org/products/oversight.html) (Objective-See)
- Detects mic/camera activation at the hardware level
- Uses `AudioObjectAddPropertyListenerBlock` on `kAudioDevicePropertyDeviceIsRunningSomewhere`
- Identifies which process activated the mic by parsing system logs (`com.apple.coremedia` on macOS 14+, `com.apple.SystemStatus` on older versions)
- Can execute scripts when mic activates
- **Relevant for detection approach** — same CoreAudio technique we'd use

### [Overhear MicUsageMonitor](https://github.com/keithah/overhear)
- Clean Swift `@MainActor` implementation
- Monitors `kAudioDevicePropertyDeviceIsRunningSomewhere` on default input device
- Handles default device changes with rebinding
- Provides `onChange: (Bool) -> Void` callback
- **Best reference implementation** for our mic detection component

### [Transcriptor MicrophoneMonitor](https://github.com/BrianVia/transcriptor)
- Swift singleton pattern
- Includes 3-second debounce for mic deactivation (prevents false triggers from brief mute/unmute)
- Immediate activation trigger, delayed deactivation
- **Good reference** for debouncing logic

### [LookAway MicrophoneActivityMonitor](https://github.com/soulfresh/look-away)
- Monitors ALL input devices (not just default)
- Tracks per-device running state
- Filters out always-on audio interfaces (e.g., Universal Audio)
- **Good reference** for multi-device monitoring

### [Monitored](https://github.com/gergelysanta/Monitored)
- Swift package for detecting when being monitored (mic + camera)
- Clean API surface
- Could potentially be used as a dependency

---

## Recommended Architecture

### Simplest Viable Implementation

A **macOS menu bar app** (SwiftUI) with three components:

```
┌─────────────────────────────────────────┐
│           WisprDuck (Menu Bar)          │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────┐                    │
│  │  MicMonitor     │ CoreAudio listener │
│  │  (detection)    │ on default input   │
│  └────────┬────────┘ device             │
│           │                             │
│           │ mic active/idle             │
│           ▼                             │
│  ┌─────────────────┐                    │
│  │  DuckController │ State machine:     │
│  │  (logic)        │ normal ↔ ducked    │
│  └────────┬────────┘ with debounce      │
│           │                             │
│           │ duck/restore                │
│           ▼                             │
│  ┌─────────────────┐                    │
│  │  VolumeControl  │ AppleScript to     │
│  │  (action)       │ Spotify / Music    │
│  └─────────────────┘                    │
│                                         │
└─────────────────────────────────────────┘
```

### Component Details

**1. MicMonitor**
- Registers `AudioObjectPropertyListenerBlock` on `kAudioDevicePropertyDeviceIsRunningSomewhere` for the default input device
- Also watches `kAudioHardwarePropertyDefaultInputDevice` for device changes (re-binds listener)
- Publishes `Bool` state: mic is active / mic is idle

**2. DuckController**
- On mic active: immediately save current music volume, set ducked volume
- On mic idle: start debounce timer (e.g., 2 seconds). If mic stays idle for the full duration, restore original volume. If mic reactivates during debounce, cancel the timer.
- Configurable duck level (e.g., 20% of original, or a fixed value like volume 15)

**3. VolumeControl**
- Checks which music apps are running (Spotify, Music)
- Uses `NSAppleScript` to get/set their volume
- Stores the "original" volume to restore later

### Menu Bar UI

- Status icon shows current state (e.g., speaker icon, ducked icon)
- Menu items:
  - Enable/Disable toggle
  - Duck level slider (how much to reduce volume)
  - Debounce delay setting
  - "Quit"

### Permissions Required

| Permission | Why | Required? |
|-----------|-----|-----------|
| **Microphone** | **Not needed.** We only check `isRunningSomewhere`, not the audio stream | No |
| **Accessibility** | Needed for AppleScript to control other apps | Yes (System Settings > Privacy > Accessibility) |
| **Automation** | AppleScript needs permission to control Spotify/Music | Yes (prompted automatically on first use) |

### Technology Choices

| Aspect | Choice | Reasoning |
|--------|--------|-----------|
| Language | **Swift** | Native macOS, best CoreAudio support |
| UI Framework | **SwiftUI** + `MenuBarExtra` | Minimal menu bar app, macOS 13+ |
| Mic detection | **CoreAudio C API** | Direct, no dependencies, event-driven |
| Volume control | **NSAppleScript** | Simplest path, no dependencies |
| Build system | **Xcode / Swift Package Manager** | Standard macOS app tooling |

---

## Edge Cases & Considerations

### What triggers the mic as "active"?

The `kAudioDevicePropertyDeviceIsRunningSomewhere` flag fires for **any** app using the mic:
- Wispr Flow dictating
- Zoom/Teams/FaceTime calls
- Siri
- Voice Memos
- Any other recording app

This is actually a **feature**: you probably want music ducked during video calls too. But if you only want it for Wispr Flow, you'd need to additionally check which process owns the mic (complex, version-dependent log parsing like OverSight does).

### Multiple music apps

If both Spotify and Apple Music are running, duck both. Save/restore volumes independently.

### Music already paused

Before ducking, check if the music app is actually playing. No point lowering volume on a paused app. Both Spotify and Apple Music expose `player state` via AppleScript:

```applescript
tell application "Spotify" to get player state
-- Returns: "playing", "paused", or "stopped"
```

### App not running

If Spotify/Music isn't running, skip it. Don't launch the app just to set its volume. Check process list first:

```applescript
tell application "System Events" to (name of processes) contains "Spotify"
```

### Volume restoration after crash

If the duck app crashes while music is ducked, the volume stays low. Consider:
- Persisting the "original volume" to disk (UserDefaults)
- On launch, check if a restore is needed
- Periodic health check

### Bluetooth mic delay

Wispr Flow's docs note that Bluetooth mics (AirPods) have a connection delay. The mic may briefly activate then deactivate as Bluetooth negotiates. The debounce timer handles this naturally.

---

## Alternative: Simpler Script-Based Approach

If a full Swift app feels like overkill, this could be implemented as a **command-line tool + launchd agent**:

```swift
// A simple Swift CLI that monitors the mic and runs AppleScript
// Could be ~100 lines of code
// Installed as a LaunchAgent for auto-start
```

Or even a **Hammerspoon script** (Lua-based macOS automation):
- [Hammerspoon](https://www.hammerspoon.org/) has `hs.audiodevice` bindings
- The [Hammerspoon-AudioMonitor](https://github.com/Jarva/Hammerspoon-AudioMonitor) project demonstrates mic monitoring via Hammerspoon's Spoon architecture
- Could implement the entire duck logic in ~50 lines of Lua

---

## Summary: Feasibility Assessment

| Aspect | Verdict |
|--------|---------|
| **Is it possible?** | Yes, fully feasible |
| **Detect mic usage** | Proven technique via `kAudioDevicePropertyDeviceIsRunningSomewhere` — event-driven, near-instant; still include mic usage strings for privacy compliance |
| **Control music volume** | Easy via AppleScript for Spotify & Apple Music |
| **Complexity** | Low — the core logic is ~200 lines of Swift |
| **Dependencies** | None — pure macOS APIs (CoreAudio + NSAppleScript) |
| **Permissions** | Accessibility + Automation (standard for AppleScript apps) |
| **Limitations** | Ducks on ANY mic usage (not just Wispr Flow); AppleScript only works for apps that support it |

**Bottom line**: This is a straightforward macOS menu bar app. The mic detection side is well-proven by multiple open-source projects, and the volume control side is trivial with AppleScript. A working prototype could be built with minimal code.

---

## References

### Apple Documentation
- [Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/CoreAudioEssentials/CoreAudioEssentials.html)
- [AudioObjectAddPropertyListenerBlock](https://developer.apple.com/documentation/coreaudio/audioobjectaddpropertylistenerblock(_:_:_:_:))
- [Capturing System Audio with Core Audio Taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps) (macOS 14.2+)
- [AVAudioInputNode voiceProcessingOtherAudioDuckingConfiguration](https://developer.apple.com/documentation/avfaudio/avaudioinputnode/voiceprocessingotheraudioduckingconfiguration)

### Open Source Projects
- [BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic) — per-app volume via virtual audio device
- [OverSight](https://objective-see.org/products/oversight.html) — mic/camera activation monitor
- [Overhear MicUsageMonitor](https://github.com/keithah/overhear) — clean Swift mic monitor
- [Transcriptor MicrophoneMonitor](https://github.com/BrianVia/transcriptor) — mic monitor with debounce
- [LookAway MicrophoneActivityMonitor](https://github.com/soulfresh/look-away) — multi-device mic monitor
- [Monitored](https://github.com/gergelysanta/Monitored) — Swift framework for mic/camera detection
- [BlackHole](https://github.com/ExistentialAudio/BlackHole) — virtual audio loopback driver
- [Hammerspoon-AudioMonitor](https://github.com/Jarva/Hammerspoon-AudioMonitor) — Hammerspoon mic monitoring Spoon
- [sountop](https://github.com/Coalesce-Software-Inc/sountop) — real-time process audio monitoring

### Wispr Flow
- [Wispr Flow Website](https://wisprflow.ai/)
- [Technical Challenges Blog Post](https://wisprflow.ai/post/technical-challenges)
- [Help: First Dictation on Desktop](https://docs.wisprflow.ai/articles/6817365244-your-first-dictation-on-desktop)
- [Help: Transcription Problems](https://docs.wisprflow.ai/articles/8828249960-transcription-problems)
- [API Documentation](https://api-docs.wisprflow.ai/introduction)
- [Privacy & Data Controls](https://wisprflow.ai/data-controls)

### Commercial Tools
- [SoundSource](https://rogueamoeba.com/soundsource/) — per-app volume control (Rogue Amoeba)
- [Sound Control](https://staticz.com/soundcontrol/) — per-app volume + EQ
