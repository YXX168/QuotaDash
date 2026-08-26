# Changelog

此文件从首个正式版本开始记录发布变化。

## [Unreleased]

## [2.0.0] - 2026-08-26

### 多供应商模块化平台

- 供应商接入全面模块化：新增 QuotaModule 统一接口与 ProviderRegistry 注册表，
  新增供应商只需实现接口并注册，无需修改界面或存储层。
- 配置页按注册表动态生成每个供应商的设置区块，支持声明式字段（ProviderField）。
- 配置模型改为通用键值存储（AppConfig.values），所有供应商凭据保存在设备安全存储，
  旧版单一配置自动迁移，不丢数据。
- 能量球显示模式扩展到所有供应商：OpenCode 等通用供应商新增 ProviderEnergyCore
  能量核心渲染，与 CLIProxyAPI 账号能量核心风格统一。
- 仅配置 OpenCode 时也可正常使用仪表盘；CLIProxyAPI 失败时保留缓存数据并显示
  真实错误原因。
- 应用更名为 Quota Dash，版本升级至 2.0.0。

### 多供应商额度面板（进行中）
### 多供应商额度面板（进行中）

- 新增统一的 ProviderQuota 数据模型与 QuotaModule 模块接口，CLIProxyAPI 与 OpenCode 作为独立模块接入。
- 仪表盘按模块动态渲染各供应商额度卡片；单个模块失败不影响其他模块。
- 修复 OpenCode 能量条颜色过浅的问题：高剩余改用品红/青色系强调色，低剩余使用更醒目的红色与琥珀色。
- 应用标题更新为 Quota Dash（多供应商额度控制台）。

## [1.0.2] - 2026-08-20

### 额度展示修复

- 适配 ChatGPT Codex 当前返回的周额度窗口；不再把 primary_window 写死显示为 5 小时限额。
- 读取服务端的 limit_window_seconds（含驼峰兼容）判定周/月/短时窗口；服务端未返回时按当前单周窗口规则显示为周额度。
- 仅返回一个额度窗口时，账号卡片、详情页和能量核心不再渲染空的第二个额度槽位。

## [1.0.1] - 2026-08-13

### 接口兼容性修复

- 兼容 CLIProxyAPI 配置接口使用的模型显示名字段 `display-name`，同时保留 OAuth 模型接口的 `display_name` 支持。
- 修复 `recent_requests[].time` 被错误按 ISO 日期解析的问题，正确保留服务端返回的 `HH:mm-HH:mm` 时间窗口标签。
- 补充模型显示名和近期请求时间窗口的解析测试。

## [1.0.0] - 2026-08-10

### 正式发布

- CLIProxy Dash 公开仓库首版，全新签名证书与干净的发布历史。
- 重做首次启动与账户同步加载体验，采用深空玻璃、棱镜数据门、分层光轨和双向数据流；支持系统“减少动态效果”。
- 主页左上角使用棱镜信标标识，与启动页视觉语言一致。
- 支持 Codex OAuth 账号状态、额度窗口、重置时间和近期请求活动展示。
- 提供深海控制台与能量核心两种视觉模式。
- 新增模型管理工具，合并配置型模型与 OAuth 凭据运行时模型并按提供商去重分组。
- 新增客户端 API Key 管理，支持即时添加与删除。
- 允许 Android 连接可信局域网中的明文 HTTP CLIProxyAPI 实例。
- Management API 地址和管理密钥保存在 Android 安全存储中。
- 提供 ARM64 APK 与 SHA-256 完整性校验文件。

[1.0.2]: https://github.com/YXX168/CLIProxy-Dash/releases/tag/v1.0.2
[1.0.1]: https://github.com/YXX168/CLIProxy-Dash/releases/tag/v1.0.1
[1.0.0]: https://github.com/YXX168/CLIProxy-Dash/releases/tag/v1.0.0
