import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:cliproxy_dash/widgets/provider_energy_core.dart';
import 'package:cliproxy_dash/widgets/provider_quota_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _openCodeQuota = ProviderQuota(
  provider: QuotaProviderId.openCode,
  windows: [
    ProviderQuotaWindow(
      label: '5 小时周期',
      remainingPercent: 80,
      resetAt: null,
    ),
    ProviderQuotaWindow(
      label: '本周额度',
      remainingPercent: 60,
      resetAt: null,
    ),
    ProviderQuotaWindow(
      label: '本月额度',
      remainingPercent: 40,
      resetAt: null,
    ),
  ],
);

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 296, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('OpenCode console card uses user-facing quota wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ProviderQuotaCard(
          quota: _openCodeQuota,
          displayName: 'OpenCode Go',
          description: '套餐额度与恢复周期',
          accentColor: AppTheme.magenta,
          icon: Icons.bolt_rounded,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('套餐额度与恢复周期'), findsOneWidget);
    expect(find.text('5 小时周期'), findsOneWidget);
    expect(find.text('本周额度'), findsOneWidget);
    expect(find.text('本月额度'), findsOneWidget);
    expect(find.text('本月可用 40%'), findsOneWidget);
    expect(find.text('月限额'), findsNothing);
    expect(find.text('总额度'), findsNothing);
  });

  testWidgets('provider energy core stacks orb and quota bays on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const ProviderEnergyCore(
          quota: _openCodeQuota,
          displayName: 'OpenCode Go',
          description: '套餐额度与恢复周期',
          accentColor: AppTheme.magenta,
          refreshing: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    final orbRect = tester.getRect(
      find.byKey(const Key('provider-energy-orb')),
    );
    final windowsRect = tester.getRect(
      find.byKey(const Key('provider-energy-windows')),
    );
    expect(orbRect.bottom, lessThanOrEqualTo(windowsRect.top));
    expect(find.text('本月可用'), findsOneWidget);
    expect(find.text('5 小时周期'), findsOneWidget);
    expect(find.text('本周额度'), findsOneWidget);
    expect(find.text('本月额度'), findsOneWidget);
  });
}
