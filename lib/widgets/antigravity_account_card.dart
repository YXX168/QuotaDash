import 'package:flutter/material.dart';

import '../models/antigravity_account.dart';
import '../models/provider_quota.dart';
import '../models/visual_mode.dart';
import '../theme/app_theme.dart';
import 'energy_core.dart';
import 'provider_quota_card.dart';

class AntigravityAccountCard extends StatelessWidget {
  const AntigravityAccountCard({
    required this.account,
    required this.visualMode,
    required this.refreshing,
    super.key,
  });

  final AntigravityAccount account;
  final VisualMode visualMode;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final name = account.auth.name;
    final windows = account.quota.windows;
    final unknown = windows.where((w) => w.remainingPercent == null).length;
    final description = windows.isEmpty
        ? 'Antigravity · 各额度组独立计算'
        : 'Antigravity · ${windows.length} 个额度窗口'
              '${unknown == 0 ? '' : ' · $unknown 个待同步'}';
    if (visualMode == VisualMode.energy) {
      final ranked = windows.toList()
        ..sort((a, b) => (a.remainingPercent ?? 101).compareTo(
          b.remainingPercent ?? 101,
        ));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnergyAccountCore.forProvider(
            data: EnergyCoreData(
              name: name,
              caption: description,
              badge: 'ANTIGRAVITY',
              headline: ProviderQuotaWindow(
                label: '最低余量',
                remainingPercent: account.lowestWindow?.remainingPercent,
              ),
              windows: ranked.take(2).toList(),
              hasError: account.quota.hasError,
            ),
            refreshing: refreshing,
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('antigravity-details'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              title: Text(
                account.quota.hasError ? '同步失败 · 查看详情' : '全部额度与恢复时间',
                style: const TextStyle(fontSize: 11),
              ),
              children: [
                ProviderQuotaCard(
                  quota: account.quota,
                  displayName: name,
                  description: description,
                  accentColor: AppTheme.cyan,
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ProviderQuotaCard(
      quota: account.quota,
      displayName: name,
      description: description,
      accentColor: AppTheme.cyan,
      icon: Icons.auto_awesome_rounded,
    );
  }
}
