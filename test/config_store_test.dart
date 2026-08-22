import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/services/config_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates a legacy management address into secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({
      'management_key': 'test-secret',
    });
    SharedPreferences.setMockInitialValues({
      'management_base_url': 'https://proxy.example/v0/management',
    });

    final store = PluginConfigStore();
    final config = await store.load();

    expect(config?.baseUrl, 'https://proxy.example/v0/management');
    const secureStorage = FlutterSecureStorage();
    expect(
      await secureStorage.read(key: 'management_base_url_secure'),
      'https://proxy.example/v0/management',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('management_base_url'), isFalse);
  });

  test('saves both management fields only in secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final store = PluginConfigStore();
    await store.save(
      const AppConfig(
        baseUrl: 'https://proxy.example/v0/management',
        key: 'test-secret',
        opencodeKey: 'opencode-secret',
      ),
    );

    const secureStorage = FlutterSecureStorage();
    expect(
      await secureStorage.read(key: 'management_base_url_secure'),
      'https://proxy.example/v0/management',
    );
    expect(await secureStorage.read(key: 'management_key'), 'test-secret');
    expect(
      await secureStorage.read(key: 'opencode_api_key'),
      'opencode-secret',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('management_base_url'), isFalse);
  });

  test('loads saved opencode key alongside management config', () async {
    FlutterSecureStorage.setMockInitialValues({
      'management_base_url_secure': 'https://proxy.example/v0/management',
      'management_key': 'test-secret',
      'opencode_api_key': 'opencode-secret',
    });
    SharedPreferences.setMockInitialValues({});

    final store = PluginConfigStore();
    final config = await store.load();

    expect(config?.baseUrl, 'https://proxy.example/v0/management');
    expect(config?.key, 'test-secret');
    expect(config?.opencodeKey, 'opencode-secret');
  });
}
