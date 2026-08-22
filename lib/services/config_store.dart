import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';

abstract interface class ConfigStore {
  Future<AppConfig?> load();
  Future<void> save(AppConfig config);
}

class PluginConfigStore implements ConfigStore {
  PluginConfigStore({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  static const _baseUrlKey = 'management_base_url';
  static const _secureBaseUrlKey = 'management_base_url_secure';
  static const _managementKey = 'management_key';
  static const _opencodeKey = 'opencode_api_key';

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _preferencesFactory;

  @override
  Future<AppConfig?> load() async {
    final preferences = await _preferencesFactory();
    final key = await _secureStorage.read(key: _managementKey);
    var baseUrl =
        (await _secureStorage.read(key: _secureBaseUrlKey))?.trim() ?? '';
    if (baseUrl.isEmpty) {
      baseUrl = preferences.getString(_baseUrlKey)?.trim() ?? '';
      if (baseUrl.isNotEmpty) {
        await _secureStorage.write(key: _secureBaseUrlKey, value: baseUrl);
        await preferences.remove(_baseUrlKey);
      }
    }
    if (key == null || key.trim().isEmpty || baseUrl.isEmpty) return null;
    final opencodeKey =
        (await _secureStorage.read(key: _opencodeKey))?.trim() ?? '';
    return AppConfig(baseUrl: baseUrl, key: key, opencodeKey: opencodeKey);
  }

  @override
  Future<void> save(AppConfig config) async {
    final preferences = await _preferencesFactory();
    await _secureStorage.write(key: _secureBaseUrlKey, value: config.baseUrl);
    await _secureStorage.write(key: _managementKey, value: config.key);
    if (config.opencodeKey.trim().isNotEmpty) {
      await _secureStorage.write(
        key: _opencodeKey,
        value: config.opencodeKey.trim(),
      );
    }
    await preferences.remove(_baseUrlKey);
  }
}
