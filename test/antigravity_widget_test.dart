import 'dart:async';
import 'dart:io';

import 'package:cliproxy_dash/models/antigravity_account.dart';
import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:cliproxy_dash/widgets/antigravity_account_card.dart';
import 'package:cliproxy_dash/widgets/energy_core.dart';
import 'package:cliproxy_dash/widgets/provider_quota_card.dart';
import 'package:cliproxy_dash/widgets/quota_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

AntigravityAccount _account({
  String id = 'test',
  Object? error,
  int count = 4,
}) => AntigravityAccount(
  auth: AuthFileAccount.fromJson({'id': id, 'email': '$id@example.com'}),
  quota: ProviderQuota(
    provider: QuotaProviderId.antigravity,
    error: error,
    windows: error != null
        ? []
        : List.generate(
            count,
            (index) => ProviderQuotaWindow(
              label: [
                'Claude · Weekly',
                'Claude · Session',
                'Gemini Pro · Weekly',
                'Gemini Flash · Session',
              ][index % 4],
              remainingPercent: [42.0, 0.0, 80.0, null][index % 4],
              resetAt: DateTime.utc(2026, 9, 15, 8),
            ),
          ),
  ),
);

Widget _card(
  VisualMode mode, {
  int count = 4,
  bool reduced = false,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.dark.copyWith(
    textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'ReviewFont'),
  ),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AntigravityAccountCard(
            account: _account(count: count),
            visualMode: mode,
            refreshing: false,
          ),
        ),
      ),
    ),
  ),
);

class _Pending implements QuotaRepository {
  final result = Completer<DashboardSnapshot>();
  @override
  Future<DashboardSnapshot> fetchDashboard() => result.future;
}

class _Counting implements QuotaRepository {
  int calls = 0;
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    calls++;
    return DashboardSnapshot(accounts: const [], checkedAt: DateTime.now());
  }
}

Widget _dashboard(
  QuotaRepository repository, {
  Duration interval = Duration.zero,
}) => MaterialApp(
  theme: AppTheme.dark,
  home: DashboardScreen(
    config: const AppConfig(
      values: {
        'baseUrl': 'https://example.com/v0/management',
        'managementKey': 'test',
      },
    ),
    repository: repository,
    visualMode: VisualMode.console,
    onVisualModeChanged: (_) async {},
    onEditConfig: () async {},
    autoRefreshInterval: interval,
  ),
);

void main() {
  testWidgets('cached provider quotas remain visible with a stale warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderQuotaCard(
            quota: const ProviderQuota(
              provider: QuotaProviderId.openCode,
              error: 'Network unavailable',
              windows: [
                ProviderQuotaWindow(label: 'Weekly', remainingPercent: 80),
              ],
            ),
            displayName: 'OpenCode',
            description: 'Quota',
            accentColor: AppTheme.cyan,
            icon: Icons.bolt,
          ),
        ),
      ),
    );
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.text('上次同步的额度 · 数据可能已过期'), findsOneWidget);
    expect(find.text('可用 80%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion settles immediately with nonzero energy', (
    tester,
  ) async {
    await tester.pumpWidget(_card(VisualMode.energy, count: 1, reduced: true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('42%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'automatic refresh pauses in background and resumes in foreground',
    (tester) async {
      final repository = _Counting();
      await tester.pumpWidget(
        _dashboard(repository, interval: const Duration(seconds: 2)),
      );
      await tester.pump();
      final initial = repository.calls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.calls, initial);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      expect(repository.calls, greaterThan(initial));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final mode in VisualMode.values) {
    for (final width in [320.0, 800.0]) {
      testWidgets('${mode.name} handles many quota groups at width $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_card(mode, count: 8));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        if (mode == VisualMode.energy) {
          expect(find.byType(EnergyAccountCore), findsOneWidget);
          expect(
            tester.getSize(find.byKey(const Key('energy-core-card'))).height,
            218,
          );
          await tester.tap(find.byKey(const Key('antigravity-details')));
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text('可用 0%'), findsNWidgets(2));
        expect(find.text('--'), findsNWidgets(2));
        if (mode == VisualMode.energy) {
          expect(find.text('最低余量'), findsOneWidget);
          expect(find.text('综合可用'), findsNothing);
          expect(
            tester.widget<Text>(find.text('可用 80%').first).style!.color,
            AppTheme.cyan,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('${mode.name} supports large text on narrow phones', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_card(mode, scale: 1.5));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('energy animations stop when reduced motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_card(VisualMode.energy, reduced: true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(EnergyAccountCore), findsOneWidget);
    await tester.pumpWidget(_card(VisualMode.energy));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late old repository response cannot replace new account data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final old = _Pending();
    final current = _Pending();
    await tester.pumpWidget(_dashboard(old));
    await tester.pumpWidget(_dashboard(current));
    current.result.complete(
      DashboardSnapshot(
        accounts: [],
        checkedAt: DateTime.now(),
        antigravityAccounts: [_account(id: 'new')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('new***@example.com'), findsOneWidget);
    expect(find.byKey(const Key('codex-section-title')), findsNothing);
    old.result.complete(
      DashboardSnapshot(
        accounts: [],
        checkedAt: DateTime.now(),
        antigravityAccounts: [_account(id: 'old')],
      ),
    );
    await tester.pump();
    expect(find.text('new***@example.com'), findsOneWidget);
    expect(find.text('old***@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quota labels stay truthful while bars animate between updates', (
    tester,
  ) async {
    Widget quota(double remaining) => MaterialApp(
      home: Scaffold(
        body: QuotaProgress(
          label: '周额度',
          window: QuotaWindow(
            usedPercent: 100 - remaining,
            remainingPercent: remaining,
          ),
        ),
      ),
    );
    await tester.pumpWidget(quota(80));
    expect(find.text('80% 剩余'), findsOneWidget);
    await tester.pumpWidget(quota(20));
    expect(find.text('20% 剩余'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, greaterThan(.2));
    expect(bar.widthFactor, lessThan(.8));
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      .2,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in VisualMode.values) {
    testWidgets('review Antigravity ${mode.name}', (tester) async {
      final fontPath = Platform.environment['QUOTA_REVIEW_FONT'];
      if (fontPath != null) {
        final loader = FontLoader('ReviewFont')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(fontPath).readAsBytesSync()),
            ),
          );
        await loader.load();
      }
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot != null) {
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await icons.load();
      }
      await tester.binding.setSurfaceSize(const Size(420, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_card(mode, reduced: true));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          '../build/visual-review/antigravity_${mode.name}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, tags: ['golden']);
  }
}
