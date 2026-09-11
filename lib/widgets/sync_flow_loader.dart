import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/visual_mode.dart';
import '../theme/app_theme.dart';

/// First-sync animation built as a layered data gateway.
class SyncFlowLoader extends StatefulWidget {
  const SyncFlowLoader({required this.visualMode, super.key});

  final VisualMode visualMode;

  @override
  State<SyncFlowLoader> createState() => _SyncFlowLoaderState();
}

class _SyncFlowLoaderState extends State<SyncFlowLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0.28;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final energyMode = widget.visualMode == VisualMode.energy;
    final primary = energyMode ? AppTheme.violet : AppTheme.cyan;

    return Semantics(
      liveRegion: true,
      label: '正在同步账户状态，请稍候',
      child: SizedBox(
        key: Key(energyMode ? 'energy-sync-flow' : 'console-sync-flow'),
        height: 468,
        child: Column(
          children: [
            RepaintBoundary(
              key: const Key('sync-flow-field'),
              child: SizedBox(
                width: double.infinity,
                height: 330,
                child: CustomPaint(
                  painter: _DataGatewayPainter(
                    animation: _controller,
                    primary: primary,
                  ),
                ),
              ),
            ),
            Text(
              '正在同步账户状态',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFF2F7FF),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '建立安全连接  ·  聚合账户数据',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8290A6),
                fontSize: 11,
                letterSpacing: 0.75,
              ),
            ),
            const SizedBox(height: 22),
            _SignalSteps(animation: _controller, primary: primary),
          ],
        ),
      ),
    );
  }
}

