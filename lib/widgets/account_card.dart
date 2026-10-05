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
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
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
                  size: 30,
                  iconSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account.name.isEmpty ? '未命名账号' : account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  account.hasError
                      ? '检查失败'
                      : account.isAvailable
                      ? account.plan.toUpperCase()
                      : '受限',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF8390AA),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (account.hasError)
            Text(
              account.error!,
              style: const TextStyle(color: AppTheme.danger, fontSize: 11),
            )
          else ...[
            QuotaProgress(
              label: account.primaryLabel,
              window: account.primary,
              compact: true,
            ),
            if (account.secondary != null) ...[
              const SizedBox(height: 10),
              QuotaProgress(
                label: account.secondaryLabel,
                window: account.secondary,
                compact: true,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
