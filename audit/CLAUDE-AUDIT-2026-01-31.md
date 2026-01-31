# WisprDuck Comprehensive Audit Report

**Date:** 2026-01-31
**Auditor:** Claude Opus 4.5
**Scope:** Full code review of the macOS app (9 Swift files, ~1800 lines), marketing site (React/Vite), build configuration, dependency analysis, and Core Audio best practices validation against reference implementations (AudioCap, Apple documentation) for macOS 14.2+.

---

## Verdict: Production-Ready

The codebase is well-structured, follows correct Core Audio patterns, and the previous audit findings (docs/AUDIT-REPORT.md) have all been addressed. There are no critical or high-severity issues remaining.

---

## What's Done Well

These are patterns that match or exceed best practices:

### 1. Correct Core Audio cleanup order
**File:** `ProcessTap.swift:128-139`

Stop -> DestroyIOProc -> DestroyAggregate -> DestroyTap. Matches the reference implementation from AudioCap exactly.

### 2. Lock-free audio volume ramping
**File:** `ProcessTap.swift:26-28`

`nonisolated(unsafe) Float` for `_targetLevel`/`_currentLevel`/`_rampRate`. 32-bit aligned float reads/writes are atomic on ARM64/x86_64. A one-buffer delay in volume change is imperceptible. This is the standard lock-free audio pattern.

### 3. Thread safety in MicMonitor
**File:** `MicMonitor.swift:28-56`

Dedicated `listenerQueue` with `DispatchSpecificKey` for safe re-entrancy detection. CoreAudio property reads happen on the listener queue, config reads dispatch to main. No data races.

### 4. Fade-out with tap reuse
**File:** `ProcessTapManager.swift:244-272`

`restoreAllWithFade()` ramps volume to 1.0 and schedules tap destruction. If `duck()` is called during fade-out, it cancels the timer and reuses existing taps. Prevents pop artifacts and handles rapid duck/unduck cycling correctly.

### 5. Output device monitoring
**File:** `ProcessTapManager.swift:329-374`

Taps are rebuilt when the default output device changes during an active duck session. Previous audit flagged this; it has been fixed.

### 6. `isDucked` accuracy
**File:** `DuckController.swift:98-102`

`duck()` returns whether any taps were actually created, so `isDucked` is never true with zero active taps. Previous audit flagged this; it has been fixed.

### 7. Non-Float32 format fallback
**File:** `ProcessTap.swift:166-179`

Detects tap format at start time. If not Float32 PCM, falls back to pass-through (`memcpy`) rather than corrupting audio. Previous audit flagged this; it has been fixed.

### 8. Trigger filtering
**File:** `MicMonitor.swift:260-300`

`shouldTriggerDuck` requires both a device-level "running" signal AND at least one matching process. Prevents over-triggering from driver quirks. Previous audit flagged this; it has been fixed.

### 9. Crash-safe audio restoration
**File:** `ProcessTap.swift:55`

`muteBehavior = .mutedWhenTapped` ensures audio auto-restores if WisprDuck crashes or is force-quit.

### 10. Correct aggregate device configuration
**File:** `ProcessTap.swift:69-89`

Private device, auto-start tap, drift compensation on tap (not sub-device), clock source set to output device. Matches best practices from Apple's Core Audio tap documentation and reference implementations.

### 11. Website accessibility
- Skip link for keyboard navigation
- `aria-label` on all icon-only links
- `aria-hidden` on decorative elements (stars, grass, crosshair, CRT overlay)
- Semantic HTML (`<nav>`, `<main>`, `<footer>`, `<ol>`)
- Keyboard `focus-visible` styles
- `prefers-reduced-motion` respected for both animations and smooth scroll

### 12. Website SEO
- Open Graph and Twitter Card meta tags with absolute image URLs
- Structured data (JSON-LD) with both `SoftwareApplication` and `FAQPage` schemas
- Canonical URL, meta description, lang attribute
- Proper `robots` meta tag

---

## Findings

### Medium Severity

#### M1. `deinit` calling `listenerQueue.sync` in MicMonitor

