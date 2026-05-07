#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-"$ROOT_DIR/DerivedData/Verify"}"
cd "$ROOT_DIR"

echo "==> Validating project files"
plutil -lint WisprDuck/Info.plist WisprDuck/WisprDuck.entitlements WisprDuck.xcodeproj/project.pbxproj

echo "==> Building native app (Debug)"
xcodebuild \
  -project WisprDuck.xcodeproj \
  -scheme WisprDuck \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Building native app (Release)"
xcodebuild \
  -project WisprDuck.xcodeproj \
  -scheme WisprDuck \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Installing site dependencies"
npm ci --prefix site

echo "==> Linting site"
npm run lint --prefix site

echo "==> Building site"
npm run build --prefix site

echo "==> Checking whitespace"
git diff --check

echo "Verification complete."
