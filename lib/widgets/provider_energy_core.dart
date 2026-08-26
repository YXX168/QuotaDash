import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/provider_quota.dart';
import '../theme/app_theme.dart';

/// Energy-orb rendering of any provider's unified quota snapshot.
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

  @override
  Widget build(BuildContext context) {
    final quota = widget.quota;
    final remaining = quota.averageRemainingPercent;
    final accent = quota.hasError ? AppTheme.danger : AppTheme.orange;
    final value = quota.hasError
        ? '!'
        : remaining == null
        ? '--'
        : '${remaining.toStringAsFixed(0)}%';

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 208,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xD8172236), Color(0xC40C1323)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent, blurRadius: 7)],
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    quota.provider.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  quota.hasError ? '同步失败' : '实时同步',
                  style: TextStyle(
                    color: quota.hasError ? AppTheme.warning : AppTheme.success,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _OrbPainter(
                          animation: _controller,
                          color: accent,
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
                              fontSize: 25,
                              height: 1,
                              shadows: [Shadow(color: accent, blurRadius: 18)],
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        quota.hasError ? '检查失败' : '综合剩余',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.95),
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
            if (!quota.hasError && quota.windows.isNotEmpty)
              for (var index = 0; index < quota.windows.length; index++) ...[
                if (index > 0) const SizedBox(height: 5),
                _WindowLine(entry: quota.windows[index]),
              ]
            else if (quota.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${quota.error}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.danger.withValues(alpha: 0.9),
                    fontSize: 9.5,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '暂无额度窗口',
                  style: TextStyle(color: Color(0xFF75829B), fontSize: 9.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WindowLine extends StatelessWidget {
  const _WindowLine({required this.entry});

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
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
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
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            remaining == null ? '--' : '${remaining.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
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

    final glow = Paint()
      ..shader =
          RadialGradient(
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
    canvas.drawCircle(satellite, hasError ? 5 : 3.4, Paint()..color = color);

    final coreRadius = ringRadius * 0.5 + pulse * 0.7;
    final corePaint = Paint()
      ..shader =
          RadialGradient(
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
