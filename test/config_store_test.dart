import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/services/config_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates legacy management config into provider-scoped keys', () async {
    FlutterSecureStorage.setMockInitialValues({
      'management_base_url_secure': 'https://proxy.example/v0/management',
      'management_key': 'test-secret',
    });
    SharedPreferences.setMockInitialValues({});

    final store = PluginConfigStore();
    final config = await store.load();

    expect(config?.value('baseUrl'), 'https://proxy.example/v0/management');
    expect(config?.value('managementKey'), 'test-secret');
  });

  test('saves and reloads multi-provider settings', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final store = PluginConfigStore();
    await store.save(
      const AppConfig(
        values: {
          'baseUrl': 'https://proxy.example/v0/management',
          'managementKey': 'proxy-secret',
          'openCodeApiKey': 'opencode-secret',
        },
      ),
    );

    final loaded = await store.load();
    expect(loaded?.value('baseUrl'), 'https://proxy.example/v0/management');
    expect(loaded?.value('managementKey'), 'proxy-secret');
    expect(loaded?.value('openCodeApiKey'), 'opencode-secret');
  });

  test('returns null when nothing is configured', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final store = PluginConfigStore();
    expect(await store.load(), isNull);
  });

  test('persists settings for an unregistered future provider', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final store = PluginConfigStore();
    await store.save(
      const AppConfig(values: {'futureProviderApiKey': 'future-secret'}),
    );

    expect(
      (await store.load())?.value('futureProviderApiKey'),
      'future-secret',
    );
  });
}
