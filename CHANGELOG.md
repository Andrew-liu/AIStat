# Changelog

本文件记录 AIStat 的逐版本变更。格式参考 [Keep a Changelog](https://keepachangelog.com/)，版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

开发约定：每次发布新版本或完成重要改动，把变更追加到本文件顶部的对应版本下。

## [Unreleased]

### Changed
- 重构 AI 用量层：抽出统一的 `UsageProvider` 协议与平级数据模型 `ProviderUsage`，每个 AI Provider 独立实现取数逻辑，对外暴露统一的「额度窗口 + 成本」模型。
- 将 Claude 从 `CodexUsageSummary` 中解耦，提升为与 Codex 平级的独立 Provider（`ClaudeProvider`），UI 层无需感知具体 Provider。
- `CodexUsageReader` 的取数实现拆分为 `CodexProvider` 与 `ClaudeProvider` 两个独立单元，为后续接入更多 Provider（Gemini、Copilot 等）打基础。

### Docs
- 重写 `design.md`：补充设计思路、设计哲学、整体架构、Provider 扩展模型与版本里程碑。
- 新增 `CHANGELOG.md`，确立逐版本变更记录约定。

## [1.0.0] - 2026-06-28

### Added
- macOS 菜单栏面板，基于 SwiftUI `MenuBarExtra`。
- AI 用量：Codex 额度、Token 与成本概览；在有本地数据源时展示 Claude 额度、Token 与成本。
- 额度多源回退：Codex 走 OAuth API → CLI RPC → 本地 session 日志 → 缓存；Claude 走 OAuth 凭据 → CLI `/usage` → 缓存 → Desktop 检测降级。
- 「上一次成功额度缓存」机制，避免临时刷新失败时面板空白。
- 系统状态：CPU、内存、磁盘、电池概览，磁盘读写速度，可点击查看详情页。
- Keep Awake：Off / 15m / 30m / 1h / 2h / 4h / 永久，阻止空闲与显示器睡眠，菜单栏图标跟随状态变化。
- 本地优先设计：成本基于本地 JSONL 日志按模型定价估算，不上传用量数据；默认避免 Claude Keychain 访问。
- 打包与发布脚本：`scripts/package_dmg.sh`、`scripts/notarize_dmg.sh`。

[Unreleased]: https://github.com/Andrew-liu/AIStat/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Andrew-liu/AIStat/releases/tag/v1.0.0
