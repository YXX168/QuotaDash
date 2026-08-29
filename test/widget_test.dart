import 'package:cliproxy_dash/app.dart';
import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/services/config_store.dart';
import 'package:cliproxy_dash/services/visual_mode_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryVisualModeStore implements VisualModeStore {
  VisualMode value = VisualMode.console;

  @override
  Future<VisualMode> load() async => value;

  @override
  Future<void> save(VisualMode mode) async => value = mode;
}

class _MemoryConfigStore implements ConfigStore {
  AppConfig? value;

  @override
  Future<AppConfig?> load() async => value;

  @override
  Future<void> save(AppConfig config) async => value = config;
}

void main() {
  testWidgets('shows secure connection setup on first launch', (tester) async {
    await tester.pumpWidget(
      CliProxyDashApp(
        configStore: _MemoryConfigStore(),
        visualModeStore: _MemoryVisualModeStore(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('连接配置'), findsOneWidget);
    expect(find.byKey(const Key('save-config-button')), findsOneWidget);
    expect(find.text('服务地址'), findsOneWidget);
    expect(find.text('API Key（可选）'), findsOneWidget);
    expect(find.textContaining('按供应商分别填入'), findsNothing);
    expect(find.textContaining('仅保存在设备安全存储'), findsNothing);
    expect(find.text('套餐额度与恢复周期'), findsNothing);
  });
}
