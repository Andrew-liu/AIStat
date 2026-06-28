# Release Guide

This guide describes how to build and publish AIStat as a macOS app.

## 0. Standard release flow (checklist)

每次发布一个版本，按顺序执行以下步骤（以 `X.Y.Z` 代表目标版本）：

1. **确认变更已完成**：所有功能/修复就绪。
2. **运行校验**：`./scripts/check.sh`，确认 `BUILD SUCCEEDED` 且 `TEST SUCCEEDED`。
3. **升版本号**：把 `project.pbxproj` 中两处 `MARKETING_VERSION` 改为 `X.Y.Z`（Debug + Release）。必要时同步 `CURRENT_PROJECT_VERSION`。
4. **CHANGELOG 落版**：把 `CHANGELOG.md` 的 `[Unreleased]` 区块改为 `[X.Y.Z] - YYYY-MM-DD`，并更新底部的版本对比链接。
5. **提交并推送**：`git add -A && git commit -m "release: vX.Y.Z" && git push origin main`。
6. **打包 DMG**：`./scripts/package_dmg.sh`，产出 `release/AIStat-X.Y.Z.dmg`（按需签名/公证，见下文）。
7. **打 tag 并推送**：`git tag vX.Y.Z && git push origin vX.Y.Z`。
8. **创建 GitHub Release**：在网页选中 `vX.Y.Z` tag，上传 `release/AIStat-X.Y.Z.dmg`，填写发布说明（可参考 CHANGELOG 对应版本），勾选 Set as latest，Publish。

> 提示：旧版本的 DMG 可从 `release/` 删除以免混淆；`release/*.dmg` 已被 `.gitignore` 忽略，不进仓库，二进制只通过 GitHub Releases 分发。

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
