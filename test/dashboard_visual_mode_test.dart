import 'dart:io';

import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/provider_field.dart';
import 'package:cliproxy_dash/services/provider_registry.dart';
import 'package:cliproxy_dash/services/quota_module.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:cliproxy_dash/widgets/energy_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRepository implements QuotaRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    checkedAt: DateTime(2026, 7, 17),
    accounts: [
      CodexAccount(
        id: 'account-1',
        authIndex: '1',
        name: 'test***@example.com',
        email: 'test***@example.com',
        plan: 'plus',
        available: true,
        limitReached: false,
        primary: QuotaWindow(
          usedPercent: 20,
          remainingPercent: 80,
          resetAt: DateTime(2026, 7, 24),
          limitWindowSeconds: 604800,
        ),
        secondary: null,
        secondaryLabel: '周额度',
        resetCredits: 3,
        successRequests: 10,
        failedRequests: 1,
      ),
    ],
  );
}

QuotaModule _createFixedOpenCode(
  AppConfig config, {
  QuotaRepository? cliProxyRepository,
}) => const _FixedOpenCodeModule();

class _FixedOpenCodeModule implements QuotaModule<ProviderModuleResult> {
  const _FixedOpenCodeModule();

  @override
  Color get accentColor => Colors.pinkAccent;

  @override
  String get description => '';

  @override
  String get displayName => 'OpenCode';

  @override
  List<ProviderField> get fields => const [];

  @override
  IconData get icon => Icons.bolt_rounded;

  @override
  QuotaProviderId get id => QuotaProviderId.openCode;

  @override
  bool isEnabled(AppConfig config) => true;

  @override
  Future<ProviderModuleResult> fetch(AppConfig config) async {
    return const ProviderModuleResult(
      ProviderQuota(
        provider: QuotaProviderId.openCode,
        windows: [
          ProviderQuotaWindow(label: '5 小时额度', remainingPercent: 80),
          ProviderQuotaWindow(label: '周限额度', remainingPercent: 60),
          ProviderQuotaWindow(label: '月限额度', remainingPercent: 40),
        ],
      ),
    );
  }
}

final _testRegistry = ProviderRegistry(
  factories: [ProviderRegistry.defaultFactories.first, _createFixedOpenCode],
);

