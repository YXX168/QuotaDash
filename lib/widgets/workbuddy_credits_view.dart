import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workbuddy_account.dart';
import '../services/private_http.dart';
import '../theme/app_theme.dart';

String formatWorkBuddyCredits(double? amount) =>
    amount == null ? '--' : NumberFormat('#,##0.##', 'en_US').format(amount);

/// Numeric balances and expiry remain visible in both dashboard modes.
class WorkBuddyCreditsView extends StatelessWidget {
  const WorkBuddyCreditsView({
    required this.account,
    this.showPackages = true,
    super.key,
  });

  final WorkBuddyAccount account;
  final bool showPackages;

  @override
  Widget build(BuildContext context) {
    final credits = account.credits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          key: const Key('workbuddy-remaining-credits'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: account.disabled ? const Color(0xFF75829B) : AppTheme.cyan,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Text('已用 ${formatWorkBuddyCredits(credits?.totalUsed)} credits'),
            Text('总量 ${formatWorkBuddyCredits(credits?.totalSize)} credits'),
            Text('积分包 ${credits?.packageCount ?? '--'}'),
          ],
        ),
        if (credits == null) ...[
          const SizedBox(height: 10),
          const Text('积分余量未知'),
        ],
        if (credits?.fetchedAt case final fetchedAt?) ...[
          const SizedBox(height: 8),
          Text(
            '查询时间：${DateFormat('yyyy-MM-dd HH:mm').format(fetchedAt.toLocal())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (showPackages) ...[
          for (final package in credits?.packages ?? <WorkBuddyPackage>[]) ...[
            const SizedBox(height: 16),
            _PackageRow(package: package),
          ],
        ],
      ],
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.package});

  final WorkBuddyPackage package;

  @override
  Widget build(BuildContext context) {
    final percent = package.remainingPercent;
    final expiry = package.cycleEnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(package.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(
          '剩余 ${formatWorkBuddyCredits(package.remaining)} / '
          '${formatWorkBuddyCredits(package.size)} credits',
        ),
        const SizedBox(height: 4),
        Text('已用 ${formatWorkBuddyCredits(package.used)} credits'),
        if (percent != null) ...[
          const SizedBox(height: 8),
          Semantics(
            label: '${package.name} 剩余 ${percent.toStringAsFixed(1)}%',
            child: LinearProgressIndicator(
              value: percent / 100,
              color: percent <= 15 ? AppTheme.danger : AppTheme.cyan,
              backgroundColor: AppTheme.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              minHeight: 6,
            ),
          ),
        ] else ...[
          const SizedBox(height: 5),
          const Text('剩余比例未知'),
        ],
        if (package.cycleStart case final start?) ...[
          const SizedBox(height: 6),
          Text(
            '周期开始：${DateFormat('yyyy-MM-dd HH:mm').format(start.toLocal())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          expiry == null
              ? '到期时间未知'
              : '到期：${DateFormat('yyyy-MM-dd HH:mm').format(expiry.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
