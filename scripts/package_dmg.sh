#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/AIStat.xcodeproj}"
SCHEME="${SCHEME:-AIStat}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-AIStat}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_DIR/DerivedData}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/release}"
STAGING_DIR="$BUILD_DIR/dmg-staging"

function read_build_setting() {
  local key="$1"
  xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null \
    | awk -F'= ' -v key="$key" '$1 ~ key { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }'
}

VERSION="${VERSION:-$(read_build_setting MARKETING_VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(read_build_setting CURRENT_PROJECT_VERSION)}"
VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
DMG_NAME="${DMG_NAME:-$APP_NAME-$VERSION.dmg}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME $VERSION}"

mkdir -p "$BUILD_DIR" "$RELEASE_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER) [$CONFIGURATION]"

BUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -destination "platform=macOS"
)

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  echo "==> Building with Developer ID signing"
  xcodebuild "${BUILD_ARGS[@]}" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build
else
  echo "==> Building unsigned app (set SIGNING_IDENTITY to sign)"
  xcodebuild "${BUILD_ARGS[@]}" CODE_SIGNING_ALLOWED=NO build
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Staging DMG contents"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"

echo "==> Creating DMG: $DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  echo "==> Signing DMG"
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

echo "==> Done"
echo "$DMG_PATH"
