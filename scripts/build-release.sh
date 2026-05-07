#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-"$ROOT_DIR/DerivedData/Release"}"
OUTPUT_DIR="${OUTPUT_DIR:-"$ROOT_DIR/build/release"}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD)}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

cd "$ROOT_DIR"

MARKETING_VERSION="$(awk -F '= ' '/MARKETING_VERSION/ { gsub(/;/, "", $2); print $2; exit }' WisprDuck.xcodeproj/project.pbxproj)"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/WisprDuck.app"
ZIP_PATH="$OUTPUT_DIR/WisprDuck-$MARKETING_VERSION-$BUILD_NUMBER.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

mkdir -p "$OUTPUT_DIR"

echo "==> Building WisprDuck $MARKETING_VERSION ($BUILD_NUMBER)"
xcodebuild \
  -project WisprDuck.xcodeproj \
  -scheme WisprDuck \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build

echo "==> Packaging $ZIP_PATH"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"

echo "Release artifact:"
echo "  $ZIP_PATH"
echo "  $CHECKSUM_PATH"
