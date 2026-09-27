import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlowingGlobeMark extends StatefulWidget {
  const GlowingGlobeMark({super.key, this.size = 38});

  final double size;

  @override
  State<GlowingGlobeMark> createState() => _GlowingGlobeMarkState();
}

class _GlowingGlobeMarkState extends State<GlowingGlobeMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        key: const Key('glowing-globe-mark'),
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _GlowingGlobePainter(progress: _controller.value),
          ),
        ),
      ),
    );
  }
}

class _GlowingGlobePainter extends CustomPainter {
  const _GlowingGlobePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side * 0.29;
    final orbitRadius = side * 0.405;
    final phase = progress * math.pi * 2;
    final orbitRotation = phase * 0.72 - 0.34;
    const orbitVerticalScale = 0.31;

    final tileRect = Offset.zero & size;
    final tileRadius = Radius.circular(side * 0.31);
    final tilePath = Path()
      ..addRRect(RRect.fromRectAndRadius(tileRect, tileRadius));

    canvas.drawPath(
      tilePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF152746), Color(0xFF0A1222)],
        ).createShader(tileRect),
    );
    canvas.drawPath(
      tilePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.018
        ..color = AppTheme.cyan.withValues(alpha: 0.22),
    );

    final auraRect = Rect.fromCircle(
      center: center,
      radius: orbitRadius * 1.14,
    );
    canvas.drawCircle(
      center,
      orbitRadius * 1.14,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.cyan.withValues(alpha: 0.14),
            AppTheme.success.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0, 0.48, 1],
        ).createShader(auraRect),
    );

    _drawOrbit(
      canvas,
      center: center,
      radius: orbitRadius,
      rotation: orbitRotation,
      verticalScale: orbitVerticalScale,
      front: false,
    );

    final globeRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.08,
      Paint()
        ..color = AppTheme.cyan.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.12),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.38),
          radius: 1.05,
          colors: [Color(0xFF2E5D9F), Color(0xFF16214C), Color(0xFF080C22)],
          stops: [0, 0.48, 1],
        ).createShader(globeRect),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(globeRect));
    _drawGlobeGrid(canvas, center: center, radius: radius, phase: phase);

    final scanAngle = phase * 1.35 - math.pi / 2;
    final scanPoint =
        center +
        Offset(
          math.cos(scanAngle) * radius * 0.83,
          math.sin(scanAngle) * radius * 0.83,
        );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.89),
      scanAngle - 0.48,
      0.52,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = side * 0.035
        ..color = AppTheme.cyan.withValues(alpha: 0.78)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.035),
    );
    canvas.drawCircle(
      scanPoint,
      side * 0.055,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.06),
    );
    canvas.drawCircle(scanPoint, side * 0.022, Paint()..color = Colors.white);
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.025
        ..shader = const SweepGradient(
          colors: [
            AppTheme.cyan,
            AppTheme.success,
            AppTheme.cyan,
            AppTheme.cyan,
          ],
        ).createShader(globeRect),
    );

    _drawOrbit(
      canvas,
      center: center,
      radius: orbitRadius,
      rotation: orbitRotation,
      verticalScale: orbitVerticalScale,
      front: true,
    );

    final flareAngle = phase * 0.72 + 0.8;
    final flareOffset = Offset(
      math.cos(flareAngle) * orbitRadius * 1.02,
      math.sin(flareAngle) * orbitRadius * orbitVerticalScale * 1.02,
    );
    final flarePoint =
        center +
        Offset(
          flareOffset.dx * math.cos(orbitRotation) -
              flareOffset.dy * math.sin(orbitRotation),
          flareOffset.dx * math.sin(orbitRotation) +
              flareOffset.dy * math.cos(orbitRotation),
        );
    canvas.drawCircle(
      flarePoint,
      side * 0.055,
      Paint()
        ..color = AppTheme.cyan.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.065),
    );
    canvas.drawCircle(flarePoint, side * 0.018, Paint()..color = Colors.white);
  }

  void _drawGlobeGrid(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double phase,
  }) {
    final lineWidth = radius * 0.055;
    final meridianPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.cyan.withValues(alpha: 0.55);
    final latitudePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.success.withValues(alpha: 0.45);

    for (var index = -2; index <= 2; index++) {
      final latitude = index * 0.34;
      final width =
          radius * 2 * math.sqrt(math.max(0.08, 1 - latitude * latitude));
      final height = radius * (0.16 + (1 - latitude.abs()) * 0.12);
      final rect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + latitude * radius),
        width: width,
        height: height,
      );
      canvas.drawOval(rect, latitudePaint);
    }

    for (var index = -2; index <= 2; index++) {
      final angle = phase + index * math.pi / 4;
      final width =
          radius * 2 * math.max(0.06, math.cos(angle).abs()).toDouble();
      final rect = Rect.fromCenter(
        center: center,
        width: width,
        height: radius * 2.08,
      );
      canvas.drawOval(rect, meridianPaint);
    }

    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.26),
          AppTheme.cyan.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.26, -radius * 0.26),
        width: radius * 0.78,
        height: radius * 0.34,
      ),
      highlight,
    );
  }

  void _drawOrbit(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double rotation,
    required double verticalScale,
    required bool front,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(1, verticalScale);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.095
      ..shader = const SweepGradient(
        colors: [AppTheme.cyan, AppTheme.success, AppTheme.cyan, AppTheme.cyan],
      ).createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12);
    final crispPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.045
      ..shader = const SweepGradient(
        colors: [AppTheme.cyan, AppTheme.success, AppTheme.cyan, AppTheme.cyan],
      ).createShader(rect);

    if (front) {
      canvas.drawArc(rect, 0, math.pi, false, orbitPaint);
      canvas.drawArc(rect, 0, math.pi, false, crispPaint);
    } else {
      canvas.drawOval(rect, orbitPaint);
      canvas.drawOval(rect, crispPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlowingGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
