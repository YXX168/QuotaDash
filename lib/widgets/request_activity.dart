import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/request_bucket.dart';
import '../theme/app_theme.dart';

class RequestSparkline extends StatelessWidget {
  const RequestSparkline({required this.buckets, super.key, this.height = 72});

  final List<RequestBucket> buckets;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _RequestSparklinePainter(buckets)),
    );
  }
}

class ResetCountdown extends StatefulWidget {
  const ResetCountdown({required this.target, super.key, this.prefix = '距重置'});

  final DateTime? target;
  final String prefix;

  @override
  State<ResetCountdown> createState() => _ResetCountdownState();
}

class _ResetCountdownState extends State<ResetCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ResetCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.target == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.target!.isBefore(DateTime.now())) {
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target == null) {
      return Text('重置时间未知', style: Theme.of(context).textTheme.bodySmall);
    }
    final difference = target.difference(DateTime.now());
    final remaining = difference.isNegative ? Duration.zero : difference;
    // Past the reset moment the countdown would otherwise freeze at zero
    // forever; show an explicit placeholder instead until fresh data
    // arrives with the next window.
    if (difference.isNegative) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            size: 13,
            color: AppTheme.cyan,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${widget.prefix}待刷新',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9EABC2)),
            ),
          ),
        ],
      );
    }
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    final value = days > 0
        ? '$days天 ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}'
        : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 13, color: AppTheme.cyan),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${widget.prefix} $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9EABC2),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestSparklinePainter extends CustomPainter {
  const _RequestSparklinePainter(this.buckets);

  final List<RequestBucket> buckets;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x182F4868)
      ..strokeWidth = 0.7;
    for (var index = 1; index < 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (buckets.isEmpty) return;

    final maxValue = math.max<int>(
      1,
      buckets.fold(0, (value, bucket) => math.max(value, bucket.total)),
    );
    final step = buckets.length <= 1
        ? size.width
        : size.width / (buckets.length - 1);
    final line = Path();
    for (var index = 0; index < buckets.length; index++) {
      final x = index * step;
      final y =
          size.height -
          (buckets[index].total / maxValue * (size.height - 8)) -
          4;
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x5555DDF4), Color(0x0055DDF4)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..shader = LinearGradient(
          colors: [
            AppTheme.cyan.withValues(alpha: 0.24),
            AppTheme.violet.withValues(alpha: 0.2),
            AppTheme.magenta.withValues(alpha: 0.18),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          colors: [AppTheme.cyan, AppTheme.violet, AppTheme.magenta],
        ).createShader(Offset.zero & size),
    );

    final failurePaint = Paint()..color = AppTheme.danger;
    final failureGlow = Paint()
      ..color = AppTheme.danger.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var index = 0; index < buckets.length; index++) {
      if (buckets[index].failed == 0) continue;
      final x = index * step;
      final y =
          size.height -
          (buckets[index].total / maxValue * (size.height - 8)) -
          4;
      canvas.drawCircle(Offset(x, y), 5, failureGlow);
      canvas.drawCircle(Offset(x, y), 2.5, failurePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RequestSparklinePainter oldDelegate) {
    return oldDelegate.buckets != buckets;
  }
}
