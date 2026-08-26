/// Immutable per-provider settings map shared by every quota module.
///
/// Keys are module-defined (for example `baseUrl`, `managementKey` or
/// `apiKey`). Values are plain strings so they can be persisted directly
/// in secure storage. Empty values mean "not configured yet".
class AppConfig {
  const AppConfig({this.values = const <String, String>{}});

  /// App version string — keep in sync with `pubspec.yaml`.
  static const appVersion = '2.0.1';

  final Map<String, String> values;

  String value(String key) => values[key]?.trim() ?? '';

  bool isConfigured(String key) => value(key).isNotEmpty;

  bool hasAny(Iterable<String> keys) => keys.any(isConfigured);

  AppConfig withValues(Map<String, String> next) {
    return AppConfig(values: {...values, ...next});
  }
}
