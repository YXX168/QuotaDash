<div align="center">

# Quota Dash

**A privacy-conscious Android quota dashboard for multiple AI model providers.**

[![Android Build](https://github.com/YXX168/QuotaDash/actions/workflows/build.yml/badge.svg)](https://github.com/YXX168/QuotaDash/actions/workflows/build.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.6-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)](https://www.android.com/)

</div>

Quota Dash 是一个模块化的 Android 大模型额度仪表盘。每个供应商以独立模块接入，
互不干扰；应用内置两种显示模式（卡片模式与能量球模式），并统一展示各供应商的
额度窗口与同步状态。

> 本项目由 CLIProxy Dash 演化而来，是独立的社区客户端，不隶属于任何模型服务提供方。

## 已接入的供应商

- **CLIProxyAPI** - Codex OAuth 账号状态、额度窗口、重置时间与近期请求活动。
- **Antigravity（通过 CLIProxyAPI）** - 自动发现已启用账号，逐个展示额度组、剩余百分比与恢复时间；兼容旧版模型额度响应。
- **OpenCode** - 滚动、周与月度额度窗口。

## Antigravity 使用说明

使用现有 CLIProxyAPI 服务地址与管理密码，无需额外填写 Google Token。
先在 CLIProxyAPI 中登录 Antigravity 账号，再刷新仪表盘即可显示。
优先读取 `retrieveUserQuotaSummary`，必要时回退到 `fetchAvailableModels`。
项目 ID 从账号元数据读取；旧版服务未公开该字段时，仅在内存中读取认证文件以提取项目 ID。
客户端不会保存 Google Token。缺少项目 ID 时会提示重新登录该账号。

每个额度组分别展示，能量模式主值为该账号已知额度中的「最低余量」，不代表总余额。
未返回的百分比显示 `--`；查询失败显示账号错误，不影响其他账号。
额度接口的剩余量不保证模型请求一定成功，模型可用性仍取决于上游限制。
请求趋势卡目前统计 Codex 账号的近期请求。

接口兼容性参考：[上游 Antigravity 数据层](https://github.com/router-for-me/Cli-Proxy-API-Management-Center/blob/main/src/features/quota/providers/antigravity/data.ts)。

## 模块化架构

新增普通额度供应商只需三步，无需修改界面或存储层（CLIProxyAPI 的多账号数据由其账号仪表盘承载）：

1. 实现 `QuotaModule` 接口（数据获取、名称、图标、强调色）；
2. 用 `ProviderField` 声明所需的配置字段（配置页自动渲染）；
3. 在 `ProviderRegistry.defaultFactories` 中注册该模块。

所有供应商的设置都以键值形式保存在设备安全存储中，旧版单一配置会自动迁移。

## 显示模式

- **卡片模式**：传统信息卡，展示额度条与详细窗口。
- **能量球模式**：动态能量核心，按剩余比例渲染光环与轨道动画。

两种模式对所有已接入的供应商统一生效，可在设置中随时切换。

## 安装

### GitHub Releases

从 Releases 页面下载最新 ARM64 APK，并可使用同页提供的 SHA-256 文件校验完整性。

正式版签名证书 SHA-256：

```text
C4:32:2F:65:9C:61:DF:7F:50:46:10:DD:FE:3B:37:E1:7C:26:1C:55:1A:6D:A3:1E:A0:AB:AC:3C:1D:2E:B9:91
```

### GitHub Actions

`main` 分支的成功构建会保留 30 天调试 Artifact；推送 `v*` 标签会自动构建
正式签名版本（需在仓库 Secrets 中配置签名密钥）。

## 隐私与安全

- 所有 API 地址与密钥均由用户在设备端输入，通过 `flutter_secure_storage` 保存；
- 仓库源码不包含、也不上传任何真实地址或密钥；
- 不收集遥测数据；
- 请勿在 Issue、截图或日志中公开真实地址、密钥或账户信息。

## 开发

### 环境

- Flutter 3.41.6 / Dart 3.11.4
- Android SDK, JDK 17

### 本地验证

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test --exclude-tags=golden
flutter build apk --release --target-platform android-arm64
```

贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
