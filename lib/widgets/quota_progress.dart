import 'package:flutter/material.dart';
import '../models/quota_window.dart';
import '../theme/app_theme.dart';
import 'request_activity.dart';

class QuotaProgress extends StatelessWidget {
  const QuotaProgress({required this.label, required this.window, super.key});

  final String label;
  final QuotaWindow? window;

  @override
  Widget build(BuildContext context) {
    final remaining = window?.remainingPercent;
    final color = _quotaColor(remaining);
    final target = remaining == null ? 0.0 : remaining / 100;

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: target.clamp(0.0, 1.0).toDouble(),
        end: target.clamp(0.0, 1.0).toDouble(),
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
                child: Text(
                  remaining == null
                      ? '--'
                      : '${remaining.toStringAsFixed(0)}% 剩余',
                ),
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
          const SizedBox(height: 7),
          ResetCountdown(target: window?.resetAt),
        ],
      ),
    );
  }

  static Color _quotaColor(double? remaining) {
    if (remaining == null) return const Color(0xFF75829B);
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    return AppTheme.success;
  }
}
