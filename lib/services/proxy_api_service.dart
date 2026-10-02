import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/model_info.dart';

/// Extended management API service for CLIProxyAPI.
///
/// Provides access to model lists, API key management, runtime configuration
/// and version checking. v8 URLs use the new management API tree while an
/// explicitly configured v0 URL keeps the legacy contract.
class ProxyApiService {
  ProxyApiService({
    required this.baseUri,
    required this.managementKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final String managementKey;
  final http.Client _client;

  bool get usesV8 => baseUri.path.contains('/v8/management');

  /// Releases the HTTP client resources.
  void dispose() => _client.close();

  /// Fetches the full runtime config and extracts model information.
  Future<ModelListResult> fetchModels() async {
    final config = await _getJson(_endpoint('config'));
    final groups = <String, _ProviderAccumulator>{};

    // Map legacy provider config keys to display names. v8 additionally
    // exposes upstream groups under api-keys/<provider>.
    const providerMap = {
      'gemini-api-key': 'Gemini',
      'interactions-api-key': 'Google Interactions',
      'codex-api-key': 'OpenAI Codex',
      'claude-api-key': 'Anthropic Claude',
      'xai-api-key': 'xAI',
      'openai-compatibility': 'OpenAI Compatible',
      'vertex-api-key': 'Vertex AI',
    };

    for (final entry in providerMap.entries) {
      final rawList = _configList(config, entry.key);
      if (rawList is! List) continue;

      if (entry.key == 'openai-compatibility') {
        for (final item in rawList) {
          if (item is! Map) continue;
          final itemMap = Map<String, dynamic>.from(item);
          final configuredName = itemMap['name']?.toString().trim() ?? '';
          final providerName = configuredName.isEmpty
              ? entry.value
              : configuredName;
          _mergeConfigEntry(groups, providerName, itemMap);
        }
      } else {
        for (final item in rawList) {
          if (item is! Map) continue;
          _mergeConfigEntry(
            groups,
            entry.value,
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    _mergeOAuthExclusions(
      groups,
      usesV8
          ? _nestedValue(config, ['oauth', 'excluded-models']) ??
                config['oauth-excluded-models']
          : config['oauth-excluded-models'],
    );
    await _mergeOAuthModels(groups);

    final providers =
        groups.values
            .where(
              (group) => group.models.isNotEmpty || group.excluded.isNotEmpty,
            )
            .map((group) => group.toProviderGroup())
            .toList()
          ..sort(
            (left, right) => left.provider.toLowerCase().compareTo(
              right.provider.toLowerCase(),
            ),
          );
    return ModelListResult(providers: providers, rawConfig: config);
  }

  void _mergeConfigEntry(
    Map<String, _ProviderAccumulator> groups,
    String providerName,
    Map<String, dynamic> item,
  ) {
    final group = groups.putIfAbsent(
      providerName,
      () => _ProviderAccumulator(providerName),
    );
    final modelList = item['models'];
    if (modelList is List) {
      for (final rawModel in modelList) {
        if (rawModel is! Map) continue;
        group.addModel(
          ModelInfo.fromJson(Map<String, dynamic>.from(rawModel), providerName),
        );
      }
    }
    group.addExcluded(item['excluded-models']);
  }

  void _mergeOAuthExclusions(
    Map<String, _ProviderAccumulator> groups,
    Object? rawExclusions,
  ) {
    if (rawExclusions is! Map) return;
    for (final entry in rawExclusions.entries) {
      final providerName = _providerDisplayName(entry.key.toString());
      groups
          .putIfAbsent(providerName, () => _ProviderAccumulator(providerName))
          .addExcluded(entry.value);
    }
  }

  Future<void> _mergeOAuthModels(
    Map<String, _ProviderAccumulator> groups,
  ) async {
    Map<String, dynamic> authResponse;
    try {
      authResponse = await _getJson(
        _endpoint(usesV8 ? 'credentials' : 'auth-files'),
      );
    } on Exception {
      // Older servers may not expose runtime model discovery. Configured
      // models remain useful, so keep them available in that case.
      return;
    }
    final files = authResponse['files'];
    if (files is! List) return;

    final lookups = <String>{};
    final requests = <Future<void>>[];
    for (final rawFile in files) {
      if (rawFile is! Map) continue;
      final file = Map<String, dynamic>.from(rawFile);
      if (_isTrue(file['disabled'])) continue;

      final id = file['id']?.toString().trim() ?? '';
      final name = file['name']?.toString().trim() ?? '';
      final lookup = id.isNotEmpty ? id : name;
      if (lookup.isEmpty || !lookups.add(lookup)) continue;
      final provider = file['provider']?.toString().trim() ?? '';
      final type = file['type']?.toString().trim() ?? '';
      final rawProvider = provider.isNotEmpty ? provider : type;
      final providerName = _providerDisplayName(rawProvider);
      requests.add(_mergeAuthFileModels(groups, providerName, lookup));
    }
    await Future.wait(requests);
  }

  Future<void> _mergeAuthFileModels(
    Map<String, _ProviderAccumulator> groups,
    String providerName,
    String lookup,
  ) async {
    try {
      final uri = _endpoint(
        usesV8 ? 'credentials/models' : 'auth-files/models',
      ).replace(queryParameters: {'name': lookup});
      final response = await _getJson(uri);
      final models = response['models'];
      if (models is! List) return;
      final group = groups.putIfAbsent(
        providerName,
        () => _ProviderAccumulator(providerName),
      );
      for (final rawModel in models) {
        if (rawModel is! Map) continue;
        group.addModel(
          ModelInfo.fromJson(Map<String, dynamic>.from(rawModel), providerName),
        );
      }
    } on Exception {
      // One stale credential must not hide models from all other providers.
    }
  }

  /// Fetches the list of client API keys.
  Future<List<String>> fetchApiKeys() async {
    final decoded = await _getValue(
      _endpoint(usesV8 ? 'config/access/api-keys' : 'api-keys'),
    );
    final keys = decoded is List
        ? decoded
        : decoded is Map
        ? (decoded['api-keys'] ?? decoded['api_keys'])
        : null;
    if (keys is! List) {
      throw const ProxyApiException('管理接口返回了无法识别的 API Key 列表');
    }
    return keys.map((e) => e.toString()).toList();
  }

  /// Replaces the full list of client API keys (PUT /api-keys).
  Future<void> replaceApiKeys(List<String> keys) async {
    final uri = _endpoint(usesV8 ? 'config/access/api-keys' : 'api-keys');
    final response = await _client
        .put(uri, headers: _headers, body: jsonEncode(keys))
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
  }

  /// Adds a client API key without replacing the complete server-side list.
  Future<void> addApiKey(String value) async {
    if (usesV8) {
      final keys = await fetchApiKeys();
      keys.add(value);
      await replaceApiKeys(keys);
      return;
    }
    await updateApiKey(oldValue: value, newValue: value);
  }

  /// Adds or replaces a single client API key (PATCH /api-keys).
  ///
  /// Provide either [oldValue] + [newValue] (rename) or [index] + [value]
  /// (positional replace). Mixing both forms is rejected.
  Future<void> updateApiKey({
    String? oldValue,
    String? newValue,
    int? index,
    String? value,
  }) async {
    final byOldNew = oldValue != null || newValue != null;
    final byIndex = index != null || value != null;
    if (byOldNew == byIndex) {
      throw ArgumentError('use either old/new or index/value, not both');
    }
    if (byOldNew && (oldValue == null || newValue == null)) {
      throw ArgumentError('oldValue and newValue must be provided together');
    }
    if (byIndex && (index == null || value == null)) {
      throw ArgumentError('index and value must be provided together');
    }
    if (usesV8) {
      final keys = await fetchApiKeys();
      if (byOldNew) {
        final position = keys.indexOf(oldValue!);
        if (position < 0) throw const ProxyApiException('找不到要修改的 API Key');
        keys[position] = newValue!;
      } else {
        if (index! < 0 || index >= keys.length) {
          throw const ProxyApiException('API Key 下标超出范围');
        }
        keys[index] = value!;
      }
      await replaceApiKeys(keys);
      return;
    }
    final Map<String, Object?> body = byOldNew
        ? {'old': oldValue, 'new': newValue}
        : {'index': index, 'value': value};
    final uri = _endpoint('api-keys');
    final response = await _client
        .patch(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
  }

  /// Deletes a client API key (DELETE /api-keys?value=... or ?index=...).
  Future<void> deleteApiKey({String? value, int? index}) async {
    if ((value == null) == (index == null)) {
      throw ArgumentError('provide exactly one of value or index');
    }
    if (usesV8) {
      final keys = await fetchApiKeys();
      final position = value != null ? keys.indexOf(value) : index!;
      if (position < 0 || position >= keys.length) {
        throw const ProxyApiException('找不到要删除的 API Key');
      }
      keys.removeAt(position);
      await replaceApiKeys(keys);
      return;
    }
    final query = value != null ? {'value': value} : {'index': '$index'};
    final uri = _endpoint('api-keys').replace(queryParameters: query);
    final response = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
  }

  /// Fetches the latest version from GitHub releases.
  Future<String?> fetchLatestVersion() async {
    try {
      final response = await _getJson(
        _endpoint(usesV8 ? 'server/latest-version' : 'latest-version'),
      );
      return response['latest-version']?.toString() ??
          response['latestVersion']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Reads a v8 configuration node as its native JSON value.
  Future<Map<String, dynamic>> fetchRuntimeConfig() async {
    if (!usesV8) throw const ProxyApiException('运行开关需要 CLIProxyAPI v8');
    final decoded = await _getValue(_endpoint('config'));
    if (decoded is! Map) {
      throw const ProxyApiException('CLIProxyAPI 返回的配置不是对象');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Reads a v8 configuration node as its native JSON value.
  Future<Object?> readConfigPath(String path) async {
    if (!usesV8) throw const ProxyApiException('运行开关需要 CLIProxyAPI v8');
    final normalized = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (normalized.isEmpty) throw const ProxyApiException('配置路径不能为空');
    return _getValue(_endpoint('config/$normalized'));
  }

  /// Replaces a v8 configuration node. Writes are hot-reloaded by the proxy.
  Future<void> writeConfigPath(String path, Object? value) async {
    if (!usesV8) throw const ProxyApiException('运行开关需要 CLIProxyAPI v8');
    final normalized = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (normalized.isEmpty) throw const ProxyApiException('配置路径不能为空');
    final response = await _client
        .put(
          _endpoint('config/$normalized'),
          headers: _headers,
          body: jsonEncode(value),
        )
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
  }

  /// Downloads the persisted v8 YAML configuration file.
  Future<String> fetchConfigYaml() async {
    if (!usesV8) throw const ProxyApiException('配置文件需要 CLIProxyAPI v8');
    final response = await _client
        .get(
          _endpoint('config.yaml'),
          headers: {..._headers, 'Accept': 'application/yaml'},
        )
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
    return utf8.decode(response.bodyBytes);
  }

  /// Replaces the persisted v8 YAML configuration file.
  Future<void> replaceConfigYaml(String yaml) async {
    if (!usesV8) throw const ProxyApiException('配置文件需要 CLIProxyAPI v8');
    final response = await _client
        .put(
          _endpoint('config.yaml'),
          headers: {..._headers, 'Content-Type': 'application/yaml'},
          body: yaml,
        )
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
  }

  // ── Internal helpers ──────────────────────────────────────────

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $managementKey',
    'Content-Type': 'application/json',
  };

  Uri _endpoint(String name) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$basePath/$name');
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final decoded = await _getValue(uri);
    if (decoded is! Map) {
      throw const ProxyApiException('管理接口返回了无法识别的数据');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Object?> _getValue(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 25));
    _checkResponse(response);
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ProxyApiException('管理接口返回了无效 JSON');
    }
  }

  List<Object?>? _configList(Map<String, dynamic> config, String key) {
    final legacy = config[key];
    if (legacy is List) return legacy;
    if (!usesV8) return null;
    final provider = _v8ProviderKey(key);
    final nested = _nestedValue(config, ['api-keys', provider]);
    return nested is List ? nested : null;
  }

  static String _v8ProviderKey(String key) {
    switch (key) {
      case 'gemini-api-key':
        return 'gemini';
      case 'interactions-api-key':
        return 'interactions';
      case 'codex-api-key':
        return 'codex';
      case 'claude-api-key':
        return 'claude';
      case 'xai-api-key':
        return 'xai';
      case 'vertex-api-key':
        return 'vertex';
      case 'openai-compatibility':
        return 'openai-compatibility';
      default:
        return key;
    }
  }

  static Object? _nestedValue(Map<String, dynamic> map, List<String> path) {
    Object? current = map;
    for (final segment in path) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final preview = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      final previewText = preview.isEmpty
          ? ''
          : '：${preview.substring(0, preview.length.clamp(0, 180).toInt())}';
      throw ProxyApiException('管理接口返回 HTTP ${response.statusCode}$previewText');
    }
  }

  static bool _isTrue(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  static String _providerDisplayName(String provider) {
    switch (provider.trim().toLowerCase()) {
      case 'codex':
        return 'OpenAI Codex';
      case 'claude':
      case 'anthropic':
        return 'Anthropic Claude';
      case 'gemini':
        return 'Gemini';
      case 'aistudio':
        return 'Google AI Studio';
      case 'antigravity':
        return 'Google Antigravity';
      case 'vertex':
        return 'Vertex AI';
      case 'xai':
        return 'xAI';
      case 'kimi':
        return 'Kimi';
      default:
        final trimmed = provider.trim();
        return trimmed.isEmpty ? 'OAuth' : trimmed;
    }
  }
}

class _ProviderAccumulator {
  _ProviderAccumulator(this.provider);

  final String provider;
  final Map<String, ModelInfo> models = {};
  final Set<String> excluded = {};

  void addModel(ModelInfo model) {
    if (model.name.isEmpty) return;
    final key = '${model.name}\u0000${model.alias ?? ''}';
    models.putIfAbsent(key, () => model);
  }

  void addExcluded(Object? values) {
    if (values is! List) return;
    for (final value in values) {
      final name = value.toString().trim();
      if (name.isNotEmpty) excluded.add(name);
    }
  }

  ProviderGroup toProviderGroup() {
    final modelList = models.values.toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
    final excludedList = excluded.toList()..sort();
    return ProviderGroup(
      provider: provider,
      models: modelList,
      excludedModels: excludedList,
    );
  }
}

class ProxyApiException implements Exception {
  const ProxyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
