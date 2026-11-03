#!/usr/bin/env bash
# End-to-end ducking check on real audio hardware.
#
# It plays a quiet 440 Hz test tone, runs WisprDuck with test settings, holds
# the mic open like a dictation app, and measures the level WisprDuck outputs:
#
#   before the mic opens   WisprDuck must not duck
#   while the mic is open  the tone must play at the duck level (10% = -20 dB)
#   after the mic closes   the tone must ramp back to full, then taps are removed
#
# Your WisprDuck settings are saved first and restored on exit. A running
# WisprDuck is quit and started again at the end.
#
# One-time permissions:
#   - "WisprDuck Test Harness": System Audio Recording (macOS asks on the first run)
#   - WisprDuck: System Audio Recording (the same grant the app already uses)
#   - "WisprDuck Test Mic": Microphone (macOS asks on the first run)
#
# Usage: ./scripts/duck-check.sh [--app PATH] [--duck-level N] [--tone-db N]
#   --app PATH       WisprDuck.app to test. Default: build Release from this checkout.
#   --duck-level N   Duck level percent, 1-100 (default 10).
#   --tone-db N      Test tone RMS level in dBFS (default -70, nearly inaudible).
#   --trigger-all    Use Trigger All Apps instead of the test mic as the one
#                    trigger app. The level meter reads process taps, so this
#                    also checks that tap readers do not count as mic users.
#   --build-only     Build the test tools and exit. Plays no audio.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${DERIVED_DATA_PATH:-"$ROOT_DIR/DerivedData"}/DuckCheck"
SRC_DIR="$ROOT_DIR/scripts/DuckCheck"
DOMAIN="com.wisprduck.WisprDuck"
TONE_BUNDLE_ID="com.wisprduck.testtone"
MIC_BUNDLE_ID="com.wisprduck.testmic"
HARNESS_BUNDLE_ID="com.wisprduck.testharness"

APP_PATH=""
BUILD_ONLY=0
TRIGGER_ALL=0
DUCK_LEVEL=10
TONE_DB=-70
BASELINE_SECONDS=2.5
MIC_SECONDS=4
AFTER_SECONDS=4

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP_PATH="$2"; shift 2 ;;
    --duck-level) DUCK_LEVEL="$2"; shift 2 ;;
    --tone-db) TONE_DB="$2"; shift 2 ;;
    --build-only) BUILD_ONLY=1; shift ;;
    --trigger-all) TRIGGER_ALL=1; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if ! [[ "$DUCK_LEVEL" =~ ^[0-9]+$ ]] || (( DUCK_LEVEL < 1 || DUCK_LEVEL > 100 )); then
  echo "--duck-level must be 1-100" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

# --- Build helpers ----------------------------------------------------------

# A stable signing identity keeps the System Audio Recording grant across
# rebuilds, because TCC matches the designated requirement, not the binary hash.
SIGN_IDENTITY="${DUCK_CHECK_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F '"' '/Apple Development/ { print $2; exit }')}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
  echo "warning: no Apple Development identity; using ad hoc signing." >&2
  echo "         macOS asks for System Audio Recording again after each rebuild." >&2
fi

# build_bundle NAME BUNDLE_ID SOURCE [USAGE_KEY USAGE_TEXT]
build_bundle() {
  local name="$1" bundle_id="$2" source="$3" usage_key="${4:-}" usage="${5:-}"
  local bundle="$OUT_DIR/$name.app"
  local binary="$bundle/Contents/MacOS/$name"
  if [[ -x "$binary" && ! "$source" -nt "$binary" && ! "$0" -nt "$binary" ]]; then
    return
  fi
  echo "==> Building $name.app" >&2
  rm -rf "$bundle"
  mkdir -p "$bundle/Contents/MacOS"
  swiftc -O -module-name "${name//[^A-Za-z0-9]/}" "$source" -o "$binary"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0"><dict>'
    echo "<key>CFBundleIdentifier</key><string>$bundle_id</string>"
    echo "<key>CFBundleName</key><string>$name</string>"
    echo "<key>CFBundleExecutable</key><string>$name</string>"
    echo '<key>CFBundlePackageType</key><string>APPL</string>'
    echo '<key>CFBundleVersion</key><string>1</string>'
    echo '<key>LSUIElement</key><true/>'
    if [[ -n "$usage_key" ]]; then
      echo "<key>$usage_key</key><string>$usage</string>"
    fi
    echo '</dict></plist>'
  } > "$bundle/Contents/Info.plist"
  codesign --force --sign "$SIGN_IDENTITY" "$bundle" >/dev/null 2>&1
}

TONE_APP="$OUT_DIR/WisprDuck Test Tone.app"
HARNESS_APP="$OUT_DIR/WisprDuck Test Harness.app"
MIC_APP="$OUT_DIR/WisprDuck Test Mic.app"

