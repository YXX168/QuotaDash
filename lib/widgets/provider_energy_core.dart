import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';

/// "Plasma Core" energy card for any provider.
///
/// Original design: layered plasma orb (breathing core + counter-rotating
/// dual rings + orbiting particles + lightning arcs at low charge) inside a
/// dark glass tile, with an animated segmented charge bar and window lines.
class ProviderEnergyCore extends StatefulWidget {
  const ProviderEnergyCore({
    required this.quota,
    required this.displayName,
    required this.description,
    required this.accentColor,
    required this.refreshing,
    super.key,
  });

  final ProviderQuota quota;
  final String displayName;
  final String description;
  final Color accentColor;
  final bool refreshing;

  @override
  State<ProviderEnergyCore> createState() => _ProviderEnergyCoreState();
}

class _ProviderEnergyCoreState extends State<ProviderEnergyCore>
    with TickerProviderStateMixin {
  late final AnimationController _rotation;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotation.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Color get _accent {
    final remaining = _headlineRemaining;
    if (widget.quota.hasError) return AppTheme.danger;
    if (remaining == null) return widget.accentColor;
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    if (remaining <= 65) return AppTheme.violet;
    return widget.accentColor;
  }

  String get _statusLabel {
    final quota = widget.quota;
    if (quota.hasError) return '同步失败';
    final remaining = _headlineRemaining;
    if (remaining == null) return '待同步';
    if (remaining <= 15) return '额度告急';
    if (remaining <= 35) return '余量偏低';
    return '能量充沛';
  }

  /// Monthly remaining when available (the account hard cap), otherwise the
  /// average across windows.
  double? get _headlineRemaining {
    for (final entry in widget.quota.windows) {
      if (entry.label.contains('月')) return entry.remainingPercent;
    }
    return widget.quota.averageRemainingPercent;
  }

  /// Whether the headline value actually reflects a monthly window.
  bool get _headlineIsMonthly => widget.quota.windows.any(
    (entry) => entry.label.contains('月') && entry.remainingPercent != null,
  );

  @override
  Widget build(BuildContext context) {
    final quota = widget.quota;
    final accent = _accent;
    final remaining = _headlineRemaining;
    final valueText = quota.hasError
        ? 'ERR'
        : remaining == null
        ? '--'
        : '${remaining.toStringAsFixed(0)}%';

    final orb = _OrbPanel(
      key: const Key('provider-energy-orb'),
      rotation: _rotation,
      pulse: _pulse,
      accent: accent,
      remaining: remaining,
      valueText: valueText,
      valueLabel: quota.hasError
          ? '同步异常'
          : _headlineIsMonthly
          ? '本月可用'
          : '综合可用',
      hasError: quota.hasError,
      refreshing: widget.refreshing,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xF0182237), Color(0xF0080F1D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                  ),
                  child: Icon(Icons.bolt_rounded, color: accent, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.26)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(controller: _pulse, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (quota.hasError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  quota.error.toString(),
                  style: const TextStyle(
                    color: Color(0xFFFFA1B5),
                    fontSize: 11,
                  ),
                ),
              )
            else if (quota.windows.isEmpty)
              const Text(
                '暂未获取到套餐额度',
                style: TextStyle(color: Color(0xFF75829B), fontSize: 10),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final windows = Column(
                    key: const Key('provider-energy-windows'),
                    children: [
                      for (
                        var index = 0;
                        index < quota.windows.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 8),
                        _WindowLine(
                          entry: quota.windows[index],
                          accent: accent,
                        ),
                      ],
                    ],
                  );
                  if (compact) {
                    return Column(
                      children: [
                        SizedBox(height: 150, child: orb),
                        const SizedBox(height: 12),
                        windows,
                      ],
                    );
                  }
                  return SizedBox(
                    height: 210,
                    child: Row(
                      children: [
                        SizedBox(width: 190, child: orb),
                        const SizedBox(width: 16),
                        Expanded(child: windows),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OrbPanel extends StatelessWidget {
  const _OrbPanel({
    required this.rotation,
    required this.pulse,
    required this.accent,
    required this.remaining,
    required this.valueText,
    required this.valueLabel,
    required this.hasError,
    required this.refreshing,
    super.key,
  });

  final AnimationController rotation;
  final AnimationController pulse;
  final Color accent;
  final double? remaining;
  final String valueText;
  final String valueLabel;
  final bool hasError;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x42101A2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([rotation, pulse]),
                builder: (context, _) => CustomPaint(
                  painter: _PlasmaPainter(
                    rotation: rotation.value,
                    pulse: Curves.easeInOut.transform(pulse.value),
                    accent: accent,
                    progress: ((remaining ?? 0).clamp(0, 100)) / 100.0,
                    hasError: hasError,
                    refreshing: refreshing,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                valueLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: _SegmentedChargeBar(
              progress: hasError ? 0 : (remaining ?? 0) / 100,
              accent: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25 + t * 0.45),
                blurRadius: 5 + t * 6,
                spreadRadius: t * 1.6,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentedChargeBar extends StatelessWidget {
  const _SegmentedChargeBar({required this.progress, required this.accent});

  static const _segmentCount = 24;

  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        final litCount = (animated * _segmentCount).round();
        return Row(
          children: [
            for (var index = 0; index < _segmentCount; index++)
              Expanded(
                child: Container(
                  height: 7,
                  margin: EdgeInsets.only(
                    right: index == _segmentCount - 1 ? 0 : 2.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: index < litCount
                        ? LinearGradient(
                            colors: [
                              accent.withValues(
                                alpha: 0.55 + 0.35 * (index / _segmentCount),
                              ),
                              accent,
                            ],
                          )
                        : null,
                    color: index < litCount ? null : const Color(0xFF1A2438),
                    boxShadow: index == litCount - 1 && litCount > 0
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.65),
                              blurRadius: 7,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WindowLine extends StatelessWidget {
  const _WindowLine({required this.entry, required this.accent});

  final ProviderQuotaWindow entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final r = entry.remainingPercent;
    final color = r == null
        ? const Color(0xFF75829B)
        : r <= 15
        ? AppTheme.danger
        : r <= 35
        ? AppTheme.warning
        : accent;
    final progress = ((r ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0x54121C2F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                r == null ? '--' : '可用 ${r.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFF1C2940)),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: color == AppTheme.cyan
                                ? const [AppTheme.cyan, AppTheme.violet]
                                : [color.withValues(alpha: 0.82), color],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 11,
                color: color.withValues(alpha: 0.78),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _resetText(entry.resetAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _resetText(DateTime? resetAt) {
    if (resetAt == null) return '恢复时间待同步';
    return '恢复于 ${DateFormat('M月d日 HH:mm').format(resetAt.toLocal())}';
  }
}

class _PlasmaPainter extends CustomPainter {
  _PlasmaPainter({
    required this.rotation,
    required this.pulse,
    required this.accent,
    required this.progress,
    required this.hasError,
    required this.refreshing,
  });

  final double rotation;
  final double pulse;
  final Color accent;
  final double progress;
  final bool hasError;
  final bool refreshing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.34;
    final speedBoost = refreshing ? 1.8 : 1.0;

    // Outer atmosphere glow.
    canvas.drawCircle(
      center,
      baseRadius * 1.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: 0.16 + pulse * 0.06),
                accent.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              stops: const [0, 0.55, 1],
            ).createShader(
              Rect.fromCircle(center: center, radius: baseRadius * 1.55),
            ),
    );

    // Progress ring (thick arc with round caps).
    final progressRect = Rect.fromCircle(center: center, radius: baseRadius);
    canvas.drawArc(
      progressRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = accent.withValues(alpha: 0.10),
    );
    if (!hasError && progress > 0) {
      canvas.drawArc(
        progressRect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );
    }

    // Counter-rotating dashed inner ring.
    final innerRadius = baseRadius * 0.80;
    final dashAngle = -rotation * math.pi * 2 * 0.7 * speedBoost;
    for (var index = 0; index < 18; index++) {
      final start = dashAngle + index * math.pi / 9;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        start,
        math.pi / 22,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: 0.28 + pulse * 0.16),
      );
    }

    // Orbiting energy particles on the progress ring.
    final particleCount = hasError ? 2 : 3;
    for (var index = 0; index < particleCount; index++) {
      final angle =
          rotation * math.pi * 2 * speedBoost +
          index * math.pi * 2 / particleCount +
          (hasError ? 0 : progress * math.pi * 2);
      final position = Offset(
        center.dx + math.cos(angle) * baseRadius,
        center.dy + math.sin(angle) * baseRadius,
      );
      canvas.drawCircle(position, 2.6, Paint()..color = accent);
      canvas.drawCircle(
        position,
        4.6,
        Paint()..color = accent.withValues(alpha: 0.22),
      );
    }

    // Plasma core with breathing radius and layered gradients.
    final coreRadius = baseRadius * 0.52 + pulse * 2.2;
    canvas.drawCircle(
      center,
      coreRadius * 1.5,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: 0.30),
                accent.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: coreRadius * 1.5),
            ),
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Colors.white.withValues(alpha: 0.95),
            accent,
            accent.withValues(alpha: 0.55),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.40),
    );

    // Lightning arcs flicker when the battery is low or in error state.
    if (hasError || progress <= 0.35) {
      final random = math.Random(size.hashCode);
      final bolts = refreshing ? 3 : 2;
      for (var index = 0; index < bolts; index++) {
        final phase = (rotation * speedBoost * 3 + index / bolts) % 1.0;
        if (phase > 0.82) {
          _paintBolt(canvas, center, coreRadius, baseRadius, accent, random);
        }
      }
    }
  }

  void _paintBolt(
    Canvas canvas,
    Offset center,
    double fromRadius,
    double toRadius,
    Color color,
    math.Random random,
  ) {
    final startAngle = random.nextDouble() * math.pi * 2;
    final start = Offset(
      center.dx + math.cos(startAngle) * fromRadius,
      center.dy + math.sin(startAngle) * fromRadius,
    );
    final end = Offset(
      center.dx + math.cos(startAngle) * toRadius,
      center.dy + math.sin(startAngle) * toRadius,
    );
    final mid1 = Offset.lerp(start, end, 0.4)!;
    final mid2 = Offset.lerp(start, end, 0.7)!;
    final jitter = (toRadius - fromRadius) * 0.22;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(
        mid1.dx + random.nextDouble() * jitter - jitter / 2,
        mid1.dy + random.nextDouble() * jitter - jitter / 2,
      )
      ..lineTo(
        mid2.dx + random.nextDouble() * jitter - jitter / 2,
        mid2.dy + random.nextDouble() * jitter - jitter / 2,
      )
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _PlasmaPainter oldDelegate) {
    return rotation != oldDelegate.rotation ||
        pulse != oldDelegate.pulse ||
        accent != oldDelegate.accent ||
        progress != oldDelegate.progress ||
        hasError != oldDelegate.hasError ||
        refreshing != oldDelegate.refreshing;
  }
}
