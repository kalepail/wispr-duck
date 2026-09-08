#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -module-cache-path "$TEST_DIR/ModuleCache" \
  "$ROOT_DIR/WisprDuck/DuckController.swift" \
  "$ROOT_DIR/WisprDuck/ProcessTapManager.swift" \
  "$ROOT_DIR/tests/AudioLifecycleTests.swift" \
  -o "$TEST_DIR/audio-tests"
"$TEST_DIR/audio-tests"
