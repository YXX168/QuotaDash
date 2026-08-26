import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

/// Generic quota panel card for any provider module.
///
/// Visual language mirrors the OpenCode energy-bar card from the original
/// branch: glass card, accent icon tile, live-sync status, corner badge,
/// glowing 14px energy bar and label/bar/percent rows per window.
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

  Color get _accent =>
      _accentByProvider[quota.provider] ?? AppTheme.magenta;

  IconData get _icon => _iconByProvider[quota.provider] ?? Icons.bolt_rounded;

  @override
  Widget build(BuildContext context) {
    final average = quota.averageRemainingPercent;
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
                                : AppTheme.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: quota.hasError
                                    ? AppTheme.warning
                                    : AppTheme.success,
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
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${average.toStringAsFixed(0)}% 剩余',
                    style: TextStyle(
                      color: accent,
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
              const SizedBox(height: 13),
              for (var index = 0; index < quota.windows.length; index++) ...[
                if (index > 0) const SizedBox(height: 11),
                QuotaRow(entry: quota.windows[index]),
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

/// Glowing 14px energy bar with white specular highlight.
class EnergyBar extends StatelessWidget {
  const EnergyBar({required this.remaining, required this.healthyColor});

  final double? remaining;
  final Color healthyColor;

  @override
  Widget build(BuildContext context) {
    final r = remaining;
    final color = r == null
        ? const Color(0xFF75829B)
        : r <= 15
        ? const Color(0xFFE8455F)
        : r <= 35
        ? const Color(0xFFE8A825)
        : healthyColor;
    final value = ((r ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0x2E24324A),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.92), color],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
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
                      Colors.white.withValues(alpha: 0.5),
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

/// Label | progress bar | percent row used under the energy bar.
class QuotaRow extends StatelessWidget {
  const QuotaRow({required this.entry});

  final ProviderQuotaWindow entry;

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remainingPercent;
    final color = remaining == null
        ? const Color(0xFF75829B)
        : remaining <= 15
        ? const Color(0xFFE8455F)
        : remaining <= 35
        ? const Color(0xFFE8A825)
        : const Color(0xFF00D98A);
    final progress = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();

    return Row(
      children: [
        SizedBox(
          width: 58,
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
                        colors: [color.withValues(alpha: 0.8), color],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
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
