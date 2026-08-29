import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';

/// Compact, mode-independent OpenCode quota strip.
class OpenCodeCompactCard extends StatelessWidget {
  const OpenCodeCompactCard({required this.quota, super.key});

  final ProviderQuota quota;

  double? get _monthlyRemaining {
    for (final window in quota.windows) {
      if (window.label.contains('月')) return window.remainingPercent;
    }
    return null;
  }

  double? get _monthlyUsed {
    final remaining = _monthlyRemaining;
    if (remaining == null) return null;
    return (100 - remaining).clamp(0, 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final accent = quota.hasError ? AppTheme.warning : AppTheme.magenta;
    return Semantics(
      label: 'OpenCode Go 额度',
      child: Container(
        key: const Key('opencode-compact-card'),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF21A2238), Color(0xF2111728)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -28,
              child: IgnorePointer(
                child: Container(
                  width: 130,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 44,
              right: 44,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.violet.withValues(alpha: 0.75),
                      accent.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.violet.withValues(alpha: 0.28),
                            accent.withValues(alpha: 0.22),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Icon(Icons.bolt_rounded, color: accent, size: 19),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'OpenCode Go',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _UsageReading(
                      accent: accent,
                      error: quota.hasError,
                      usedPercent: _monthlyUsed,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (quota.hasError)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '额度同步失败',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (quota.windows.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '暂无额度数据',
                      style: TextStyle(color: Color(0xFF8390A8), fontSize: 11),
                    ),
                  )
                else
                  Row(
                    key: const Key('opencode-compact-values'),
                    children: [
                      for (var index = 0; index < quota.windows.length; index++)
                        ...[
                          if (index > 0)
                            Container(
                              width: 1,
                              height: 44,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: const Color(0x242F3C55),
                            ),
                        Expanded(
                          child: _QuotaValue(
                            window: quota.windows[index],
                          ),
                        ),
                        ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageReading extends StatelessWidget {
  const _UsageReading({
    required this.accent,
    required this.error,
    required this.usedPercent,
  });

  final Color accent;
  final bool error;
  final double? usedPercent;

  @override
  Widget build(BuildContext context) {
    if (error) {
      return const Text(
        '同步失败',
        style: TextStyle(
          color: AppTheme.warning,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    final value = usedPercent == null
        ? '--'
        : '${usedPercent!.toStringAsFixed(0)}%';
    return Row(
      key: const Key('opencode-used-badge'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text(
          '月已用',
          style: TextStyle(
            color: Color(0xFF8996AD),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _QuotaValue extends StatelessWidget {
  const _QuotaValue({required this.window});

  final ProviderQuotaWindow window;

  Color get _valueColor {
    final remaining = window.remainingPercent;
    if (remaining == null) return const Color(0xFF7F8CA4);
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    if (window.label.contains('月')) return AppTheme.magenta;
    return AppTheme.violet;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = window.remainingPercent;
    final progress = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    final color = _valueColor;
    return Column(
      key: Key('opencode-quota-${window.label}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          window.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF95A2B9),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          remaining == null ? '--' : '${remaining.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            key: Key('opencode-quota-track-${window.label}'),
            height: 3,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF202B41)),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.violet.withValues(alpha: 0.72),
                          color,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
