import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

/// Generic quota panel card for any provider module.
///
/// Refined magenta-identity design: duotone violet-to-magenta bars, soft
/// glows, and per-window rows whose color always harmonises with the card
/// accent instead of mixing in unrelated greens.
class ProviderQuotaCard extends StatelessWidget {
  const ProviderQuotaCard({required this.quota, super.key});

  final ProviderQuota quota;

  static const _accentByProvider = {
    QuotaProviderId.cliProxyApi: AppTheme.cyan,
    QuotaProviderId.openCode: AppTheme.magenta,
  };

  static const _iconByProvider = {
    QuotaProviderId.cliProxyApi: Icons.dns_rounded,
    QuotaProviderId.openCode: Icons.bolt_rounded,
  };

  Color get _accent => _accentByProvider[quota.provider] ?? AppTheme.magenta;

  IconData get _icon => _iconByProvider[quota.provider] ?? Icons.bolt_rounded;

  @override
  Widget build(BuildContext context) {
    // Prefer the monthly window (account hard cap) for the headline badge.
    double? headline;
    for (final entry in quota.windows) {
      if (entry.label == '月额度') headline = entry.remainingPercent;
    }
    final average = headline ?? quota.averageRemainingPercent;
    final accent = quota.hasError ? AppTheme.warning : _accent;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      borderColor: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(_icon, size: 20, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quota.provider.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: quota.hasError
                                ? AppTheme.warning
                                : accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: quota.hasError
                                    ? AppTheme.warning
                                    : accent,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          quota.hasError ? '同步失败' : '官方用量实时同步',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10, height: 1.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (average != null && !quota.hasError)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.violet.withValues(alpha: 0.18),
                        accent.withValues(alpha: 0.16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${average.toStringAsFixed(0)}% 剩余',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (quota.hasError) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                '${quota.error}',
                style: const TextStyle(color: Color(0xFFFFA1B5), fontSize: 12),
              ),
            ),
          ] else ...[
            const SizedBox(height: 15),
            EnergyBar(remaining: average, healthyColor: accent),
            if (quota.windows.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (var index = 0; index < quota.windows.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                QuotaRow(entry: quota.windows[index], accent: accent),
              ],
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '暂无可用额度窗口',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shared color rule: bars always stay in the card's duotone identity
/// (accent + violet) while low charge shifts toward warning/danger.
Color _barColor(double? remaining, Color accent) {
  final r = remaining;
  if (r == null) return const Color(0xFF75829B);
  if (r <= 15) return AppTheme.danger;
  if (r <= 35) return AppTheme.warning;
  return accent;
}

/// Glowing 14px energy bar: violet-to-accent duotone with white highlight.
class EnergyBar extends StatelessWidget {
  const EnergyBar({required this.remaining, required this.healthyColor});

  final double? remaining;
  final Color healthyColor;

  @override
  Widget build(BuildContext context) {
    final r = remaining;
    final color = _barColor(remaining, healthyColor);
    final tail = r == null || r <= 35 ? color : AppTheme.violet;
    final value = ((r ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0x2E24324A),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              colors: [tail.withValues(alpha: 0.85), color],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 9),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label | progress bar | percent row under the energy bar.
class QuotaRow extends StatelessWidget {
  const QuotaRow({required this.entry, required this.accent});

  final ProviderQuotaWindow entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remainingPercent;
    final color = _barColor(remaining, accent);
    final tail = remaining == null || remaining <= 35
        ? color
        : AppTheme.violet;
    final progress = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();

    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0x221B2947),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tail.withValues(alpha: 0.75), color],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            remaining == null ? '--' : '${remaining.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