**File:** `MicMonitor.swift:41-48`

`deinit` calls `performOnListenerQueue` which may execute `listenerQueue.sync`. While this is safe in the current architecture (MicMonitor is owned by DuckController, a `@StateObject` that is released on the main thread, never on the listener queue), it is a fragile invariant. If the ownership model ever changes, this could deadlock.

**Risk:** Low. Current code paths guarantee deinit runs on the main thread.
**Recommendation:** No change needed unless ownership model changes. Worth a comment noting the invariant.

#### M2. `settings.objectWillChange` triggers redundant sync

**File:** `DuckController.swift:58-67`

The subscription to `settings.objectWillChange` calls `syncTriggerSettings()` on every settings change, including unrelated ones (e.g., duck level slider movement). This writes `triggerAllApps` and `triggerBundleIDs` to MicMonitor on every change, which triggers their `didSet` observers and calls `reevaluateTriggerState()`.

**Risk:** Low. These are fast operations (set comparisons and CoreAudio property reads). No user-visible impact.
**Recommendation:** Acceptable as-is. Could optimize with specific property observation if needed later.

#### M3. Tap buffer offset assumption for unusual devices

**File:** `ProcessTap.swift:164`

```swift
let tapOffset = max(0, inputs.count - outputs.count)
```

If a device reports input buffers in an unexpected layout, tap audio could be read from wrong buffers. The `guard inputIndex < inputs.count` check on line 187 prevents out-of-bounds access, so worst case is silence for some channels rather than a crash.

**Risk:** Low. Only affects unusual multi-channel audio interfaces.

---

### Low Severity / Cleanup

#### L1. Unused `lucide-react` dependency

**File:** `site/package.json:19`

`lucide-react` is listed as a dependency but is never imported anywhere in `site/src/`. It adds unnecessary weight to `node_modules` and the lockfile.

**Recommendation:** Remove it:
```
cd site && npm uninstall lucide-react
```

#### L2. Version inconsistency between Xcode project and package.json

- `MARKETING_VERSION = 1.2` (in `project.pbxproj:306,334`)
- `package.json`: `"version": "1.2.0"`

Minor inconsistency. Not a functional issue, but could cause confusion during releases.

**Recommendation:** Align both to `1.2.0`.

#### L3. `SWIFT_VERSION = 5.0` is outdated

**File:** `project.pbxproj:311,339`

The project uses `nonisolated(unsafe)` (Swift 5.10+) but the build setting says `5.0`. This works because Xcode's compiler version is determined by the Xcode installation, not this setting. However, updating to `6` would enable Swift 6 strict concurrency checking, which is good practice for a project doing cross-thread communication.

**Recommendation:** Consider setting to `6` and addressing any concurrency warnings as a future hardening measure.

#### L4. `CURRENT_PROJECT_VERSION = 1` for both Debug and Release

**File:** `project.pbxproj:296,323`

The `CFBundleVersion` (build number) is `1` in both configurations. For production distribution, each build should have a unique, incrementing build number. This is required for notarization and is used by macOS to differentiate versions.

**Recommendation:** Increment for each release or use a CI-generated build number.

#### L5. `*stellar.buzz/*` catch-all route in wrangler config

**File:** `site/wrangler.jsonc:11`

The `*stellar.buzz/*` pattern routes all traffic for the stellar.buzz zone through this worker. If other services are hosted on that zone, they would also be served by this worker (which just serves static assets). May be intentional.

**Recommendation:** Verify this is the desired behavior. If stellar.buzz hosts other services, narrow the pattern.

#### L6. `Set<String>` JSON encoding order non-determinism

**File:** `AppSettings.swift:111-115`

Sets are unordered, so `JSONEncoder().encode(ids)` may produce different JSON strings for the same set across runs, causing unnecessary `UserDefaults` writes. Not a functional issue.

**Risk:** Negligible. Slightly wasteful I/O on settings changes.

---

## Architecture Assessment

