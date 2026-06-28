#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: APPLE_ID=... TEAM_ID=... APP_SPECIFIC_PASSWORD=... $0 path/to/AIStat.dmg" >&2
  exit 2
fi

DMG_PATH="$1"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "error: DMG not found: $DMG_PATH" >&2
  exit 1
fi

: "${APPLE_ID:?APPLE_ID is required}"
: "${TEAM_ID:?TEAM_ID is required}"
: "${APP_SPECIFIC_PASSWORD:?APP_SPECIFIC_PASSWORD is required}"

echo "==> Submitting for notarization: $DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying stapled DMG"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "==> Notarized DMG ready: $DMG_PATH"
