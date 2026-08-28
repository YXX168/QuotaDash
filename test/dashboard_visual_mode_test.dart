import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:cliproxy_dash/widgets/energy_core.dart';
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
      final emailRect = tester.getRect(
        find.byKey(const Key('energy-account-email')),
      );
      expect(headerRect.bottom, lessThanOrEqualTo(orbRect.top));
      expect(orbRect.bottom, lessThanOrEqualTo(quotaRect.top));
      expect(quotaRect.bottom, lessThanOrEqualTo(emailRect.top));
      expect(
        tester.getSize(find.byType(EnergyAccountCore)).height,
        closeTo(226, 0.1),
      );
      expect(find.byKey(const Key('energy-orb')), findsOneWidget);
      expect(
        find.byKey(const Key('energy-quota-line-primary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('energy-quota-line-secondary')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'very-long-account-name@example.com' &&
              widget.maxLines == 1,
        ),
        findsNWidgets(2),
      );
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
  });
}
