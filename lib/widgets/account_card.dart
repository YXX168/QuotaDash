import 'package:flutter/material.dart';

import '../models/codex_account.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';
import 'quota_progress.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({required this.account, super.key, this.onTap});

  final CodexAccount account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = account.hasError
        ? AppTheme.danger
        : account.isAvailable
        ? AppTheme.success
        : AppTheme.warning;
    final statusLabel = account.hasError
        ? '检查失败'
        : account.isAvailable
        ? '可用'
        : '受限';

    return GlassCard(
      onTap: onTap,
      borderColor: statusColor.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'account-${account.id}',
                child: GradientIcon(
                  icon: account.hasError
                      ? Icons.cloud_off_rounded
                      : Icons.smart_toy_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name.isEmpty ? '未命名账号' : account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Codex',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.workspace_premium_rounded,
                label: account.plan.toUpperCase(),
              ),
              _InfoChip(
                icon: Icons.check_circle_outline_rounded,
                label: '${account.successRequests} 成功',
              ),
              _InfoChip(
                icon: Icons.error_outline_rounded,
                label: '${account.failedRequests} 失败',
              ),
              if (account.recentTotal > 0)
                _InfoChip(
                  icon: Icons.monitor_heart_rounded,
                  label: '近期 ${account.recentTotal}',
                ),
            ],
          ),
          if (account.hasError) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                account.error!,
                style: const TextStyle(color: Color(0xFFFFA1B5)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            QuotaProgress(label: account.primaryLabel, window: account.primary),
            if (account.secondary != null) ...[
              const SizedBox(height: 17),
              QuotaProgress(
                label: account.secondaryLabel,
                window: account.secondary,
              ),
            ],
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: account.resetCredits == null
                    ? const Color(0xFF7F8AA3)
                    : AppTheme.cyan,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  account.resetCredits != null
                      ? '${account.resetCredits} 次重置额度'
                      : account.resetCreditsError ?? '重置额度未知',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF8390AA),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xB0162031),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF27344A), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9BA8C0)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
