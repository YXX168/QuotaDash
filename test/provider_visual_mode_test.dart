import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:cliproxy_dash/widgets/opencode_compact_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _openCodeQuota = ProviderQuota(
  provider: QuotaProviderId.openCode,
  windows: [
    ProviderQuotaWindow(label: '5 小时周期', remainingPercent: 80),
    ProviderQuotaWindow(label: '周限额度', remainingPercent: 60),
    ProviderQuotaWindow(label: '月限额度', remainingPercent: 40),
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
  testWidgets('OpenCode compact card shows three values and monthly usage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const OpenCodeCompactCard(quota: _openCodeQuota)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('opencode-compact-card')), findsOneWidget);
    expect(find.byKey(const Key('opencode-compact-values')), findsOneWidget);
    expect(find.text('OpenCode Go'), findsOneWidget);
    expect(find.text('5 小时周期'), findsOneWidget);
    expect(find.text('周限额度'), findsOneWidget);
    expect(find.text('月限额度'), findsOneWidget);
    expect(find.text('已用量 60%'), findsOneWidget);
    expect(find.text('套餐额度与恢复周期'), findsNothing);
    expect(find.text('月度周期'), findsNothing);
  });

  testWidgets('OpenCode compact card stays bounded on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(const OpenCodeCompactCard(quota: _openCodeQuota)),
    );

    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byKey(const Key('opencode-compact-card')));
    final values = tester.getRect(
      find.byKey(const Key('opencode-compact-values')),
    );
    expect(card.width, closeTo(296, 0.1));
    expect(card.top, lessThanOrEqualTo(values.top));
    expect(values.bottom, lessThanOrEqualTo(card.bottom));
    expect(card.height, lessThan(150));
  });
}
