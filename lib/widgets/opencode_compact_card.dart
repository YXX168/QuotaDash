import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';

/// Compact, mode-independent OpenCode quota strip.
class OpenCodeCompactCard extends StatelessWidget {
  const OpenCodeCompactCard({required this.quota, super.key});

  final ProviderQuota quota;

  @override
  Widget build(BuildContext context) {
    final accent = quota.hasError ? AppTheme.warning : AppTheme.cyan;
    return Semantics(
      label: 'OpenCode Go 额度',
      child: Container(
        key: const Key('opencode-compact-card'),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
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
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -7,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const Key('opencode-top-light-strip'),
                  width: 132,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.cyan.withValues(alpha: 0.70),
                        AppTheme.violet.withValues(alpha: 0.62),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      for (
                        var index = 0;
                        index < quota.windows.length;
                        index++
                      ) ...[
                        if (index > 0)
                          Container(
                            width: 1,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: AppTheme.cyan.withValues(alpha: 0.08),
                          ),
                        Expanded(
                          child: _QuotaValue(window: quota.windows[index]),
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

class _QuotaValue extends StatelessWidget {
  const _QuotaValue({required this.window});

  final ProviderQuotaWindow window;

  Color get _valueColor {
    final remaining = window.remainingPercent;
    if (remaining == null) return const Color(0xFF7F8CA4);
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    return AppTheme.cyan;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                key: Key('opencode-quota-track-${window.label}'),
                width: double.infinity,
                height: 4,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFF202B41)),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * progress,
                      child: DecoratedBox(
                        key: Key('opencode-quota-fill-${window.label}'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: color == AppTheme.cyan
                                ? const [AppTheme.cyan, AppTheme.violet]
                                : [color, color.withValues(alpha: 0.82)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