build_bundle "WisprDuck Test Tone" "$TONE_BUNDLE_ID" "$SRC_DIR/Tone.swift"
build_bundle "WisprDuck Test Harness" "$HARNESS_BUNDLE_ID" "$SRC_DIR/Meter.swift" \
  NSAudioCaptureUsageDescription "The WisprDuck test harness measures app audio levels to verify ducking."
build_bundle "WisprDuck Test Mic" "$MIC_BUNDLE_ID" "$SRC_DIR/MicHold.swift" \
  NSMicrophoneUsageDescription "The WisprDuck test mic opens the microphone to trigger ducking."

if [[ "$BUILD_ONLY" == 1 ]]; then
  echo "Built test tools in $OUT_DIR"
  exit 0
fi

if [[ -z "$APP_PATH" ]]; then
  echo "==> Building WisprDuck (Release)" >&2
  xcodebuild -project "$ROOT_DIR/WisprDuck.xcodeproj" -scheme WisprDuck -configuration Release \
    -derivedDataPath "$OUT_DIR/App" build -quiet
  APP_PATH="$OUT_DIR/App/Build/Products/Release/WisprDuck.app"
fi
APP_PATH="$(cd "$APP_PATH" && pwd)"
APP_BINARY="$APP_PATH/Contents/MacOS/WisprDuck"
[[ -x "$APP_BINARY" ]] || { echo "No WisprDuck binary at $APP_BINARY" >&2; exit 2; }

# --- Save state and set up --------------------------------------------------

RUN_DIR="$OUT_DIR/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"

PREFS_BACKUP="$RUN_DIR/prefs-backup.plist"
HAD_PREFS=0
if defaults read "$DOMAIN" >/dev/null 2>&1; then
  HAD_PREFS=1
  defaults export "$DOMAIN" "$PREFS_BACKUP"
fi

USER_APP=""
if pid="$(pgrep -x WisprDuck | head -1)" && [[ -n "$pid" ]]; then
  USER_APP="$(ps -o comm= -p "$pid" | sed 's#/Contents/MacOS/WisprDuck$##')"
  echo "==> Quitting the running WisprDuck ($USER_APP)" >&2
  pkill -x WisprDuck || true
  sleep 1
fi

cleanup() {
  pkill -f "$APP_BINARY" 2>/dev/null || true
  pkill -f "$TONE_APP/Contents/MacOS/" 2>/dev/null || true
  pkill -f "$HARNESS_APP/Contents/MacOS/" 2>/dev/null || true
  pkill -f "$MIC_APP/Contents/MacOS/" 2>/dev/null || true
  sleep 0.5
  defaults delete "$DOMAIN" >/dev/null 2>&1 || true
  if [[ "$HAD_PREFS" == 1 ]]; then
    defaults import "$DOMAIN" "$PREFS_BACKUP"
  fi
  if [[ -n "$USER_APP" ]]; then
    open -g "$USER_APP" || true
  fi
}
trap cleanup EXIT

defaults write "$DOMAIN" isEnabled -bool true
defaults write "$DOMAIN" duckLevel -int "$DUCK_LEVEL"
defaults write "$DOMAIN" duckAllApps -bool false
defaults write "$DOMAIN" duckBundleIDs3 -string "[\"$TONE_BUNDLE_ID\"]"
defaults write "$DOMAIN" triggerBundleIDs3 -string "[\"$MIC_BUNDLE_ID\"]"
if [[ "$TRIGGER_ALL" == 1 ]]; then
  defaults write "$DOMAIN" triggerAllApps2 -bool true
else
  defaults write "$DOMAIN" triggerAllApps2 -bool false
fi
defaults write "$DOMAIN" hasCompletedOnboarding -bool true
defaults write "$DOMAIN" wisprFlowHelperTriggerMigration1 -bool true

# --- Run --------------------------------------------------------------------

TOTAL_SECONDS="$(echo "$BASELINE_SECONDS + $MIC_SECONDS + $AFTER_SECONDS + 4" | bc)"
METER_SECONDS="$(echo "$BASELINE_SECONDS + $MIC_SECONDS + $AFTER_SECONDS" | bc)"

echo "==> Playing the test tone at $TONE_DB dBFS" >&2
open -g -n "$TONE_APP" --stdout "$RUN_DIR/tone.log" --stderr "$RUN_DIR/tone.log" \
  --args "$TOTAL_SECONDS" "$TONE_DB"

echo "==> Starting WisprDuck at duck level $DUCK_LEVEL%$([[ "$TRIGGER_ALL" == 1 ]] && echo ", Trigger All Apps")" >&2
# Launch through Launch Services, so macOS checks WisprDuck's own permissions
# and not the terminal's.
open -g -n "$APP_PATH" --stdout "$RUN_DIR/wisprduck.log" --stderr "$RUN_DIR/wisprduck.log"