Future<void> _pumpDashboard(WidgetTester tester, VisualMode mode) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: DashboardScreen(
        config: const AppConfig(
          values: {
            'baseUrl': 'https://example.com/v0/management',
            'managementKey': 'test-key',
          },
        ),
        repository: _FixedRepository(),
        visualMode: mode,
        onVisualModeChanged: (_) async {},
        onEditConfig: () async {},
        autoRefreshInterval: Duration.zero,
        registry: _testRegistry,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final mode in VisualMode.values) {
    testWidgets('review compact ChatGPT ${mode.name}', (tester) async {
      final font = Platform.environment['QUOTA_REVIEW_FONT'];
      if (font != null) {
        final loader = FontLoader('sans-serif')
          ..addFont(
            Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
          );
        await loader.load();
      }
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root != null) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
      }
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpDashboard(tester, mode);
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile('../build/visual-review/chatgpt-${mode.name}.png'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, tags: ['golden']);
  }
  testWidgets('console mode renders account cards without redundant summary', (
    tester,
  ) async {
    await _pumpDashboard(tester, VisualMode.console);

    expect(find.byKey(const Key('summary-stats-grid')), findsNothing);
    expect(find.text('API 在线'), findsNothing);
    expect(find.text('缓存数据'), findsNothing);
    expect(find.text('Codex 降智测试'), findsNothing);
    expect(find.byKey(const Key('account-card-0')), findsOneWidget);
    expect(find.byKey(const Key('energy-account-0')), findsNothing);
    expect(find.byKey(const Key('opencode-compact-card')), findsOneWidget);
    expect(find.text('OpenCode'), findsOneWidget);
    expect(find.text('1 个账号'), findsNothing);
    expect(find.text('周均额度'), findsNothing);
    expect(find.text('平均剩余'), findsNothing);
    expect(find.byKey(const Key('quota-card-openCode')), findsNothing);
    expect(find.byKey(const Key('provider-energy-openCode')), findsNothing);
  });

  testWidgets('energy mode renders one energy core per account', (
    tester,
  ) async {
    await _pumpDashboard(tester, VisualMode.energy);

    expect(find.byKey(const Key('summary-stats-grid')), findsNothing);
    expect(find.text('API 在线'), findsNothing);
    expect(find.text('缓存数据'), findsNothing);
    expect(find.text('Codex 降智测试'), findsNothing);
    expect(find.byKey(const Key('account-card-0')), findsNothing);
    expect(find.byKey(const Key('energy-account-0')), findsOneWidget);
    expect(find.byKey(const Key('opencode-compact-card')), findsOneWidget);
    expect(find.byKey(const Key('quota-card-openCode')), findsNothing);
    expect(find.byKey(const Key('provider-energy-openCode')), findsNothing);
    final pulse = tester.getRect(find.byKey(const Key('request-pulse-card')));
    final openCodeTitle = tester.getRect(
      find.byKey(const Key('opencode-section-title')),
    );
    final openCodeCard = tester.getRect(
      find.byKey(const Key('opencode-compact-card')),
    );
    final codexTitle = tester.getRect(
      find.byKey(const Key('codex-section-title')),
    );
    expect(pulse.bottom, lessThan(openCodeTitle.top));
    expect(openCodeTitle.bottom, lessThan(openCodeCard.top));
    expect(openCodeCard.bottom, lessThan(codexTitle.top));
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-account-0')),
        matching: find.text('80%'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-account-0')),
        matching: find.byKey(const Key('energy-orb')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-account-0')),
        matching: find.byKey(const Key('energy-foreground')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-account-0')),
        matching: find.byKey(const Key('energy-quota-line-primary')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-account-0')),
        matching: find.byKey(const Key('energy-quota-line-secondary')),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'energy core stays bounded with two quota windows on a narrow card',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 296,
              child: EnergyAccountCore(
                account: CodexAccount(
                  id: 'narrow-account',
                  authIndex: '1',
                  name: 'very-long-account-name@example.com',
                  email: 'very-long-account-name@example.com',
                  plan: 'team',
                  available: true,
                  limitReached: false,
                  primary: QuotaWindow(
                    usedPercent: 20,
                    remainingPercent: 80,
                    limitWindowSeconds: 604800,
                  ),
                  secondary: QuotaWindow(
                    usedPercent: 40,
                    remainingPercent: 60,
                    limitWindowSeconds: 2592000,
                  ),
                  secondaryLabel: '月度额度',
                  resetCredits: 0,
                  successRequests: 0,
                  failedRequests: 0,
                ),
                refreshing: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      final orbRect = tester.getRect(find.byKey(const Key('energy-orb')));
      final headerRect = tester.getRect(find.byKey(const Key('energy-header')));
      final quotaRect = tester.getRect(
        find.byKey(const Key('energy-quota-row')),
      );
      expect((headerRect.top - orbRect.top).abs(), lessThanOrEqualTo(0.1));
      expect(quotaRect.top, greaterThanOrEqualTo(headerRect.bottom));
      expect(orbRect.right, lessThanOrEqualTo(quotaRect.left));
      final cardRect = tester.getRect(
        find.byKey(const Key('energy-core-card')),
      );
      final lastTrack = tester.getRect(
        find.byKey(const Key('energy-quota-track-月度额度')),
      );
      expect(
        headerRect.top - cardRect.top,
        closeTo(cardRect.bottom - lastTrack.bottom, 0.1),
      );
      expect(
        tester.getSize(find.byKey(const Key('energy-core-card'))).height,
        closeTo(130, 0.1),
      );
      expect(find.byKey(const Key('energy-orb')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('energy-orb')),
          matching: find.text('80%'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('energy-orb')),
          matching: find.text('周额度'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('energy-quota-line-primary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('energy-quota-line-secondary')),
        findsOneWidget,
      );
      final weeklyTrack = tester.getSize(
        find.byKey(const Key('energy-quota-track-周额度')),
      );
      final weeklyFill = tester.getSize(
        find.byKey(const Key('energy-quota-fill-周额度')),
      );
      final monthlyTrack = tester.getSize(
        find.byKey(const Key('energy-quota-track-月度额度')),
      );
      final monthlyFill = tester.getSize(
        find.byKey(const Key('energy-quota-fill-月度额度')),
      );
      expect(weeklyFill.width, closeTo(weeklyTrack.width * 0.8, 0.1));
      expect(monthlyFill.width, closeTo(monthlyTrack.width * 0.6, 0.1));
      expect(
        find.descendant(
          of: find.byKey(const Key('energy-header')),
          matching: find.text('very-long-account-name@example.com'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('energy-account-email')), findsNothing);
    },
  );

  testWidgets('labels a single current quota window as weekly', (tester) async {
    await _pumpDashboard(tester, VisualMode.console);

    await tester.tap(find.byKey(const Key('account-card-0')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('周额度'), findsWidgets);
    expect(find.text('5 小时限额'), findsNothing);
  });

  testWidgets('settings opens the redesigned control center', (tester) async {
    await _pumpDashboard(tester, VisualMode.console);

    await tester.tap(find.byKey(const Key('dashboard-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('控制中心'), findsOneWidget);
    expect(find.text('显示模式'), findsOneWidget);
    expect(find.text('深海控制台'), findsOneWidget);
    expect(find.text('能量核心'), findsOneWidget);
    expect(find.text('自动刷新'), findsOneWidget);
    expect(find.text('连接配置'), findsOneWidget);
    await tester.ensureVisible(find.text('工具箱'));
    await tester.tap(find.text('工具箱'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PROXY MANAGEMENT TOOLS'), findsOneWidget);
    expect(find.text('账号管理'), findsOneWidget);
    expect(find.text('Codex 降智测试'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
