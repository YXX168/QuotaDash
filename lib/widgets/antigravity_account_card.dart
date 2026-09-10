import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/antigravity_account.dart';
import '../models/provider_quota.dart';
import '../models/visual_mode.dart';
import '../screens/antigravity_detail_screen.dart';
import '../theme/app_theme.dart';
import 'energy_core.dart';
import 'provider_quota_card.dart';

class AntigravityAccountCard extends StatelessWidget {
  const AntigravityAccountCard({
    required this.account,
    required this.visualMode,
    required this.refreshing,
    super.key,
    this.onTap,
  });

  final AntigravityAccount account;
  final VisualMode visualMode;
  final bool refreshing;
  final VoidCallback? onTap;

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      unawaited(HapticFeedback.lightImpact());
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AntigravityDetailScreen(account: account),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = account.auth.name;
    const description = 'Antigravity';
    if (visualMode == VisualMode.energy) {
      final geminiWeekly = account.geminiWeeklyWindow;
      final gemini5H = account.gemini5HWindow;

      return EnergyAccountCore.forProvider(
        key: const Key('antigravity-details'),
        data: EnergyCoreData(
          name: name,
          caption: description,
          badge: 'ANTIGRAVITY',
          headline: ProviderQuotaWindow(
            label: '周额度',
            remainingPercent: geminiWeekly?.remainingPercent,
            resetAt: geminiWeekly?.resetAt,
          ),
          windows: [
            ProviderQuotaWindow(
              label: 'Gemini Models · 5H',
              remainingPercent: gemini5H?.remainingPercent,
              resetAt: gemini5H?.resetAt,
            ),
            ProviderQuotaWindow(
              label: 'Gemini Models · 168H',
              remainingPercent: geminiWeekly?.remainingPercent,
              resetAt: geminiWeekly?.resetAt,
            ),
          ],
          hasError: account.quota.hasError,
        ),
        refreshing: refreshing,
        onTap: () => _handleTap(context),
      );
    }
    return ProviderQuotaCard(
      key: const Key('antigravity-details'),
      quota: account.quota,
      displayName: name,
      description: description,
      accentColor: AppTheme.cyan,
      icon: Icons.auto_awesome_rounded,
      onTap: () => _handleTap(context),
    );
  }
}
