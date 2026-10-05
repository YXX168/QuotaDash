<div align="center">

# Quota Dash

**A privacy-conscious quota dashboard for multiple AI model providers.**

[![Android Build](https://github.com/YXX168/QuotaDash/actions/workflows/build.yml/badge.svg)](https://github.com/YXX168/QuotaDash/actions/workflows/build.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.41.6-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)](https://www.android.com/)

</div>

Quota Dash 是一个模块化的大模型额度仪表盘。Android 版提供完整的移动端界面，
macOS 版提供菜单栏面板；每个供应商以独立模块接入，
互不干扰；应用内置两种显示模式（卡片模式与能量球模式），并统一展示各供应商的
额度窗口与同步状态。

> 本项目由 CLIProxy Dash 演化而来，是独立的社区客户端，不隶属于任何模型服务提供方。

## 已接入的供应商

- **CLIProxyAPI** - Codex OAuth 账号状态、额度窗口、重置时间与近期请求活动。
- **Antigravity（通过 CLIProxyAPI）** - 自动发现已启用账号，逐个展示额度组、剩余百分比与恢复时间；兼容旧版模型额度响应。
- **OpenCode** - 滚动、周与月度额度窗口。
- **WorkBuddy / CodeBuddy（通过 CLIProxyAPI 插件）** - 多账号剩余积分、积分套餐与到期时间、账号状态和近期请求活动。

## Antigravity 使用说明

使用现有 CLIProxyAPI 服务地址与管理密码，无需额外填写 Google Token。
先在 CLIProxyAPI 中登录 Antigravity 账号，再刷新仪表盘即可显示。
优先读取 `retrieveUserQuotaSummary`，必要时回退到 `fetchAvailableModels`。
项目 ID 从账号元数据读取；旧版服务未公开该字段时，仅在内存中读取认证文件以提取项目 ID。
客户端不会保存 Google Token。缺少项目 ID 时会提示重新登录该账号。

每个额度组分别展示，能量模式主值为该账号已知额度中的「最低余量」，不代表总余额。
未返回的百分比显示 `--`；查询失败显示账号错误，不影响其他账号。
额度接口的剩余量不保证模型请求一定成功，模型可用性仍取决于上游限制。
请求趋势卡会合并 Codex、Antigravity 与 WorkBuddy 账号的近期请求时间桶，并在存在失败请求的时间段标出红点。

当服务地址使用新版 CLIProxyAPI 的 `/v8/management` 接口时，工具箱会显示“运行开关”，
可直接热更新局域网发现、远程管理、会话粘滞、日志、用量统计、插件等开关，也可以查看和编辑
完整 YAML 配置文件。应用仍兼容手动填写的旧 `/v0/management` 地址。

接口兼容性参考：[上游 Antigravity 数据层](https://github.com/router-for-me/Cli-Proxy-API-Management-Center/blob/main/src/features/quota/providers/antigravity/data.ts)。

## WorkBuddy 使用说明

在 CLIProxyAPI 中启用 WorkBuddy 插件并登录账号后，使用原有服务地址与管理密码即可自动发现。
客户端通过插件的 `accounts` 与按账号查询的 `credits` 接口读取积分，不下载认证文件或保存
WorkBuddy Token。v8 管理端搭配旧插件时，仅在插件路由返回 404 后回退到同一服务的
`/v0/management/plugins/workbuddy`，其他管理操作仍使用原来配置的 API 版本。

积分未知时显示 `--`，不会当成已耗尽；套餐的到期时间不等同于额度重置时间。
某个账号查询失败不会隐藏其他账号。卡片与能量球模式均可查看积分详情，请求趋势也会计入
WorkBuddy 的活动。客户端刷新只读取额度，不触发签到、试用领取或路由账号切换。

## 账号管理

工具箱中的「账号管理」可列出已启用、已禁用账号并切换状态。开关修改管理端凭证状态，
禁用的账号仍可在该页重新启用；操作完成后回读确认，返回首页会重新同步额度。
内存或来源配置账号需在管理端处理，客户端不会替换整份配置。

## Codex 降智测试

Android 可从工具箱中的「Codex 降智测试」进入原生测试页。服务端需安装并启用
[cpa-codex-candy-eval](https://github.com/haowang02/cpa-plugin-codex-candy-eval)（本次核验版本 0.3.8）。
支持糖果题、指纹测试和 ModelTrace，默认筛选 Codex，也可查看其他服务端凭证；读取服务端保留的
测试历史，提供批量启动、进度、指纹/ModelTrace 停止及记录详情。模型目录按凭证读取，
无法读取的目录保持未知，由 CPA 判断请求；插件路由仅在 404 时同源回退至 v0。

页面刷新只读取记录。启动测试会消耗账号额度，页面会显示每账号与本次批量的预计请求数，
部分测试失败后可能重试。糖果题正确率按所选模型和推理强度统计，失败与跳过不计入；
测试和模型归因结果仅供参考。名称脱敏，服务端原始错误不会展示，记录文本中的地址与常见密钥/令牌会隐藏。

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

## macOS 菜单栏面板

仓库内的 `macos-panel` 是一个不依赖 Flutter 的原生 macOS 桌面小组件，直接读取
CLIProxyAPI v8 管理接口，展示所有凭证的短时/周额度、刷新时间和主动重置次数；
禁用凭证也会单独标出。小组件可拖动、置顶并跨桌面空间显示，菜单栏摘要按供应商显示
最低剩余额度（例如 `C 43% · A 91% · W 65%`）。服务地址与管理密钥只写入 macOS 钥匙串，面板不会把地址或密钥写进源码。

在 macOS 上构建并启动：

```bash
cd macos-panel
./build.sh
open dist/QuotaDash.app
```

启动后会直接显示桌面小组件；点击菜单栏的 Quota Dash 图标可以隐藏或重新显示它。
首次使用时，在连接配置中填入 CLIProxyAPI 服务地址和管理密钥。
地址可以填服务根地址，面板会自动补全 `/v8/management`；兼容显式填写的
`/v0/management`。面板每 5 分钟自动刷新，也可以手动刷新。

## 安装 Android 版

### GitHub Releases

从 Releases 页面下载最新 ARM64 APK，并可使用同页提供的 SHA-256 文件校验完整性。

正式版签名证书 SHA-256：

```text
DE:58:35:3C:54:25:C2:73:5B:B0:2C:18:D6:C2:59:1F:A7:B9:71:D3:66:96:EE:FB:A8:AA:33:2B:26:55:77:83
```

### GitHub Actions

`main` 分支的成功构建会保留 30 天的 Debug APK、稳定签名 Release APK 和
Antigravity 视觉审阅截图，附件名称包含对应构建提交 SHA。

PR 同样执行格式检查、静态分析、测试以及 Debug / Release 模式编译，但不读取正式
签名密钥；PR 的 Release 模式编译仅用于验证，显式允许调试签名，不上传正式签名
Release 附件。PR 提供的 Debug APK 和视觉截图不等同于正式发布。

推送与 `pubspec.yaml` 版本一致的 `v*` 标签会自动构建正式签名版本，并创建 GitHub
Release，附 ARM64 APK 与 SHA-256 校验文件（需在仓库 Secrets 中配置签名密钥）。
正式发布状态以 GitHub Releases 页面为准，成功的 Actions Artifact 本身不代表已发布。

## 隐私与安全

- 所有 API 地址与密钥均由用户在设备端输入，通过 `flutter_secure_storage` 保存；
- 仓库源码不包含、也不上传任何真实地址或密钥；
- 不收集遥测数据；
- 错误提示不显示原始服务端内容或网络地址，带凭据的请求不自动跟随跳转；
- Android 自动备份与设备迁移不包含应用配置；
- 远程连接要求 HTTPS；HTTP 仅支持本机或局域网 IP；
- 密钥输入关闭输入法建议和个性化学习；Android 复制密钥使用敏感剪贴板标记，并在进程运行且内容未更换时尝试于 60 秒后清除；
- 请勿在 Issue、截图或日志中公开真实地址、密钥或账户信息。

## 开发

### 环境

- Flutter 3.41.6 / Dart 3.11.4
- Android SDK, JDK 17

### 本地验证

正式 APK 必须使用原来的发布密钥。在 `android/key.properties` 配置 `storeFile`、
`storePassword`、`keyAlias` 和 `keyPassword`；密钥路径相对于 `android/app`。
缺少正式签名时，Release 构建会报错。没有本地密钥时使用 GitHub Actions 的正式签名构建。
安装前应使用 Android SDK 的 `apksigner verify --print-certs` 核对上面的证书指纹。

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test --exclude-tags=golden
flutter build apk --release --target-platform android-arm64
```

贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
