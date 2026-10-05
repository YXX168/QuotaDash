import 'dart:io';

import 'package:cliproxy_dash/models/antigravity_account.dart';
import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/models/request_bucket.dart';
import 'package:cliproxy_dash/models/visual_mode.dart';
import 'package:cliproxy_dash/models/workbuddy_account.dart';
import 'package:cliproxy_dash/screens/dashboard_screen.dart';
import 'package:cliproxy_dash/services/quota_repository.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:cliproxy_dash/widgets/antigravity_account_card.dart';
import 'package:cliproxy_dash/widgets/energy_core.dart';
import 'package:cliproxy_dash/widgets/glass_widgets.dart';
import 'package:cliproxy_dash/widgets/workbuddy_account_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

WorkBuddyAccount fixture({
  bool unknown = false,
  Object? error,
  String id = 'fixture-index',
  String region = 'global',
  double remaining = 375,
  double? total = 500,
}) => WorkBuddyAccount(
  auth: AuthFileAccount(
    id: 'synthetic-workbuddy-$id',
    authIndex: id,
    name: 'Syn***',
    email: '',
    successRequests: 12,
    failedRequests: 1,
    recentRequests: const [
      RequestBucket(time: '10:00-10:10', success: 3, failed: 0),
      RequestBucket(time: '10:10-10:20', success: 5, failed: 1),
    ],
  ),
  nickname: 'Syn***',
  region: region,
  plan: 'pro',
  selected: true,
  error: error,
  credits: unknown
      ? null
      : WorkBuddyCredits(
          totalRemaining: remaining,
          totalUsed: 125,
          totalSize: total,
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

Finder remainingReading(
  VisualMode mode, {
  String remaining = '375',
  String total = '500',
}) {
  if (mode == VisualMode.console) return find.text('剩余 $remaining credits');
  final amount = double.tryParse(remaining);
  final size = double.tryParse(total);
  final text = amount == null || size == null || size <= 0
      ? '--'
      : '${(amount / size * 100).clamp(0, 100).toStringAsFixed(0)}%';
  return find.descendant(
    of: find.byKey(const Key('energy-quota-line-secondary')),
    matching: find.text(text),
  );
}

class _Repository implements QuotaRepository {
  const _Repository(this.accounts, {this.antigravityAccounts = const []});
  final List<WorkBuddyAccount> accounts;
  final List<AntigravityAccount> antigravityAccounts;

  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    accounts: const [],
    workBuddyAccounts: accounts,
    antigravityAccounts: antigravityAccounts,
    checkedAt: DateTime.utc(2026, 10, 3, 1),
  );
}

Future<void> pumpDashboard(
  WidgetTester tester,
  VisualMode mode, {
  List<WorkBuddyAccount>? accounts,
  List<AntigravityAccount> antigravityAccounts = const [],
}) async {
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
          repository: _Repository(
            accounts ?? [fixture()],
            antigravityAccounts: antigravityAccounts,
          ),
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
      theme: AppTheme.dark.copyWith(
        textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'ReviewFont'),
      ),
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
  testWidgets('energy shows used above remaining with actual credit ratios', (
    tester,
  ) async {
    await pumpCard(tester, VisualMode.energy, fixture());
    final used = find.byKey(const Key('energy-quota-track-已用 Credits'));
    final remaining = find.byKey(const Key('energy-quota-track-剩余 Credits'));
    expect(
      tester.getRect(used).bottom,
      lessThan(tester.getRect(remaining).top),
    );
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('国际版'), findsOneWidget);
    expect(find.text('TRIAL'), findsNothing);
    expect(find.byKey(const Key('energy-account-email')), findsNothing);
    expect(remainingReading(VisualMode.energy), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('energy-quota-fill-已用 Credits')))
          .width,
      closeTo(tester.getSize(used).width * .25, .1),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('energy-quota-fill-剩余 Credits')))
          .width,
      closeTo(tester.getSize(remaining).width * .75, .1),
    );
    await pumpCard(tester, VisualMode.energy, fixture(total: null));
    expect(
      find.descendant(
        of: find.byKey(const Key('energy-quota-line-primary')),
        matching: find.text('--'),
      ),
      findsOneWidget,
    );
    expect(remainingReading(VisualMode.energy, total: '--'), findsOneWidget);
    await pumpCard(tester, VisualMode.energy, fixture(region: 'cn'));
    expect(find.text('国内版'), findsOneWidget);
    expect(find.text('国际版'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final mode in VisualMode.values) {
    for (final width in [320.0, 800.0]) {
      testWidgets(
        '${mode.name} shows one card per WorkBuddy account below all Antigravity accounts at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final accounts = [
            fixture(id: 'global'),
            fixture(id: 'cn', region: 'cn', remaining: 125),
          ];
          final antigravityAccounts = List.generate(
            2,
            (index) => AntigravityAccount(
              auth: AuthFileAccount(
                id: 'synthetic-antigravity-$index',
                authIndex: 'antigravity-$index',
                name: 'Antigravity fixture $index',
                email: '',
                successRequests: 0,
                failedRequests: 0,
                recentRequests: const [],
              ),
              quota: const ProviderQuota(
                provider: QuotaProviderId.antigravity,
                windows: [
                  ProviderQuotaWindow(
                    label: 'Gemini Models 周额度',
                    remainingPercent: 80,
                  ),
                ],
              ),
            ),
          );
          await pumpDashboard(
            tester,
            mode,
            accounts: accounts,
            antigravityAccounts: antigravityAccounts,
          );
          expect(find.byType(WorkBuddyAccountCard), findsNWidgets(2));
          expect(find.byType(AntigravityAccountCard), findsNWidgets(2));
          final antigravityTitle = tester.getRect(
            find.byKey(const Key('antigravity-section-title')),
          );
          final workBuddyTitle = tester.getRect(
            find.byKey(const Key('workbuddy-section-title')),
          );
          for (final account in antigravityAccounts) {
            final rect = tester.getRect(
              find.byKey(ValueKey('antigravity-${account.auth.id}')),
            );
            expect(rect.top, greaterThan(antigravityTitle.bottom));
            expect(rect.bottom, lessThan(workBuddyTitle.top));
          }
          for (final account in accounts) {
            final card = find.descendant(
              of: find.byKey(ValueKey('workbuddy-${account.auth.authIndex}')),
              matching: find.byType(WorkBuddyAccountCard),
            );
            expect(card, findsOneWidget);
            expect(
              tester.getRect(card).top,
              greaterThan(workBuddyTitle.bottom),
            );
            expect(
              find.descendant(of: card, matching: find.byType(InkWell)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: card, matching: find.byType(GlassCard)),
              mode == VisualMode.console ? findsOneWidget : findsNothing,
            );
            expect(
              find.descendant(
                of: card,
                matching: find.byType(EnergyAccountCore),
              ),
              mode == VisualMode.energy ? findsOneWidget : findsNothing,
            );
          }
          final cnCard = find.byKey(const ValueKey('workbuddy-cn'));
          await tester.ensureVisible(cnCard);
          await tester.pump(const Duration(milliseconds: 600));
          await tester.tap(
            find.descendant(
              of: cnCard,
              matching: remainingReading(mode, remaining: '125'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('WorkBuddy 账号详情'), findsOneWidget);
          expect(find.text('国内版'), findsOneWidget);
          expect(find.text('剩余 125 credits'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

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
        expect(find.byType(WorkBuddyAccountCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(WorkBuddyAccountCard),
            matching: find.byType(InkWell),
          ),
          findsOneWidget,
        );
        expect(remainingReading(mode), findsOneWidget);
        expect(
          find.textContaining('当前账号'),
          mode == VisualMode.console ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('查看积分包与到期时间'),
          mode == VisualMode.console ? findsOneWidget : findsNothing,
        );
        expect(find.text('已用 125 credits'), findsNothing);
        expect(find.textContaining('积分包 1'), findsNothing);
        expect(find.textContaining('查询时间：'), findsNothing);
        expect(find.textContaining('到期：'), findsNothing);
        expect(find.textContaining('重置'), findsNothing);
        await tester.tap(remainingReading(mode));
        await tester.pumpAndSettle();
        expect(find.text('WorkBuddy 账号详情'), findsOneWidget);
        expect(find.text('当前账号'), findsOneWidget);
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
      expect(
        remainingReading(mode, remaining: '--', total: '--'),
        findsOneWidget,
      );
      expect(
        find.textContaining('积分余量未知'),
        mode == VisualMode.console ? findsOneWidget : findsNothing,
      );
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
      expect(
        mode == VisualMode.console
            ? find.text('操作失败，请检查连接或配置后重试')
            : find.text('检查失败'),
        findsOneWidget,
      );
      await pumpCard(tester, mode, fixture(error: Exception('private')));
      expect(
        mode == VisualMode.console
            ? find.text('上次查询的积分 · 数据可能已过期')
            : find.text('检查失败'),
        findsOneWidget,
      );
      expect(remainingReading(mode), findsOneWidget);
      expect(find.text('private'), findsNothing);
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
        expect(find.text('积分包 8'), findsNothing);
        expect(
          mode == VisualMode.energy
              ? remainingReading(mode, remaining: '--', total: '--')
              : remainingReading(mode),
          findsOneWidget,
        );
        expect(
          find.textContaining('Synthetic long credit package'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (mode == VisualMode.energy) {
          final orb = tester.getRect(find.byKey(const Key('energy-orb')));
          final bar = tester.getRect(
            find.byKey(const Key('energy-quota-track-剩余 Credits')),
          );
          expect(orb.right, lessThanOrEqualTo(bar.left));
          expect(bar.top, greaterThanOrEqualTo(orb.top));
          expect(bar.bottom, lessThanOrEqualTo(orb.bottom));
          expect(find.byType(GlassCard), findsNothing);
          expect(find.byType(EnergyAccountCore), findsOneWidget);
          expect(
            tester.getSize(find.byKey(const Key('energy-core-card'))).height,
            lessThan(180),
          );
        }
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
      await tester.tap(remainingReading(mode));
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
