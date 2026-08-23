import 'package:flutter/material.dart';

import '../models/opencode_quota.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

class OpencodeQuotaCard extends StatelessWidget {
  const OpencodeQuotaCard({required this.quota, super.key});

  final OpencodeQuota quota;

  @override
  Widget build(BuildContext context) {
    final windows = quota.windows
        .where((entry) => entry.window != null)
        .toList(growable: false);
    final average = quota.averageRemainingPercent;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      borderColor: AppTheme.magenta.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.magenta.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppTheme.magenta.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.magenta.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: AppTheme.magenta,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OpenCode Go',
                      style: TextStyle(
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
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: AppTheme.success, blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '官方用量实时同步',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10, height: 1.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (average != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.magenta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.magenta.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    average.toStringAsFixed(0) + '% 剩余',
                    style: const TextStyle(
                      color: AppTheme.magenta,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          _OpenCodeEnergyBar(remaining: average),
          if (windows.isNotEmpty) ...[
            const SizedBox(height: 13),
            for (var index = 0; index < windows.length; index++) ...[
              if (index > 0) const SizedBox(height: 11),
              _QuotaRow(entry: windows[index]),
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
      ),
    );
  }
}

class _OpenCodeEnergyBar extends StatelessWidget {
  const _OpenCodeEnergyBar({required this.remaining});

  final double? remaining;

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
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
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
                    colors: [Colors.white.withValues(alpha: 0.5), Colors.transparent],
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

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.entry});

  final OpencodeWindow entry;

  @override
  Widget build(BuildContext context) {
    final remaining = entry.window?.remainingPercent;
    final color = remaining == null
        ? const Color(0xFF75829B)
        : remaining <= 15
        ? AppTheme.danger
        : remaining <= 35
        ? AppTheme.warning
        : AppTheme.success;
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
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0x221B2947),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
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
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            remaining == null ? '--' : remaining.toStringAsFixed(0) + '%',
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
