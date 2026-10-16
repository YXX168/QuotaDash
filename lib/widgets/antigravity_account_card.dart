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
      final h5Label =
          gemini5H != null &&
              (gemini5H.label.contains('Claude') ||
                  gemini5H.label.contains('GPT'))
          ? 'Claude & GPT · 5H'
          : 'Gemini Models · 5H';
      final h168Label =
          geminiWeekly != null &&
              (geminiWeekly.label.contains('Claude') ||
                  geminiWeekly.label.contains('GPT'))
          ? 'Claude & GPT · 168H'
          : 'Gemini Models · 168H';

      return EnergyAccountCore.forProvider(
        key: const Key('antigravity-details'),
        data: EnergyCoreData(
          name: name,
          badge: 'PRO',
          headline: ProviderQuotaWindow(
            label: '周额度',
            remainingPercent: geminiWeekly?.remainingPercent,
            resetAt: geminiWeekly?.resetAt,
          ),
          windows: [
            ProviderQuotaWindow(
              label: h5Label,
              remainingPercent: gemini5H?.remainingPercent,
              resetAt: gemini5H?.resetAt,
            ),
            ProviderQuotaWindow(
              label: h168Label,
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
