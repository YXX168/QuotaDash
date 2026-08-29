import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

/// Generic quota panel card for any provider module.
///
/// Clean layout: header (icon + name + monthly balance badge) followed by
/// one duotone progress row per quota window. No redundant summary bar.
class ProviderQuotaCard extends StatelessWidget {
  const ProviderQuotaCard({
    required this.quota,
    required this.displayName,
    required this.description,
    required this.accentColor,
    required this.icon,
    super.key,
  });

  final ProviderQuota quota;
  final String displayName;
  final String description;
  final Color accentColor;
  final IconData icon;

  double? get _monthlyRemaining {
    for (final entry in quota.windows) {
      if (_isMonthly(entry.label)) return entry.remainingPercent;
    }
    return null;
  }

  /// True only when the provider actually exposes a monthly window so the
  /// header badge never mislabels an average as the monthly hard cap.
  bool get _hasMonthlyWindow =>
      quota.windows.any((entry) => _isMonthly(entry.label));

  static bool _isMonthly(String label) => label.contains('月');

  @override
  Widget build(BuildContext context) {
    final accent = quota.hasError ? AppTheme.warning : accentColor;
    final monthly = _monthlyRemaining ?? quota.averageRemainingPercent;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (!quota.hasError && _hasMonthlyWindow && monthly != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.violet.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.38)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.battery_charging_full_rounded,
                        size: 12,
                        color: accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '本月可用 ${monthly.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
          ] else if (quota.windows.isEmpty) ...[
            const SizedBox(height: 12),
            Text('暂未获取到套餐额度', style: Theme.of(context).textTheme.bodySmall),
          ] else ...[
            const SizedBox(height: 16),
            for (var index = 0; index < quota.windows.length; index++) ...[
              if (index > 0) const SizedBox(height: 14),
              _WindowRow(
                entry: quota.windows[index],
                accent: accent,
                isMonthly: _isMonthly(quota.windows[index].label),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One quota window: label + duotone bar + percent.
/// The monthly row is visually emphasized as the account hard cap.
class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.entry,
    required this.accent,
    required this.isMonthly,
  });

  final ProviderQuotaWindow entry;
  final Color accent;
  final bool isMonthly;

  Color get _color {
    final r = entry.remainingPercent;
    if (r == null) return const Color(0xFF75829B);
    if (r <= 15) return AppTheme.danger;
    if (r <= 35) return AppTheme.warning;
    return accent;
  }

  Color get _tailColor {
    final r = entry.remainingPercent;
    if (r == null || r <= 35) return _color;
    return AppTheme.violet;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remainingPercent;
    final progress = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              entry.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isMonthly ? FontWeight.w800 : FontWeight.w600,
                color: isMonthly ? Colors.white : const Color(0xFFB9C4DA),
              ),
            ),
            if (isMonthly) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '月度周期',
                  style: TextStyle(
                    color: accent,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              remaining == null
                  ? '--'
                  : '可用 ${remaining.toStringAsFixed(0)}%',
              style: TextStyle(
                color: _color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(
                height: isMonthly ? 9 : 7,
                color: const Color(0x1E1B2947),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: isMonthly ? 9 : 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_tailColor.withValues(alpha: 0.70), _color],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _resetText(entry.resetAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }

  static String _resetText(DateTime? resetAt) {
    if (resetAt == null) return '恢复时间待同步';
    return '恢复于 ${DateFormat('M月d日 HH:mm').format(resetAt.toLocal())}';
  }
}
