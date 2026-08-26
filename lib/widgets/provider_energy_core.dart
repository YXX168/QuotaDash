import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';

/// Energy-orb rendering of any provider's quota snapshot.
///
/// Mirrors [EnergyAccountCore]: status header, glowing orb with ring
/// progress and comet satellite, energy bar, then per-window lines.
class ProviderEnergyCore extends StatefulWidget {
  const ProviderEnergyCore({
    required this.quota,
    required this.refreshing,
    super.key,
  });

  final ProviderQuota quota;
  final bool refreshing;

  @override
  State<ProviderEnergyCore> createState() => _ProviderEnergyCoreState();
}

class _ProviderEnergyCoreState extends State<ProviderEnergyCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _coreColor(double? remaining) {
    if (widget.quota.hasError) return AppTheme.danger;
    if (remaining == null) return AppTheme.magenta;
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    if (remaining <= 65) return AppTheme.violet;
    return AppTheme.magenta;
  }

  String _statusLabel(double? remaining) {
    if (widget.quota.hasError) return '检查失败';
    if (remaining == null) return '状态正常';
    if (remaining <= 15) return '额度紧张';
    if (remaining <= 35) return '额度偏低';
    return '状态正常';
  }

  @override
  Widget build(BuildContext context) {
    final quota = widget.quota;
    final remaining = quota.averageRemainingPercent;
    final color = _coreColor(remaining);
    final value = quota.hasError
        ? '!'
        : remaining == null
        ? '--'
        : '${remaining.toStringAsFixed(0)}%';
    final label = quota.hasError ? '检查失败' : '综合剩余';

    return Semantics(
      label: '${quota.provider.displayName}，$label $value',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 226,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xD8172236), Color(0xC40C1323)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color, blurRadius: 7)],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      quota.provider.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      _statusLabel(remaining),
                      style: TextStyle(
                        color: color.withValues(alpha: 0.95),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _OrbPainter(
                            animation: _controller,
                            color: color,
                            progress: (remaining ?? 0).clamp(0, 100) / 100,
                            hasError: quota.hasError,
                            refreshing: widget.refreshing,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1,
                                shadows: [
                                  Shadow(color: color, blurRadius: 18),
                                ],
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.95),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              _EnergyBar(remaining: remaining, color: color),
              const SizedBox(height: 8),
              Expanded(
                child: quota.windows.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          quota.hasError ? '${quota.error}' : '暂无额度窗口',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: quota.hasError
                                ? AppTheme.danger.withValues(alpha: 0.9)
                                : const Color(0xFF75829B),
                            fontSize: 9.5,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          for (var index = 0;
                              index < math.min(2, quota.windows.length);
                              index++) ...[
                            if (index > 0)
                              Container(
                                width: 1,
                                height: 24,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                                color: const Color(0x332D3C55),
                              ),
                            Expanded(
                              child: _QuotaLine(entry: quota.windows[index]),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  const _EnergyBar({required this.remaining, required this.color});

  final double? remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final remaining = this.remaining;
    final value = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        Text(
          '剩余能量',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 11,
            decoration: BoxDecoration(
              color: const Color(0x221B2947),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.8), color],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          remaining == null ? '--' : '${remaining.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _QuotaLine extends StatelessWidget {
  const _QuotaLine({required this.entry});

  final ProviderQuotaWindow entry;

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remainingPercent;
    final color = remaining == null
        ? const Color(0xFF75829B)
        : remaining <= 15
        ? AppTheme.danger
        : remaining <= 35
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
              remaining == null ? '--' : '${remaining.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0x221B2947),
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.animation,
    required this.color,
    required this.progress,
    required this.hasError,
    required this.refreshing,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double progress;
  final bool hasError;
  final bool refreshing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final phase = animation.value;
    final speed = refreshing ? 2.2 : 0.5;
    final rotation = phase * math.pi * 2 * speed;
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    final ringRadius = math.min(size.width, size.height) * 0.38;

    final glow =
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0, 0.55, 1],
          ).createShader(
            Rect.fromCircle(center: center, radius: ringRadius * 0.92),
          );
    canvas.drawCircle(center, ringRadius * 0.92, glow);

    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.12),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.9),
    );

    final satelliteAngle = -math.pi / 2 + rotation;
    final satellite = Offset(
      center.dx + math.cos(satelliteAngle) * ringRadius,
      center.dy + math.sin(satelliteAngle) * ringRadius,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      satelliteAngle - 0.9,
      0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(satellite, hasError ? 5 : 3.4, Paint()..color = color);
    if (!hasError) {
      canvas.drawCircle(
        satellite,
        5.2,
        Paint()..color = color.withValues(alpha: 0.2 + pulse * 0.18),
      );
    }

    final coreRadius = ringRadius * 0.5 + pulse * 0.7;
    final corePaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95),
              color,
              color.withValues(alpha: 0.62),
            ],
            stops: const [0, 0.42, 1],
          ).createShader(
            Rect.fromCircle(center: center - Offset(6, 6), radius: coreRadius),
          );
    canvas.drawCircle(center, coreRadius, corePaint);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotation * 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: ringRadius * 2.15,
        height: ringRadius * 0.82,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = color.withValues(alpha: 0.22),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return animation != oldDelegate.animation ||
        color != oldDelegate.color ||
        progress != oldDelegate.progress ||
        hasError != oldDelegate.hasError ||
        refreshing != oldDelegate.refreshing;
  }
}