TONE_PID=""
for _ in {1..30}; do
  TONE_PID="$(pgrep -f "$TONE_APP/Contents/MacOS/" | head -1 || true)"
  [[ -n "$TONE_PID" ]] && break
  sleep 0.1
done
[[ -n "$TONE_PID" ]] || { echo "The test tone did not start" >&2; exit 1; }
DUCK_PID="$(pgrep -f "$APP_BINARY" | head -1 || true)"
[[ -n "$DUCK_PID" ]] || { echo "WisprDuck did not start" >&2; exit 1; }
sleep 1.5

open -g -n "$HARNESS_APP" --stdout "$RUN_DIR/levels.csv" --stderr "$RUN_DIR/meter.err" \
  --args "$METER_SECONDS" 0.1 "TONE=$TONE_PID" "DUCK=$DUCK_PID"
sleep "$BASELINE_SECONDS"

echo "==> Holding the mic open for $MIC_SECONDS s" >&2
open -W -g -n "$MIC_APP" --stdout "$RUN_DIR/mic.log" --stderr "$RUN_DIR/mic.log" --args "$MIC_SECONDS"
if ! grep -q '^mic-off' "$RUN_DIR/mic.log"; then
  cat "$RUN_DIR/mic.log" >&2
  exit 1
fi
sleep "$AFTER_SECONDS"
sleep 0.5

# --- Analyze ----------------------------------------------------------------

MIC_ON="$(awk '/^mic-on/ { print $2 }' "$RUN_DIR/mic.log")"
MIC_OFF="$(awk '/^mic-off/ { print $2 }' "$RUN_DIR/mic.log")"

awk -F, -v mic_on="$MIC_ON" -v mic_off="$MIC_OFF" -v level="$DUCK_LEVEL" '
  function isnum(v) { return v ~ /^-?[0-9]+(\.[0-9]+)?$/ }
  NR == 1 { next }
  {
    t = $1; tone = $2; duck = $3
    if (isnum(tone)) { tone_sum += tone; tone_n++ }
    if (t < mic_on) {
      if (isnum(duck)) early_duck++
    } else if (t < mic_off) {
      if (isnum(duck) && first_duck == "") first_duck = t
      if (t >= mic_on + 1.0 && isnum(duck)) { ducked_sum += duck; ducked_n++ }
    } else {
      after_n++
      if (full_at == "" && isnum(duck) && tone_n > 0 && duck >= tone_sum / tone_n - 1.0) full_at = t
      if (full_at != "" && torn_down == "" && !isnum(duck)) torn_down = t
    }
  }
  END {
    fail = 0
    if (tone_n == 0) {
      print "FAIL: the meter read no tone. Grant System Audio Recording to \"WisprDuck Test Harness\"."
      exit 1
    }
    ref = tone_sum / tone_n
    expected = ref + 20 * log(level / 100) / log(10)
    printf "Tone level:               %.1f dBFS\n", ref

    if (early_duck > 0) {
      print "FAIL: WisprDuck ducked before the mic opened. Is another app using the mic?"
      fail = 1
    } else {
      print "PASS: no ducking before the mic opened"
    }

    if (ducked_n == 0) {
      print "FAIL: WisprDuck output nothing while the mic was open (no duck)"
      fail = 1
    } else {
      ducked = ducked_sum / ducked_n
      diff = ducked - expected
      printf "Ducked level:             %.1f dBFS (expected %.1f, %+.1f dB)\n", ducked, expected, diff
      printf "Duck started after:       %.2f s\n", first_duck - mic_on
      if (diff < -2 || diff > 2) { print "FAIL: ducked level is not within 2 dB of the duck level"; fail = 1 }
      else print "PASS: ducked level matches the duck level"
    }

    if (full_at == "") {
      if (ducked_n > 0) { print "FAIL: the tone did not ramp back to full after the mic closed"; fail = 1 }
    } else {
      printf "Back to full after:       %.2f s\n", full_at - mic_off
      if (full_at - mic_off > 2.0) { print "FAIL: restore took longer than 2 s"; fail = 1 }
      else print "PASS: the tone ramped back to full"
      if (torn_down == "") { print "FAIL: taps were not removed after the restore"; fail = 1 }
      else { printf "Taps removed after:       %.2f s\n", torn_down - mic_off; print "PASS: taps removed after the restore" }
    }
    exit fail
  }
' "$RUN_DIR/levels.csv" && RESULT=0 || RESULT=$?

echo "Logs: $RUN_DIR" >&2
if [[ "$RESULT" == 0 ]]; then echo "Duck check passed."; else echo "Duck check FAILED."; fi
exit "$RESULT"
