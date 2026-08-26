import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';
import 'provider_registry_keys.dart';

abstract interface class ConfigStore {
  Future<AppConfig?> load();
  Future<void> save(AppConfig config);
}

/// Secure key/value store for every provider module's settings.
///
/// Legacy single-provider keys (management_base_url, management_key,
/// opencode_api_key) are migrated transparently on first load.
class PluginConfigStore implements ConfigStore {
  PluginConfigStore({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  // Legacy keys (pre multi-provider).
  static const _legacyBaseUrlKey = 'management_base_url';
  static const _legacySecureBaseUrlKey = 'management_base_url_secure';
  static const _legacyManagementKey = 'management_key';
  static const _legacyOpencodeKey = 'opencode_api_key';
  static const _configBlobKey = 'provider_config_v1';

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _preferencesFactory;

  @override
  Future<AppConfig?> load() async {
    final preferences = await _preferencesFactory();

    // ---- Legacy migration -------------------------------------------
    var legacyBaseUrl =
        (await _secureStorage.read(key: _legacySecureBaseUrlKey))?.trim() ?? '';
    if (legacyBaseUrl.isEmpty) {
      legacyBaseUrl = preferences.getString(_legacyBaseUrlKey)?.trim() ?? '';
      if (legacyBaseUrl.isNotEmpty) {
        await _secureStorage.write(
          key: _legacySecureBaseUrlKey,
          value: legacyBaseUrl,
        );
        await preferences.remove(_legacyBaseUrlKey);
      }
    }
    final legacyKey = await _secureStorage.read(key: _legacyManagementKey);
    final legacyOpencode = await _secureStorage.read(key: _legacyOpencodeKey);

    // The blob keeps the store extensible when a new provider adds fields.
    final values = <String, String>{};
    final blob = await _secureStorage.read(key: _configBlobKey);
    if (blob != null && blob.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(blob);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString().trim();
            final value = entry.value?.toString().trim() ?? '';
            if (key.isNotEmpty && value.isNotEmpty) values[key] = value;
          }
        }
      } on FormatException {
        // Recover known values from their dedicated slots below.
      }
    }

    // Dedicated slots remain for downgrade compatibility and override the
    // blob when both representations exist.
    for (final entry in providerConfigKeys.entries) {
      final raw = await _secureStorage.read(key: entry.value);
      if (raw != null && raw.trim().isNotEmpty) {
        values[entry.key] = raw.trim();
      }
    }

    // Map legacy values into the new module-owned keys.
    if (values['baseUrl'] == null && legacyBaseUrl.isNotEmpty) {
      values['baseUrl'] = legacyBaseUrl;
    }
    if (values['managementKey'] == null &&
        legacyKey != null &&
        legacyKey.trim().isNotEmpty) {
      values['managementKey'] = legacyKey.trim();
    }
    if (values['openCodeApiKey'] == null &&
        legacyOpencode != null &&
        legacyOpencode.trim().isNotEmpty) {
      values['openCodeApiKey'] = legacyOpencode.trim();
    }

    if (values.isEmpty) return null;
    return AppConfig(values: values);
  }

  @override
  Future<void> save(AppConfig config) async {
    final preferences = await _preferencesFactory();
    await preferences.remove(_legacyBaseUrlKey);
    if (config.values.isEmpty) {
      await _secureStorage.delete(key: _configBlobKey);
    } else {
      await _secureStorage.write(
        key: _configBlobKey,
        value: jsonEncode(config.values),
      );
    }

    for (final entry in providerConfigKeys.entries) {
      final value = config.value(entry.key);
      if (value.isEmpty) {
        await _secureStorage.delete(key: entry.value);
      } else {
        await _secureStorage.write(key: entry.value, value: value);
      }
    }

    // Keep legacy secure-storage slots in sync so a downgrade does not
    // lose the CLIProxyAPI connection silently.
    final baseUrl = config.value('baseUrl');
    final managementKey = config.value('managementKey');
    if (baseUrl.isNotEmpty) {
      await _secureStorage.write(key: _legacySecureBaseUrlKey, value: baseUrl);
    } else {
      await _secureStorage.delete(key: _legacySecureBaseUrlKey);
    }
    if (managementKey.isNotEmpty) {
      await _secureStorage.write(
        key: _legacyManagementKey,
        value: managementKey,
      );
    } else {
      await _secureStorage.delete(key: _legacyManagementKey);
    }
    await _secureStorage.delete(key: _legacyOpencodeKey);
  }
}
