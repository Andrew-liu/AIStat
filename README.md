<h1 align="center">AIStat</h1>

<p align="center">
  <strong>一个紧凑的 macOS 菜单栏仪表盘，集中查看 AI 编程用量、系统状态，并提供 Keep Awake 防睡眠控制。</strong>
</p>

<p align="center">
  AIStat 把 Codex / Claude 的额度、本机 Token 与成本、系统状态，以及 Keep Awake 防睡眠开关集中在一个面板里 —— 无需在多个应用之间来回切换，即可掌握 AI 编程预算、让 Mac 保持运行，并随时查看设备状态。
</p>

<p align="center">
  <a href="https://github.com/Andrew-liu/AIStat/releases/latest"><img src="https://img.shields.io/github/v/release/Andrew-liu/AIStat?style=for-the-badge&logo=apple" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/macOS-14+-000000?style=for-the-badge&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=for-the-badge&logo=swift" alt="Swift 5.9+">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License MIT"></a>
</p>

<p align="center">
  <a href="https://github.com/Andrew-liu/AIStat/releases/latest">下载</a> ·
  <a href="#功能特性">功能</a> ·
  <a href="#数据与隐私">数据与隐私</a> ·
  <a href="#从源码构建">从源码构建</a>
</p>

<p align="center">
  <strong>简体中文</strong> | <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="docs/images/dashboard.png" alt="AIStat 仪表盘" width="420">
</p>

## 为什么选择 AIStat

| | |
| --- | --- |
| **AI 预算一眼掌握** | Codex 与 Claude 的额度、Token 用量和成本，集中在一个菜单栏面板。 |
| **让 Mac 保持唤醒** | 一键阻止空闲与显示器睡眠，支持 15 分钟到永久。 |
| **本地优先** | 用量数据来自本地凭据、CLI 工具和日志，不经过任何自定义后端。 |

为长时间使用 Claude Code、Codex 的 macOS 开发者打造，让 AI 预算和系统状态始终触手可及。

## 功能特性

| 模块 | 能力 |
| --- | --- |
| **AI 用量** | Codex 额度及 Token / 成本概览；在有本地数据源时展示 Claude 额度；支持上一次成功额度缓存，避免临时刷新失败导致空白。 |
| **系统状态** | CPU、内存、磁盘、电池概览；磁盘读写速度；可点击查看详情页。 |
| **Keep Awake** | Off、15m、30m、1h、2h、4h、永久；阻止空闲与显示器睡眠；菜单栏图标跟随防睡眠状态变化。 |

基于 SwiftUI `MenuBarExtra` 构建，采用按指标模块化的架构，方便后续扩展更多 Provider。

## 安装

1. 从 [Releases](https://github.com/Andrew-liu/AIStat/releases/latest) 下载最新 `.dmg`。
2. 将 `AIStat.app` 拖入 `/Applications`。
3. 从启动台或应用程序中启动 AIStat。

> DMG 尚未经过 Apple 公证。首次启动时请右键点击应用并选择 **打开**，以绕过 Gatekeeper。

## 数据与隐私

AIStat 采用本地优先设计，不会把用量数据上传到自定义后端，并默认避免自动访问 Claude Keychain，防止弹出系统密码提示。

| 数据 | 来源 |
| --- | --- |
| 系统指标 | 在本机本地读取。 |
| Codex Token / 成本 | 从本地 Codex 会话日志扫描。 |
| Claude Token / 成本 | 在存在本地 Claude Code 日志时从本机扫描。 |
| Codex 额度 | Codex OAuth usage API `https://chatgpt.com/backend-api/wham/usage`。 |
| Claude 额度 | Claude OAuth usage API `https://api.anthropic.com/api/oauth/usage`。 |

仅在读取 Provider 额度接口时才会产生网络访问。

## 环境要求

- 推荐 macOS 14 或更新版本
- 推荐 Xcode 16 或更新版本
- Swift 5.9+
- 可选数据源：
  - 带有 `~/.codex/auth.json` 的 Codex app / CLI
  - Claude Code CLI 或 Claude OAuth 凭据文件

## 从源码构建

```bash
git clone https://github.com/Andrew-liu/AIStat.git
cd AIStat
open AIStat.xcodeproj
```

在 Xcode 中选择 `AIStat` scheme 并运行。或使用命令行构建：

```bash
xcodebuild \
  -project AIStat.xcodeproj \
  -scheme AIStat \
  -configuration Debug \
  -derivedDataPath .derivedData \
  build
```

生成本地未签名 DMG：

```bash
./scripts/package_dmg.sh   # 输出：release/AIStat-<version>.dmg
```

如果有 Apple Developer 证书，可生成签名 DMG：

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
DEVELOPMENT_TEAM="TEAMID" \
./scripts/package_dmg.sh
```

对已签名 DMG 进行公证：

```bash
APPLE_ID="you@example.com" \
TEAM_ID="TEAMID" \
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize_dmg.sh release/AIStat-<version>.dmg
```

## 技术栈

`SwiftUI` · `MenuBarExtra` · `IOKit` · `pmset` · `caffeinate` · `xcodebuild`

## 数据源说明

**Codex** —— AIStat 按以下顺序读取：从 `~/.codex/auth.json` 读取 Codex OAuth usage API → 通过 `codex app-server` 读取 Codex CLI RPC → 本地 Codex session 日志 → 上一次成功的额度缓存。如果 Codex 只返回 30 天窗口，AIStat 会显示 `30d`，不会强行显示为 `5h` 或 `Week`。

**Claude** —— AIStat 避免自动弹出 Keychain 密码提示。额度可从 Claude OAuth 凭据文件 → Claude Code CLI `/usage` → 上一次成功的额度缓存读取。如果只安装了 Claude Desktop，可能显示 `Desktop only`，因为读取 Claude Desktop cookies 需要 Keychain 访问权限。

## 发布检查清单

1. 在 Xcode 中更新 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`。
2. 执行 `./scripts/package_dmg.sh`。
3. 如果不是仅发布源码构建版本，建议对 DMG 进行签名和公证。
4. 创建发布 tag：`git tag v1.0.0 && git push origin v1.0.0`。
5. 将生成的 DMG 上传到 GitHub Releases。

## 开源协议

MIT © 2026 Andrew-liu。详见 [LICENSE](LICENSE)。
