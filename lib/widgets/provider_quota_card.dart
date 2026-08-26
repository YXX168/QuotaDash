import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

/// Generic quota panel card for any provider module.
///
/// Mirrors the Codex [AccountCard] visual language: glass card, gradient
/// icon, status pill and animated progress rows with reset countdowns.
class ProviderQuotaCard extends StatelessWidget {
  const ProviderQuotaCard({required this.quota, super.key});

  final ProviderQuota quota;

  static Color _accentFor(QuotaProviderId id) {
    switch (id) {
      case QuotaProviderId.cliProxyApi:
        return AppTheme.cyan;
      case QuotaProviderId.openCode:
        return AppTheme.magenta;
    }
  }

  static IconData _iconFor(QuotaProviderId id) {
    switch (id) {
      case QuotaProviderId.cliProxyApi:
        return Icons.dns_rounded;
      case QuotaProviderId.openCode:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(quota.provider);
    final average = quota.averageRemainingPercent;
    return GlassCard(
      borderColor: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIcon(icon: _iconFor(quota.provider)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quota.provider.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      quota.hasError ? '同步失败' : '额度窗口实时同步',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: quota.hasError ? '异常' : '正常',
                color: quota.hasError ? AppTheme.danger : AppTheme.success,
              ),
            ],
          ),
          if (quota.hasError) ...[
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
                '${quota.error}',
                style: const TextStyle(color: Color(0xFFFFA1B5)),
              ),
            ),
          ] else ...[
            if (average != null) ...[
              const SizedBox(height: 18),
              _AverageRow(remaining: average, accent: accent),
            ],
            const SizedBox(height: 16),
            for (var index = 0; index < quota.windows.length; index++) ...[
              if (index > 0) const SizedBox(height: 17),
              _WindowProgress(
                label: quota.windows[index].label,
                remaining: quota.windows[index].remainingPercent,
                resetAt: quota.windows[index].resetAt,
              ),
            ],
            if (quota.windows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('暂无可用额度窗口'),
              ),
          ],
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.remaining, required this.accent});

  final double remaining;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.donut_large_rounded, size: 18, color: accent),
          const SizedBox(width: 9),
          const Text('综合剩余'),
          const Spacer(),
          Text(
            '${remaining.toStringAsFixed(0)}%',
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowProgress extends StatelessWidget {
  const _WindowProgress({
    required this.label,
    required this.remaining,
    this.resetAt,
  });

  final String label;
  final double? remaining;
  final DateTime? resetAt;

  @override
  Widget build(BuildContext context) {
    final r = remaining;
    final color = r == null
        ? const Color(0xFF75829B)
        : r <= 15
        ? AppTheme.danger
        : r <= 35
        ? AppTheme.warning
        : AppTheme.magenta;
    final target = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                remaining == null
                    ? '--'
                    : '${(value * 100).toStringAsFixed(0)}% 剩余',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0x221B2947),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.72), color],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (resetAt != null) ...[
            const SizedBox(height: 7),
            Text(
              _resetLabel(resetAt!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  static String _resetLabel(DateTime resetAt) {
    final diff = resetAt.difference(DateTime.now());
    if (diff.isNegative) return '已重置';
    if (diff.inDays >= 1) {
      return '${diff.inDays} 天后重置';
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours >= 1) return '${hours} 小时 ${minutes} 分后重置';
    return '${diff.inMinutes} 分钟后重置';
  }
}
