class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.key,
    this.opencodeKey = '',
  });

  static const defaultBaseUrl = '';

  /// App version string — keep in sync with `pubspec.yaml`.
  static const appVersion = '1.0.0';

  final String baseUrl;
  final String key;
  final String opencodeKey;

  Uri get baseUri => Uri.parse(baseUrl);

  bool get hasOpencodeKey => opencodeKey.trim().isNotEmpty;

  AppConfig copyWith({String? baseUrl, String? key, String? opencodeKey}) {
    return AppConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      key: key ?? this.key,
      opencodeKey: opencodeKey ?? this.opencodeKey,
    );
  }
}
