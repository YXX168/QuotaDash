import 'codex_account.dart';

/// Credential identifiers remain private; only the masked name reaches the UI.
class ManagedAccount {
  ManagedAccount.fromJson(Map<String, dynamic> json)
    : id = _text(json['id']),
      fileName = _text(json['name']),
      name = AuthFileAccount.maskName(
        _text(json['label']).isNotEmpty
            ? _text(json['label'])
            : _text(json['email']).isNotEmpty
            ? _text(json['email'])
            : _text(json['name']),
      ),
      provider = _text(
        _text(json['provider']).isEmpty ? json['type'] : json['provider'],
      ).toLowerCase(),
      disabled = _boolean(json['disabled']),
      runtimeOnly =
          _boolean(json['runtime_only']) != false &&
          json['runtime_only'] != null,
      source = _text(json['source']).toLowerCase();

  final String id;
  final String fileName;
  final String name;
  final String provider;
  final bool? disabled;
  final bool runtimeOnly;
  final String source;

  String get identity => id.isEmpty ? fileName : id;
  String get lookup => fileName.isEmpty ? id : fileName;
  bool get canToggle =>
      identity.isNotEmpty &&
      disabled != null &&
      !runtimeOnly &&
      ['', 'file', 'auth_files'].contains(source) &&
      !provider.contains('api-key') &&
      !provider.contains('api_key');

  String get providerLabel => switch (provider) {
    'codex' => 'ChatGPT',
    'antigravity' => 'Antigravity',
    'workbuddy' => 'WorkBuddy',
    'claude' => 'Claude',
    'gemini' => 'Gemini',
    _ => fileName.toLowerCase().startsWith('workbuddy-') ? 'WorkBuddy' : '其他账号',
  };

  String get statusLabel => switch (disabled) {
    true => '已禁用',
    false => '已启用',
    null => '状态未知',
  };

  String get restriction =>
      disabled == null ? '状态未识别，请在管理端检查' : '请在管理端修改该账号的来源配置';

  static String _text(Object? value) => value?.toString().trim() ?? '';
  static bool? _boolean(Object? value) => switch (value) {
    true || 'true' => true,
    false || 'false' => false,
    _ => null,
  };
}
