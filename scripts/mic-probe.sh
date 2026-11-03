#!/usr/bin/env bash
# Show which processes use the mic and whether WisprDuck would duck.
# Example: ./scripts/mic-probe.sh --seconds 20 --trigger com.granola.app
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${DERIVED_DATA_PATH:-"$ROOT_DIR/DerivedData"}/MicProbe"
BINARY="$OUT_DIR/mic-probe"
SOURCES=(
  "$ROOT_DIR/scripts/MicProbe/main.swift"
  "$ROOT_DIR/WisprDuck/Utilities.swift"
  "$ROOT_DIR/WisprDuck/TriggerMatching.swift"
  "$ROOT_DIR/WisprDuck/AppSettings.swift"
)

mkdir -p "$OUT_DIR"
needs_build=0
[[ -x "$BINARY" ]] || needs_build=1
for source in "${SOURCES[@]}"; do
  if [[ "$source" -nt "$BINARY" ]]; then needs_build=1; fi
done

if [[ "$needs_build" == 1 ]]; then
  swiftc -O -module-name MicProbe "${SOURCES[@]}" -o "$BINARY"
fi

exec "$BINARY" "$@"
