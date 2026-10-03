import 'dart:io';

import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/request_bucket.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/models/workbuddy_account.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:cliproxy_dash/widgets/workbuddy_account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

WorkBuddyAccount fixture({bool unknown = false, Object? error}) =>
    WorkBuddyAccount(
      auth: const AuthFileAccount(
        id: 'synthetic-workbuddy',
        authIndex: 'fixture-index',
        name: 'Syn***',
        email: '',
        successRequests: 12,
        failedRequests: 1,
        recentRequests: [
          RequestBucket(time: '10:00-10:10', success: 3, failed: 0),
          RequestBucket(time: '10:10-10:20', success: 5, failed: 1),
        ],
      ),
      nickname: 'Syn***',
      region: 'global',
      plan: 'pro',
      selected: true,
      error: error,
      credits: unknown
          ? null
          : WorkBuddyCredits(
              totalRemaining: 375,
              totalUsed: 125,
              totalSize: 500,
              packageCount: 1,
              fetchedAt: DateTime.utc(2026, 10, 3, 1),
              packages: [
                WorkBuddyPackage(
                  name: 'Synthetic credit package',
                  remaining: 375,
                  used: 125,
                  size: 500,
                  cycleStart: DateTime.utc(2026, 10, 1),
                  cycleEnd: DateTime.utc(2026, 10, 31),
                ),
              ],
            ),
    );

class _Repository implements QuotaRepository {
  const _Repository(this.account);
  final WorkBuddyAccount account;

  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    accounts: const [],
    workBuddyAccounts: [account],
    checkedAt: DateTime.utc(2026, 10, 3, 1),
  );
}

Future<void> pumpDashboard(WidgetTester tester, VisualMode mode) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark.copyWith(
        textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'ReviewFont'),
      ),
      home: RepaintBoundary(
        key: const Key('workbuddy-review'),
        child: DashboardScreen(
          config: const AppConfig(
            values: {
              'baseUrl': 'https://proxy.example.invalid/v8/management',
              'managementKey': 'fixture-key',
            },
          ),
          repository: _Repository(fixture()),
          onEditConfig: () async {},
          visualMode: mode,
          onVisualModeChanged: (_) async {},
          autoRefreshInterval: Duration.zero,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> pumpCard(
  WidgetTester tester,
  VisualMode mode,
  WorkBuddyAccount account, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: WorkBuddyAccountCard(
              account: account,
              visualMode: mode,
              refreshing: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final mode in VisualMode.values) {
    testWidgets(
      '${mode.name} WorkBuddy-only dashboard and detail retain credit semantics',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpDashboard(tester, mode);
        expect(
          find.byKey(const Key('workbuddy-section-title')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('codex-section-title')), findsNothing);
        expect(find.byKey(const Key('request-pulse-card')), findsOneWidget);
        expect(find.text('剩余 375 credits'), findsOneWidget);
        expect(find.text('当前账号'), findsOneWidget);
        expect(find.text('查看积分包与到期时间'), findsOneWidget);
        expect(find.textContaining('到期：'), findsNothing);
        expect(find.textContaining('重置'), findsNothing);
        await tester.tap(find.text('剩余 375 credits'));
        await tester.pumpAndSettle();
        expect(find.text('WorkBuddy 账号详情'), findsOneWidget);
        expect(find.text('Synthetic credit package'), findsOneWidget);
        expect(find.textContaining('到期：'), findsOneWidget);
        expect(find.text('成功 12 · 失败 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${mode.name} unknown credits and errors never imply zero', (
      tester,
    ) async {
      await pumpCard(tester, mode, fixture(unknown: true));
      expect(find.text('剩余 -- credits'), findsOneWidget);
      expect(find.text('积分余量未知'), findsOneWidget);
      expect(find.text('剩余 0 credits'), findsNothing);
      await pumpCard(
        tester,
        mode,
        fixture(
          unknown: true,
          error: Exception('synthetic-private-diagnostic'),
        ),
      );
      expect(find.textContaining('synthetic-private-diagnostic'), findsNothing);
      expect(find.text('操作失败，请检查连接或配置后重试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${mode.name} narrow card supports large text and many packages',
      (tester) async {
        final base = fixture();
        final account = WorkBuddyAccount(
          auth: base.auth,
          region: 'cn',
          disabled: true,
          exhausted: true,
          credits: WorkBuddyCredits(
            totalRemaining: 375,
            totalUsed: 125,
            totalSize: 500,
            packageCount: 8,
            packages: List.generate(
              8,
              (index) => WorkBuddyPackage(
                name: 'Synthetic long credit package $index',
                remaining: 0,
                used: 100,
                size: 100,
              ),
            ),
          ),
        );
        await pumpCard(tester, mode, account, width: 320, textScale: 1.5);
        expect(find.text('已禁用'), findsWidgets);
        expect(find.text('积分包 8'), findsOneWidget);
        expect(
          find.textContaining('Synthetic long credit package'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders synthetic WorkBuddy ${mode.name} review', (
      tester,
    ) async {
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
        final loader = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
      }
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpDashboard(tester, mode);
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(DashboardScreen),
        matchesGoldenFile('../build/visual-review/workbuddy_${mode.name}.png'),
      );
      await tester.tap(find.text('剩余 375 credits'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          '../build/visual-review/workbuddy_${mode.name}_detail.png',
        ),
      );
      expect(tester.takeException(), isNull);
    }, tags: ['golden']);
  }
}
