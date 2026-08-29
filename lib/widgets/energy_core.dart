import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/codex_account.dart';
import '../theme/app_theme.dart';

class EnergyAccountCore extends StatefulWidget {
  const EnergyAccountCore({
    required this.account,
    required this.refreshing,
    super.key,
    this.onTap,
  });

  final CodexAccount account;
  final bool refreshing;
  final VoidCallback? onTap;

  @override
  State<EnergyAccountCore> createState() => _EnergyAccountCoreState();
}

class _EnergyAccountCoreState extends State<EnergyAccountCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final remaining = account.averageRemainingPercent;
    final color = _coreColor(account, remaining);
    final value = account.hasError
        ? '!'
        : remaining == null
        ? '--'
        : '${remaining.toStringAsFixed(0)}%';
    final label = account.hasError ? '检查失败' : '综合剩余';

    return UnconstrainedBox(
      alignment: Alignment.topCenter,
      constrainedAxis: Axis.horizontal,
      child: SizedBox(
        key: const Key('energy-core-card'),
        width: double.infinity,
        height: 218,
        child: Semantics(
          button: widget.onTap != null,
          label: account.name + '，' + label + ' ' + value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xF0182235), Color(0xF00A1020)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.32)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  key: const Key('energy-foreground'),
                  children: [
                    SizedBox(
                      key: const Key('energy-header'),
                      height: 30,
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              color: color,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              account.name.isEmpty ? '未命名账号' : account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 82),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              account.plan.isEmpty
                                  ? 'CODEX'
                                  : account.plan.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            key: const Key('energy-orb'),
                            width: 116,
                            height: double.infinity,
                            child: ClipRect(
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: _EnergyPainter(
                                          animation: _controller,
                                          color: color,
                                          progress:
                                              (remaining ?? 0).clamp(0, 100) /
                                              100,
                                          hasError: account.hasError,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontSize: 25,
                                              height: 1,
                                              shadows: [
                                                Shadow(
                                                  color: color,
                                                  blurRadius: 15,
                                                ),
                                              ],
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: color.withValues(alpha: 0.95),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              key: const Key('energy-quota-row'),
                              children: [
                                Expanded(
                                  child: _QuotaReading(
                                    key: const Key('energy-quota-line-primary'),
                                    label: account.primaryLabel,
                                    remaining:
                                        account.primary?.remainingPercent,
                                    color: color,
                                  ),
                                ),
                                if (account.secondary != null) ...[
                                  const SizedBox(height: 7),
                                  Expanded(
                                    child: _QuotaReading(
                                      key: const Key(
                                        'energy-quota-line-secondary',
                                      ),
                                      label: account.secondaryLabel,
                                      remaining:
                                          account.secondary?.remainingPercent,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      key: const Key('energy-account-email'),
                      height: 18,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.alternate_email_rounded,
                            size: 12,
                            color: Color(0xFF71809A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              account.email.isEmpty
                                  ? 'Codex Account'
                                  : account.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 9.5),
                            ),
                          ),
                          if (widget.onTap != null)
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: Color(0xFF71809A),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _coreColor(CodexAccount account, double? remaining) {
    if (account.hasError) return AppTheme.danger;
    if (!account.isAvailable) return AppTheme.warning;
    if (remaining == null) return AppTheme.cyan;
    if (remaining <= 15) return AppTheme.danger;
    if (remaining <= 35) return AppTheme.warning;
    if (remaining <= 65) return AppTheme.violet;
    return AppTheme.cyan;
  }
}

class _QuotaReading extends StatelessWidget {
  const _QuotaReading({
    required this.label,
    required this.remaining,
    required this.color,
    super.key,
  });

  final String label;
  final double? remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = ((remaining ?? 0) / 100).clamp(0.0, 1.0).toDouble();
    final valueColor = remaining == null
        ? const Color(0xFF71809A)
        : remaining! <= 15
        ? AppTheme.danger
        : remaining! <= 35
        ? AppTheme.warning
        : color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0x64131D30),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: valueColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 8.5),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                remaining == null ? '--' : remaining!.toStringAsFixed(0) + '%',
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFF1C2940)),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: ColoredBox(color: valueColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyPainter extends CustomPainter {
  _EnergyPainter({
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
    final phase = animation.value;
    final center = Offset(size.width / 2, size.height / 2 - 2);
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    final ringRadius = math.min(
      53.0,
      math.min(size.width * 0.37, size.height * 0.38),
    );
    final glowRadius = ringRadius * (1.28 + pulse * 0.06);
    final rotation = phase * math.pi * 2 * (refreshing ? 2.4 : 0.45);
    final progressValue = progress.clamp(0.0, 1.0).toDouble();

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.28),
          color.withValues(alpha: 0.68),
          color.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0, 0.27, 0.64, 1],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glow);

    final coreRadius = ringRadius * (0.38 + pulse * 0.025);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Colors.white.withValues(alpha: 0.96),
            color,
            color.withValues(alpha: 0.38),
          ],
          stops: const [0, 0.42, 1],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.34);
    for (var index = 0; index < 14; index++) {
      final start = -rotation * 0.42 + index * math.pi * 2 / 14;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius * 0.72),
        start,
        math.pi / 24,
        false,
        dashPaint,
      );
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: hasError ? 0.28 : 0.85);
    if (hasError || progressValue <= 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        0,
        math.pi * 2,
        false,
        ring,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        rotation - math.pi / 2,
        math.pi * 2 * progressValue,
        false,
        ring,
      );
    }

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: 0.24);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotation * 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: ringRadius * 2.38,
        height: ringRadius * 1.32,
      ),
      orbit,
    );
    canvas.drawCircle(
      Offset(ringRadius * 1.13, 0),
      hasError ? 4.2 : 2.4,
      Paint()..color = hasError ? AppTheme.danger : color,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnergyPainter oldDelegate) {
    return animation != oldDelegate.animation ||
        color != oldDelegate.color ||
        progress != oldDelegate.progress ||
        hasError != oldDelegate.hasError ||
        refreshing != oldDelegate.refreshing;
  }
}