| Area | Assessment |
|------|-----------|
| **Thread safety** | Correct. CoreAudio reads on listener queue, UI state on main, lock-free floats for audio IO. No data races. |
| **Resource cleanup** | Correct. Cleanup order matches Apple reference. `deinit` + explicit `stop()` cover all paths. |
| **Memory management** | Correct. `[weak self]` in all listener callbacks. Strong capture in IO proc is intentional and broken by `stop()`. No retain cycles. |
| **Edge cases** | Handled. Rapid duck/unduck cycling, output device changes, stale process cleanup, non-Float32 formats, zero eligible targets. |
| **Permissions** | Correct. `NSMicrophoneUsageDescription` and `NSAudioCaptureUsageDescription` in Info.plist. `LSUIElement = true` for menu bar app. Sandbox disabled (required for CoreAudio process taps). |
| **Performance** | Event-driven throughout. No polling. CoreAudio property listeners fire only on state changes. Audio processing is minimal (per-sample multiply with linear ramp). |
| **Crash safety** | `mutedWhenTapped` ensures audio restores even on unexpected termination. |
| **Website** | Clean, accessible, performant. Single-page static deployment via Cloudflare Workers. |

---

## Edge Cases Verified

| Scenario | Behavior | Status |
|----------|----------|--------|
| Rapid mic on/off toggling | Fade-out timer cancelled, existing taps reused | Correct |
| Output device changed while ducked | Taps rebuilt for new device | Correct |
| Output device changed during fade-out | Fade completes on old device, taps destroyed | Acceptable |
| No eligible duck targets | `isDucked` stays false, no phantom state | Correct |
| Process PID reused after death | Stale tap cleaned up, new tap created for new process | Correct |
| Non-Float32 tap format | Pass-through without scaling | Correct |
| Mic active but no trigger apps match | `shouldTriggerDuck = false`, status shows "Mic Active" | Correct |
| App quit while ducked | `restoreAndStop()` immediately stops all taps | Correct |
| App crash while ducked | `mutedWhenTapped` auto-restores audio | Correct |
| Duck level slider while ducked | Live-updates all active taps | Correct |

---

## Dependency Audit

### macOS App (Swift)
- No third-party dependencies. Uses only Apple frameworks: SwiftUI, CoreAudio, AppKit, Combine, Foundation.
- All CoreAudio APIs used (`AudioHardwareCreateProcessTap`, `CATapDescription`, `AudioHardwareCreateAggregateDevice`) are public APIs introduced in macOS 14.2.

### Website (React/Vite)

| Dependency | Version | Status |
|-----------|---------|--------|
| react | ^19.2.0 | Current |
| react-dom | ^19.2.0 | Current |
| tailwindcss | ^4.1.18 | Current |
| @tailwindcss/vite | ^4.1.18 | Current |
| @radix-ui/react-separator | ^1.1.8 | Current |
| @radix-ui/react-slot | ^1.2.4 | Current |
| class-variance-authority | ^0.7.1 | Current |
| clsx | ^2.1.1 | Current |
| tailwind-merge | ^3.4.0 | Current |
| **lucide-react** | **^0.563.0** | **Unused — remove** |
| vite | ^7.2.4 | Current |
| wrangler | ^4.61.1 | Current |
| eslint | ^9.39.1 | Current |

---

## Previous Audit Status

All findings from docs/AUDIT-REPORT.md have been verified as resolved:

| Finding | Severity | Status |
|---------|----------|--------|
| MicMonitor listener thread safety | Critical | Fixed (listenerQueue serialization) |
| `isDucked` true with no active taps | High | Fixed (`duck()` returns tap existence) |
| Output device changes not handled | High | Fixed (output device monitoring) |
| Float32 format assumption | Medium | Fixed (format detection + pass-through fallback) |
| Over-triggering from device state | Medium | Fixed (process-level input check) |

---

## Actionable Items

Ordered by priority:

1. **Remove `lucide-react`** from site dependencies (dead dependency, no code changes needed)
2. **Increment `CURRENT_PROJECT_VERSION`** per release (required for notarization)
3. **Align version strings** between Xcode (`1.2`) and package.json (`1.2.0`)
4. **Consider Swift 6 language mode** for stricter concurrency checking (future hardening)

None of these block production release.
