import 'package:flutter/material.dart';

import '../models/antigravity_account.dart';
import '../models/provider_quota.dart';
import '../models/visual_mode.dart';
import '../theme/app_theme.dart';
import 'provider_energy_core.dart';
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
    const description = 'Antigravity · 各额度组独立计算';
    if (visualMode == VisualMode.energy) {
      return ProviderEnergyCore(
        quota: account.quota,
        displayName: name,
        description: description,
        accentColor: AppTheme.cyan,
        refreshing: refreshing,
        headline: ProviderQuotaWindow(
          label: '最低余量',
          remainingPercent: account.lowestWindow?.remainingPercent,
        ),
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
