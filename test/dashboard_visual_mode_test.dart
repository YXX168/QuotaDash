import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:flutter/material.dart';
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

Future<void> _pumpDashboard(WidgetTester tester, VisualMode mode) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DashboardScreen(
        config: const AppConfig(
          baseUrl: 'https://example.com/v0/management',
          key: 'test-key',
        ),
        repository: _FixedRepository(),
        visualMode: mode,
        onVisualModeChanged: (_) async {},
        onEditConfig: () async {},
        autoRefreshInterval: Duration.zero,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('console mode renders account cards and keeps summary stats', (
    tester,
  ) async {
    await _pumpDashboard(tester, VisualMode.console);

    expect(find.byKey(const Key('summary-stats-grid')), findsOneWidget);
    expect(find.byKey(const Key('account-card-0')), findsOneWidget);
    expect(find.byKey(const Key('energy-account-0')), findsNothing);
  });

  testWidgets('energy mode renders one energy core per account', (
    tester,
  ) async {
    await _pumpDashboard(tester, VisualMode.energy);

    expect(find.byKey(const Key('summary-stats-grid')), findsOneWidget);
    expect(find.byKey(const Key('account-card-0')), findsNothing);
    expect(find.byKey(const Key('energy-account-0')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-account-0')),
        matching: find.text('80%'),
      ),
      findsNWidgets(3),
    );
  });

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
  });
}
