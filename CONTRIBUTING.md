# Contributing

欢迎提交 Issue 和 Pull Request。

## 开发环境

- Flutter `3.41.6`
- Dart `3.11.4` 或项目约束兼容版本
- Android SDK 与 JDK 17

## 提交前验证

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
```

涉及 Android 构建时，再执行：

```bash
flutter build apk --release --target-platform android-arm64
```

## macOS 原生面板

修改 `macos-panel/` 后，在 macOS 上执行：

```bash
./macos-panel/test.sh
./macos-panel/build.sh
codesign --verify --deep --strict macos-panel/dist/QuotaDash.app
```

原生测试使用内存中的 HTTP 与存储替身，不会启动应用、访问钥匙串或连接真实服务。
相关 PR 会由独立的 macOS 工作流执行这些检查。

## 隐私与凭据

禁止提交真实 Management API 地址、管理密码、Token、认证文件、未脱敏日志或包含私人邮箱的截图。

新增配置项时，应优先判断是否属于敏感数据；敏感数据必须使用安全存储。
