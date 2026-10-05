import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../models/visual_mode.dart';
import '../models/workbuddy_account.dart';
import '../screens/workbuddy_detail_screen.dart';
import '../services/private_http.dart';
import '../theme/app_theme.dart';
import 'energy_core.dart';
import 'glass_widgets.dart';
import 'workbuddy_credits_view.dart';

class WorkBuddyAccountCard extends StatelessWidget {
  const WorkBuddyAccountCard({
    required this.account,
    required this.visualMode,
    required this.refreshing,
    super.key,
    this.onTap,
  });

  final WorkBuddyAccount account;
  final VisualMode visualMode;
  final bool refreshing;
  final VoidCallback? onTap;

  void _open(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkBuddyDetailScreen(account: account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credits = account.credits;
    if (visualMode == VisualMode.energy) {
      return EnergyAccountCore.forProvider(
        key: ValueKey('workbuddy-energy-${account.auth.authIndex}'),
        data: EnergyCoreData(
          name: account.displayName,
          badge: account.regionLabel,
          headline: ProviderQuotaWindow(
            label: account.disabled ? '已禁用' : '积分余量',
            remainingPercent: account.disabled
                ? null
                : credits?.remainingPercent,
          ),
          windows: [
            ProviderQuotaWindow(
              label: '已用 Credits',
              higherIsBetter: false,
              remainingPercent:
                  account.disabled ||
                      credits?.totalUsed == null ||
                      credits?.totalSize == null ||
                      credits!.totalSize! <= 0
                  ? null
                  : (credits.totalUsed! / credits.totalSize! * 100).clamp(
                      0.0,
                      100.0,
                    ),
            ),
            ProviderQuotaWindow(
              label: '剩余 Credits',
              remainingPercent: account.disabled
                  ? null
                  : credits?.remainingPercent,
            ),
          ],
          hasError: account.error != null && !account.disabled,
        ),
        refreshing: refreshing,
        onTap: () => _open(context),
      );
    }
    return GlassCard(
      onTap: () => _open(context),
      borderColor: AppTheme.cyan.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(label: account.regionLabel, color: AppTheme.cyan),
              if (account.plan.isNotEmpty)
                StatusPill(label: account.plan, color: AppTheme.cyan),
              if (account.disabled)
                const StatusPill(label: '已禁用', color: Color(0xFF75829B))
              else if (account.exhausted == true)
                const StatusPill(label: '积分耗尽', color: AppTheme.warning),
              if (account.selected)
                const StatusPill(label: '当前账号', color: AppTheme.success),
            ],
          ),
          const SizedBox(height: 14),
          if (account.error != null && !account.disabled) ...[
            Text(
              safeErrorMessage(account.error),
              style: const TextStyle(color: AppTheme.warning),
            ),
            const SizedBox(height: 10),
            if (credits != null) ...[
              const Text('上次查询的积分 · 数据可能已过期'),
              const SizedBox(height: 10),
            ],
          ],
          Text(
            '剩余 ${formatWorkBuddyCredits(credits?.totalRemaining)} credits',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: account.disabled ? const Color(0xFF75829B) : AppTheme.cyan,
            ),
          ),
          const SizedBox(height: 8),
          Text('总量 ${formatWorkBuddyCredits(credits?.totalSize)} credits'),
          if (credits == null) ...[
            const SizedBox(height: 8),
            const Text('积分余量未知'),
          ],
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Text('查看积分包与到期时间')),
              Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
