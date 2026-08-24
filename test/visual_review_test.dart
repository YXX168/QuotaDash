@Tags(['golden'])

import 'dart:async';

import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:cliproxy_dash/models/request_bucket.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/screens/account_detail_screen.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReviewRepository implements QuotaRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    checkedAt: DateTime(2026, 7, 19, 10, 28),
    accounts: [
      _account('amy', 'amy***@example.com', 'plus', 82, 61, 128, 2),
      _account('neo', 'neo***@example.com', 'team', 46, 72, 96, 0),
      _account('kai', 'kai***@example.com', 'plus', 18, 35, 62, 8),
    ],
  );

  CodexAccount _account(
    String id,
    String name,
    String plan,
    double primary,
    double secondary,
    int success,
    int failed,
  ) => CodexAccount(
    id: id,
    authIndex: id,
    name: name,
    email: name,
    plan: plan,
    available: true,
    limitReached: false,
    primary: QuotaWindow(
      usedPercent: 100 - primary,
      remainingPercent: primary,
      resetAt: DateTime(2026, 7, 19, 15),
    ),
    secondary: QuotaWindow(
      usedPercent: 100 - secondary,
      remainingPercent: secondary,
      resetAt: DateTime(2026, 7, 26),
    ),
    secondaryLabel: plan == 'team' ? '月度额度' : '周额度',
    resetCredits: 3,
    successRequests: success,
    failedRequests: failed,
    recentRequests: List.generate(
      12,
      (index) => RequestBucket(
        time: _requestWindow(index),
        success: 3 + (index * 7 + id.length) % 11,
        failed: index == 4 || index == 9 ? 2 : 0,
      ),
    ),
  );

  String _requestWindow(int index) {
    String format(int minutes) =>
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';

    final start = 9 * 60 + index * 10;
    return '${format(start)}-${format(start + 10)}';
  }
}

class _PendingRepository implements QuotaRepository {
  final Completer<DashboardSnapshot> _completer = Completer();

  @override
  Future<DashboardSnapshot> fetchDashboard() => _completer.future;
}

Future<void> _render(
  WidgetTester tester,
  VisualMode mode,
  String golden, {
  double scrollOffset = 0,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 960));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: DashboardScreen(
        config: const AppConfig(
          baseUrl: 'https://example.com/v0/management',
          key: 'preview',
        ),
        repository: _ReviewRepository(),
        visualMode: mode,
        onVisualModeChanged: (_) async {},
        onEditConfig: () async {},
        autoRefreshInterval: Duration.zero,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  if (scrollOffset > 0) {
    await tester.drag(
      find.byKey(const Key('dashboard-scroll')),
      Offset(0, -scrollOffset),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await expectLater(
    find.byType(DashboardScreen),
    matchesGoldenFile('goldens/$golden.png'),
  );
}

Future<void> _renderSyncFlow(
  WidgetTester tester,
  VisualMode mode,
  String golden,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 960));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: DashboardScreen(
        config: const AppConfig(
          baseUrl: 'https://example.com/v0/management',
          key: 'preview',
        ),
        repository: _PendingRepository(),
        visualMode: mode,
        onVisualModeChanged: (_) async {},
        onEditConfig: () async {},
        autoRefreshInterval: Duration.zero,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 720));
  await expectLater(
    find.byType(DashboardScreen),
    matchesGoldenFile('goldens/$golden.png'),
  );
}

Future<void> _renderAccountTimeline(WidgetTester tester) async {
  final snapshot = await _ReviewRepository().fetchDashboard();
  await tester.binding.setSurfaceSize(const Size(420, 960));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: AccountDetailScreen(account: snapshot.accounts.first),
    ),
  );
  await tester.pump(const Duration(milliseconds: 850));
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -310));
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(AccountDetailScreen),
    matchesGoldenFile('goldens/account_reset_timeline.png'),
  );
}

void main() {
  testWidgets('matches console dashboard visual baseline', (tester) async {
    await _render(tester, VisualMode.console, 'dashboard_console');
  });

  testWidgets('matches console account-card visual baseline', (tester) async {
    await _render(
      tester,
      VisualMode.console,
      'dashboard_console_accounts',
      scrollOffset: 430,
    );
  });

  testWidgets('matches energy account-card visual baseline', (tester) async {
    await _render(
      tester,
      VisualMode.energy,
      'dashboard_energy_accounts',
      scrollOffset: 430,
    );
  });

  testWidgets('matches console sync-flow visual baseline', (tester) async {
    await _renderSyncFlow(
      tester,
      VisualMode.console,
      'dashboard_console_sync_flow',
    );
    expect(find.byKey(const Key('console-sync-flow')), findsOneWidget);
    expect(find.byKey(const Key('sync-flow-field')), findsOneWidget);
    expect(find.text('正在同步账户状态'), findsOneWidget);
  });

  testWidgets('matches energy sync-flow visual baseline', (tester) async {
    await _renderSyncFlow(
      tester,
      VisualMode.energy,
      'dashboard_energy_sync_flow',
    );
    expect(find.byKey(const Key('energy-sync-flow')), findsOneWidget);
    expect(find.byKey(const Key('sync-flow-field')), findsOneWidget);
    expect(find.text('建立安全连接  ·  聚合账户数据'), findsOneWidget);
  });

  testWidgets('matches account reset-timeline visual baseline', (tester) async {
    await _renderAccountTimeline(tester);
    expect(find.byKey(const Key('quota-reset-timeline')), findsOneWidget);
  });
}
