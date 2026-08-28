import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    required this.accentColor,
    required this.refreshing,
    super.key,
  });

  final ProviderQuota quota;
  final String displayName;
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
      if (entry.label == '月限额') return entry.remainingPercent;
    }
    return widget.quota.averageRemainingPercent;
  }

  /// Whether the headline value actually reflects a monthly window.
  bool get _headlineIsMonthly => widget.quota.windows.any(
    (entry) => entry.label == '月限额' && entry.remainingPercent != null,
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

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 232,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xF0151E33), Color(0xE60B1220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header -------------------------------------------------
            Row(
              children: [
                _PulsingDot(controller: _pulse, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.32)),
                    ),
                    child: Text(
                      _statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ---- Plasma orb --------------------------------------------
            Expanded(
              // The stack must span the full card width; otherwise it
              // shrink-wraps to the center text and the orb hugs one side.
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_rotation, _pulse]),
                          builder: (context, _) => CustomPaint(
                            painter: _PlasmaPainter(
                              rotation: _rotation.value,
                              pulse: Curves.easeInOut.transform(_pulse.value),
                              accent: accent,
                              progress:
                                  ((remaining ?? 0).clamp(0, 100)) / 100.0,
                              hasError: quota.hasError,
                              refreshing: widget.refreshing,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              accent.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds),
                          child: Text(
                            valueText,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quota.hasError
                              ? '同步异常'
                              : _headlineIsMonthly
                              ? '月限额剩余'
                              : '综合剩余',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.95),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ---- Segmented charge bar ----------------------------------
            _SegmentedChargeBar(
              progress: quota.hasError ? 0 : (remaining ?? 0) / 100,
              accent: accent,
            ),
            const SizedBox(height: 8),
            // ---- Window lines ------------------------------------------
            if (quota.hasError)
              Text(
                '${quota.error}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.danger.withValues(alpha: 0.92),
                  fontSize: 9.5,
                ),
              )
            else if (quota.windows.isEmpty)
              const Text(
                '暂无额度窗口',
                style: TextStyle(color: Color(0xFF75829B), fontSize: 9.5),
              )
            else
              Row(
                children: [
                  for (
                    var index = 0;
                    index < math.min(2, quota.windows.length);
                    index++
                  ) ...[
                    if (index > 0)
                      Container(
                        width: 1,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x552D3C55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: SizedBox(
                        height: 31,
                        child: _WindowLine(entry: quota.windows[index]),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
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
  const _WindowLine({required this.entry});

  final ProviderQuotaWindow entry;

  @override
  Widget build(BuildContext context) {
    final r = entry.remainingPercent;
    final color = r == null
        ? const Color(0xFF75829B)
        : r <= 15
        ? AppTheme.danger
        : r <= 35
        ? AppTheme.warning
        : AppTheme.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              r == null ? '--' : '${r.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final progress = ((r ?? 0) / 100).clamp(0.0, 1.0).toDouble();
            return ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                width: constraints.maxWidth,
                height: 4,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0x221B2947)),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth * progress,
                        height: 4,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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
