# Release Guide

This guide describes how to build and publish AIStat as a macOS app.

## 1. Prepare version numbers

Update these values in Xcode target build settings:

- `MARKETING_VERSION`, for example `1.0.0`
- `CURRENT_PROJECT_VERSION`, for example `1`

You can also override the DMG version name at packaging time:

```bash
VERSION=1.0.0 ./scripts/package_dmg.sh
```

## 2. Build an unsigned DMG for local testing

```bash
./scripts/package_dmg.sh
```

Output:

```text
release/AIStat-<version>.dmg
```

Unsigned apps are useful for local testing or source-based releases. Users may need to right-click and choose Open.

## 3. Build a signed DMG

Requirements:

- Apple Developer Program membership
- Developer ID Application certificate installed in Keychain
- Team ID

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
DEVELOPMENT_TEAM="TEAMID" \
./scripts/package_dmg.sh
```

Verify the app signature:

```bash
codesign --verify --deep --strict --verbose=2 release/AIStat-*.dmg
```

## 4. Notarize the DMG

Create an app-specific password at <https://appleid.apple.com/>.

```bash
APPLE_ID="you@example.com" \
TEAM_ID="TEAMID" \
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize_dmg.sh release/AIStat-<version>.dmg
```

The script will:

1. Submit the DMG using `xcrun notarytool`.
2. Wait for notarization.
3. Staple the ticket using `xcrun stapler`.
4. Verify the final DMG using `spctl`.

## 5. Create a GitHub release

```bash
git tag v1.0.0
git push origin v1.0.0
```

Then create a GitHub Release and upload:

```text
release/AIStat-1.0.0.dmg
```

## 6. Recommended release notes template

```markdown
## AIStat v1.0.0

### Highlights
- Compact macOS menu bar dashboard
- Codex and Claude usage overview
- CPU, memory, disk, battery status
- Keep Awake controls

### Notes
- Claude Desktop-only mode does not read Keychain by default.
- Unsigned builds may require right-click → Open.
```

## 7. Troubleshooting

### `dyld: Library not loaded: AIStat.debug.dylib`

Make sure `ENABLE_DEBUG_DYLIB = NO` is set in target build settings, then clean DerivedData.

### Xcode still runs an old build

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/AIStat-*
```

Then run:

```bash
xcodebuild -project AIStat.xcodeproj -scheme AIStat clean
```

### Notarization fails

Check:

- The app is signed with `Developer ID Application`, not `Apple Development`.
- The DMG is signed.
- The app does not contain unsigned nested binaries.
- `xcrun notarytool log <submission-id>` for details.
