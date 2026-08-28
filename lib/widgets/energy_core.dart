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

    return Semantics(
      button: widget.onTap != null,
      label: '${account.name}，$label $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 226,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xD8172236), Color(0xC40C1323)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    key: const Key('energy-orb'),
                    child: CustomPaint(
                      painter: _EnergyPainter(
                        animation: _controller,
                        color: color,
                        progress: (remaining ?? 0).clamp(0, 100) / 100,
                        hasError: account.hasError,
                        refreshing: widget.refreshing,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    key: const Key('energy-foreground'),
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: color, blurRadius: 7),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              account.name.isEmpty ? '未命名账号' : account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              account.plan.isEmpty
                                  ? 'CODEX'
                                  : account.plan.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: color.withValues(alpha: 0.9),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: 27,
                              shadows: [Shadow(color: color, blurRadius: 16)],
                            ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.95),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: _QuotaReading(
                              key: const Key('energy-quota-line-primary'),
                              label: account.primaryLabel,
                              remaining: account.primary?.remainingPercent,
                            ),
                          ),
                          if (account.secondary != null) ...[
                            Container(
                              width: 1,
                              height: 25,
                              margin: const EdgeInsets.symmetric(horizontal: 9),
                              color: const Color(0x332D3C55),
                            ),
                            Expanded(
                              child: _QuotaReading(
                                key: const Key('energy-quota-line-secondary'),
                                label: account.secondaryLabel,
                                remaining:
                                    account.secondary?.remainingPercent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        account.email.isEmpty ? 'Codex Account' : account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
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
  const _QuotaReading({required this.label, required this.remaining, super.key});

  final String label;
  final double? remaining;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          remaining == null ? '--' : '${remaining!.toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8),
        ),
      ],
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
    final center = Offset(size.width / 2, size.height / 2 - 2);
    final phase = animation.value;
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    final radius = 40.0 + pulse * 2.5;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.28),
          color.withValues(alpha: 0.68),
          color.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0, 0.27, 0.64, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));
    canvas.drawCircle(center, radius * 1.3, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.85);
    final rotation = phase * math.pi * 2 * (refreshing ? 2.4 : 0.45);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 53),
      rotation - math.pi / 2,
      math.pi * 2 * progress,
      false,
      ring,
    );

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: 0.24);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotation * 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 126, height: 70),
      orbit,
    );
    canvas.drawCircle(
      const Offset(60, 0),
      hasError ? 4.2 : 2.4,
      Paint()..color = hasError ? AppTheme.danger : color,
    );
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