class _DataGatewayPainter extends CustomPainter {
  _DataGatewayPainter({required this.animation, required this.primary})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 2);
    final unit = math.min(size.width, size.height) / 330;
    final phase = animation.value;
    final wave = (math.sin(phase * math.pi * 2) + 1) / 2;

    _drawAtmosphere(canvas, center, unit, wave);
    _drawPerspectiveGrid(canvas, size, center, unit);
    _drawOuterGate(canvas, center, unit, phase);
    _drawDataRails(canvas, center, unit, phase);
    _drawEnergySphere(canvas, center, unit, phase, wave);
    _drawPackets(canvas, center, unit, phase);
  }

  void _drawAtmosphere(Canvas canvas, Offset center, double unit, double wave) {
    final radius = 150 * unit;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: 0.12 + wave * 0.025),
            AppTheme.violet.withValues(alpha: 0.045),
            Colors.transparent,
          ],
          stops: const [0, 0.46, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawPerspectiveGrid(
    Canvas canvas,
    Size size,
    Offset center,
    double unit,
  ) {
    for (var i = -4; i <= 4; i++) {
      final offset = i * 26 * unit;
      final xTop = center.dx + offset * 0.34;
      final yTop = center.dy - 104 * unit;
      final xBottom = center.dx + offset;
      final yBottom = center.dy + 112 * unit;
      canvas.drawLine(
        Offset(xTop, yTop),
        Offset(xBottom, yBottom),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7 * unit
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary.withValues(alpha: 0.02),
              primary.withValues(alpha: 0.08),
            ],
          ).createShader(Rect.fromLTRB(xTop, yTop, xBottom, yBottom)),
      );
    }
    for (var i = 0; i < 6; i++) {
      final y = center.dy - 82 * unit + i * 35 * unit;
      final spread = 42 * unit + i * 22 * unit;
      final alpha = 0.025 + i * 0.015;
      canvas.drawLine(
        Offset(center.dx - spread, y),
        Offset(center.dx + spread, y),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7 * unit
          ..color = primary.withValues(alpha: alpha),
      );
    }
  }

  void _drawOuterGate(Canvas canvas, Offset center, double unit, double phase) {
    for (var i = 0; i < 3; i++) {
      final scale = 1 - i * 0.17;
      final alpha = 0.24 - i * 0.055;
      final gate = _hexagon(center, 116 * unit * scale, 82 * unit * scale);
      canvas.drawPath(
        gate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.15 - i * 0.16) * unit
          ..color = primary.withValues(alpha: alpha),
      );
    }

    final scan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * unit
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(phase * math.pi * 2),
        colors: [
          Colors.transparent,
          primary.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.9),
          primary,
          Colors.transparent,
        ],
        stops: const [0, 0.46, 0.54, 0.64, 1],
      ).createShader(Rect.fromCircle(center: center, radius: 116 * unit));
    canvas.drawPath(_hexagon(center, 116 * unit, 82 * unit), scan);
  }

  void _drawDataRails(Canvas canvas, Offset center, double unit, double phase) {
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * unit
      ..color = primary.withValues(alpha: 0.22);
    for (final direction in [-1.0, 1.0]) {
      for (var lane = -1; lane <= 1; lane++) {
        final path = Path()
          ..moveTo(
            center.dx + direction * 164 * unit,
            center.dy + lane * 28 * unit,
          )
          ..lineTo(
            center.dx + direction * 82 * unit,
            center.dy + lane * 18 * unit,
          )
          ..lineTo(
            center.dx + direction * 49 * unit,
            center.dy + lane * 12 * unit,
          );
        canvas.drawPath(path, rail);

        final rawT = (phase * (0.72 + lane.abs() * 0.12) + lane * 0.16) % 1;
        final t = Curves.easeInQuad.transform(rawT);
        final metric = path.computeMetrics().first;
        final tangent = metric.getTangentForOffset(metric.length * t);
        if (tangent == null) continue;
        final glowSize = (5 + t * 4) * unit;
        canvas.drawCircle(
          tangent.position,
          glowSize,
          Paint()
            ..color = primary.withValues(alpha: 0.25 + t * 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSize),
        );
        canvas.drawCircle(
          tangent.position,
          (1.8 + t * 0.8) * unit,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawEnergySphere(
    Canvas canvas,
    Offset center,
    double unit,
    double phase,
    double wave,
  ) {
    final radius = 50 * unit;
    final orbitRadius = radius * 1.5;
    const orbitVerticalScale = 0.32;
    final orbitRotation = -0.32 + math.sin(phase * math.pi * 2) * 0.05;

    final auraRadius = radius * (1.65 + wave * 0.1);
    canvas.drawCircle(
      center,
      auraRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: 0.35 + wave * 0.08),
            AppTheme.violet.withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: auraRadius)),
    );

    _drawTiltedOrbit(
      canvas,
      center: center,
      radius: orbitRadius,
      rotation: orbitRotation,
      verticalScale: orbitVerticalScale,
      primary: primary,
      front: false,
    );
    _drawOrbitFlare(
      canvas,
      center: center,
      radius: orbitRadius,
      rotation: orbitRotation,
      verticalScale: orbitVerticalScale,
      phase: phase,
      unit: unit,
      primary: primary,
      front: false,
    );

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * unit
      ..strokeCap = StrokeCap.round
      ..color = primary.withValues(alpha: 0.32);
    for (var index = 0; index < 14; index++) {
      final start = -phase * math.pi * 2 + index * math.pi * 2 / 14;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 1.18),
        start,
        math.pi / 28,
        false,
        dashPaint,
      );
    }

    final globeRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.08,
      Paint()
        ..color = primary.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * unit),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.38),
          radius: 1.08,
          colors: [
            Color.lerp(primary, Colors.white, 0.45)!,
            primary.withValues(alpha: 0.8),
            const Color(0xFF142046),
            const Color(0xFF070B18),
          ],
          stops: const [0, 0.3, 0.68, 1],
        ).createShader(globeRect),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(globeRect));
    _drawSphereWireframe(
      canvas,
      center: center,
      radius: radius,
      unit: unit,
      phase: phase,
    );
    _drawSphereScan(
      canvas,
      center: center,
      radius: radius,
      unit: unit,
      phase: phase,
    );
    _drawSphereGloss(canvas, center: center, radius: radius, unit: unit);
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * unit
        ..shader = SweepGradient(
          colors: [primary, AppTheme.violet, AppTheme.magenta, primary],
        ).createShader(globeRect),
    );

    _drawTiltedOrbit(
      canvas,
      center: center,
      radius: orbitRadius,
      rotation: orbitRotation,
      verticalScale: orbitVerticalScale,
      primary: primary,
      front: true,
    );
    _drawOrbitFlare(
      canvas,
      center: center,
      radius: orbitRadius,
      rotation: orbitRotation,
      verticalScale: orbitVerticalScale,
      phase: phase,
      unit: unit,
      primary: primary,
      front: true,
    );
  }

  void _drawSphereWireframe(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double unit,
    required double phase,
  }) {
    final lineWidth = math.max(0.6, 0.85 * unit);
    final meridianPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..color = primary.withValues(alpha: 0.45);
    final latitudePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.violet.withValues(alpha: 0.4);

    for (var index = -2; index <= 2; index++) {
      if (index == 0) continue;
      final latitude = index * 0.38;
      final width =
          radius * 2 * math.sqrt(math.max(0.08, 1 - latitude * latitude));
      final height = radius * (0.18 + (1 - latitude.abs()) * 0.12);
      final rect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + latitude * radius),
        width: width,
        height: height,
      );
      canvas.drawOval(rect, latitudePaint);
    }

    for (var index = -2; index <= 2; index++) {
      final angle = phase * math.pi * 2 + index * math.pi / 3;
      final width =
          radius * 2 * math.max(0.06, math.cos(angle).abs()).toDouble();
      final rect = Rect.fromCenter(
        center: center,
        width: width,
        height: radius * 2.05,
      );
      canvas.drawOval(rect, meridianPaint);
    }
  }

  void _drawSphereScan(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double unit,
    required double phase,
  }) {
    final scanAngle = phase * math.pi * 2.8 - math.pi / 2;
    final scanPoint =
        center +
        Offset(
          math.cos(scanAngle) * radius * 0.78,
          math.sin(scanAngle) * radius * 0.78,
        );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      scanAngle - 0.5,
      0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4 * unit
        ..color = primary.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 * unit),
    );
    canvas.drawCircle(
      scanPoint,
      3.8 * unit,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.2 * unit),
    );
    canvas.drawCircle(scanPoint, 1.5 * unit, Paint()..color = Colors.white);
  }

  void _drawSphereGloss(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double unit,
  }) {
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.36),
          primary.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.28, -radius * 0.28),
        width: radius * 0.76,
        height: radius * 0.35,
      ),
      highlight,
    );
  }

  void _drawTiltedOrbit(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double rotation,
    required double verticalScale,
    required Color primary,
    required bool front,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(1, verticalScale);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.085
      ..shader = SweepGradient(
        colors: [primary, AppTheme.violet, AppTheme.magenta, primary],
      ).createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.1);
    final crispPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.038
      ..shader = SweepGradient(
        colors: [primary, AppTheme.violet, AppTheme.magenta, primary],
      ).createShader(rect);

    if (front) {
      canvas.drawArc(rect, 0, math.pi, false, glowPaint);
      canvas.drawArc(rect, 0, math.pi, false, crispPaint);
    } else {
      canvas.drawArc(rect, math.pi, math.pi, false, glowPaint);
      canvas.drawArc(rect, math.pi, math.pi, false, crispPaint);
    }
    canvas.restore();
  }

  void _drawOrbitFlare(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double rotation,
    required double verticalScale,
    required double phase,
    required double unit,
    required Color primary,
    required bool front,
  }) {
    for (var i = 0; i < 2; i++) {
      final flareAngle = (phase * math.pi * 2 + i * math.pi) % (math.pi * 2);
      final isFront = math.sin(flareAngle) >= 0;
      if (isFront != front) continue;

      final dx0 = math.cos(flareAngle) * radius;
      final dy0 = math.sin(flareAngle) * radius * verticalScale;
      final flarePoint =
          center +
          Offset(
            dx0 * math.cos(rotation) - dy0 * math.sin(rotation),
            dx0 * math.sin(rotation) + dy0 * math.cos(rotation),
          );

      final color = i == 0 ? primary : AppTheme.violet;
      canvas.drawCircle(
        flarePoint,
        5.2 * unit,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.5 * unit),
      );
      canvas.drawCircle(flarePoint, 1.8 * unit, Paint()..color = Colors.white);
    }
  }

  void _drawPackets(Canvas canvas, Offset center, double unit, double phase) {
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + phase * math.pi * 0.32;
      final radius = (91 + (i.isEven ? 12 : 0)) * unit;
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.72);
      final alpha = 0.18 + 0.32 * ((math.sin(angle + phase * 6) + 1) / 2);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 8 * unit,
            height: 3 * unit,
          ),
          Radius.circular(1.5 * unit),
        ),
        Paint()..color = primary.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  Path _hexagon(Offset center, double width, double height) => Path()
    ..moveTo(center.dx, center.dy - height)
    ..lineTo(center.dx + width * 0.78, center.dy - height * 0.5)
    ..lineTo(center.dx + width, center.dy + height * 0.22)
    ..lineTo(center.dx + width * 0.45, center.dy + height)
    ..lineTo(center.dx - width * 0.45, center.dy + height)
    ..lineTo(center.dx - width, center.dy + height * 0.22)
    ..lineTo(center.dx - width * 0.78, center.dy - height * 0.5)
    ..close();

  @override
  bool shouldRepaint(covariant _DataGatewayPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.primary != primary;
}

class _SignalSteps extends StatelessWidget {
  const _SignalSteps({required this.animation, required this.primary});

  final Animation<double> animation;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('sync-flow-dots'),
      width: 78,
      height: 12,
      child: CustomPaint(
        painter: _SignalStepsPainter(animation: animation, primary: primary),
      ),
    );
  }
}

class _SignalStepsPainter extends CustomPainter {
  _SignalStepsPainter({required this.animation, required this.primary})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final active = (animation.value * 4).floor() % 4;
    for (var i = 0; i < 4; i++) {
      final isActive = i == active;
      final width = isActive ? 19.0 : 10.0;
      final rect = Rect.fromCenter(
        center: Offset(10 + i * 19.5, size.height / 2),
        width: width,
        height: 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..color = isActive
              ? primary.withValues(alpha: 0.95)
              : primary.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalStepsPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.primary != primary;
}
