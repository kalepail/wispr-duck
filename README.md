<p align="center">
  <img src="docs/banner-dark.png" width="700" alt="WisprDuck — Shhh... Ducking volume.">
</p>

<p align="center">
  <strong>Auto-duck background audio when your mic is active.</strong><br>
  A lightweight macOS menu bar utility for voice-to-text, calls, and recording.
</p>

<p align="center">
  <a href="../../releases/latest"><img src="https://img.shields.io/github/v/release/kalepail/wispr-duck?style=flat-square" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14.2%2B-blue?style=flat-square" alt="macOS 14.2+">
  <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=flat-square" alt="Apache 2.0 License">
</p>

---

## What is WisprDuck?

WisprDuck sits in your menu bar and watches for microphone activity. When any app starts using the mic — voice-to-text tools like [Wispr Flow](https://wispr.com), video calls, screen recordings — WisprDuck automatically lowers the volume of other apps so your voice comes through clearly. When the mic goes idle, volume smoothly fades back up.

No manual toggling. No keyboard shortcuts. Just works.

## Features

- **Automatic mic detection** — monitors the default input device, no setup required
- **Smooth linear fade** — 1-second constant-rate volume transitions, no harsh jumps
- **Per-app control** — duck all audio or pick specific apps (Spotify, Chrome, Discord, etc.)
- **Crash-safe** — uses `mutedWhenTapped` so audio auto-restores if WisprDuck quits unexpectedly
- **Lightweight** — event-driven Core Audio listeners, no polling, minimal CPU usage
- **Smart grouping** — Chrome helpers, Slack workers, etc. automatically group under their parent app

## Installation

1. Download **WisprDuck.zip** from the [latest release](../../releases/latest)
2. Unzip and drag **WisprDuck.app** to `/Applications`
3. Launch WisprDuck
4. On first launch: right-click the app → **Open** (required for unsigned apps)
5. Grant **microphone access** when prompted

> WisprDuck runs as a menu bar app — no Dock icon. Look for the duck foot in your menu bar.

## How It Works

WisprDuck uses [Core Audio process taps](https://developer.apple.com/documentation/coreaudio) (macOS 14.2+) to intercept audio at the system level. When the mic goes active:

1. **Detect** — A Core Audio listener fires when any app activates the default input device
2. **Tap** — Process taps are created for target apps, muting their original audio at the system mixer
3. **Scale** — The intercepted audio is scaled by the duck level and played through an aggregate device
4. **Restore** — When the mic goes idle, volume linearly ramps back to 100% over ~1 second, then taps are destroyed

The `mutedWhenTapped` behavior is the safety net: if WisprDuck crashes or is force-quit, macOS automatically unmutes all tapped processes. Audio is never permanently stuck at a low volume.

## Configuration

Click the duck foot icon in your menu bar:

| Setting | Description |
|---------|-------------|
| **Enable Monitoring** | Toggle WisprDuck on/off |
| **Duck Level** | How much to reduce volume (0–100%) |
| **Duck All Audio** | Duck every app or only selected ones |
| **Audio Apps** | Select specific apps to duck when not in "all" mode |

## Requirements

- **macOS 14.2+** (Sonoma) — required for Core Audio process taps
- **Microphone permission** — WisprDuck reads a device-level boolean to detect mic activity, but macOS still requires the permission grant

## Building from Source

```bash
git clone https://github.com/kalepail/wispr-duck.git
cd wispr-duck
open WisprDuck.xcodeproj
```

Build and Run with **Cmd+R** in Xcode. Requires Xcode 15+ with the macOS 14.2+ SDK.

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
