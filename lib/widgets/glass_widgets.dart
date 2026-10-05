import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -150,
            right: -125,
            child: _GlowOrb(size: 340, color: AppTheme.violet, intensity: 0.14),
          ),
          const Positioned(
            top: 120,
            left: -190,
            child: _GlowOrb(size: 330, color: AppTheme.cyan, intensity: 0.065),
          ),
          const Positioned(
            bottom: 80,
            right: -250,
            child: _GlowOrb(
              size: 440,
              color: AppTheme.magenta,
              intensity: 0.045,
            ),
          ),
          const Positioned(
            bottom: -170,
            left: -150,
            child: _GlowOrb(size: 390, color: AppTheme.cyan, intensity: 0.12),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: _BackdropVignette()),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.intensity,
  });

  final double size;
  final Color color;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: intensity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackdropVignette extends StatelessWidget {
  const _BackdropVignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.3,
          colors: [Colors.transparent, Color(0x08000000), Color(0x26000000)],
          stops: [0.42, 0.75, 1],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AppTheme.outline, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? content
          : _PressableGlassSurface(onTap: onTap!, child: content),
    );
  }
}

class _PressableGlassSurface extends StatefulWidget {
  const _PressableGlassSurface({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableGlassSurface> createState() => _PressableGlassSurfaceState();
}

class _PressableGlassSurfaceState extends State<_PressableGlassSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.987 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

class GradientIcon extends StatelessWidget {
  const GradientIcon({
    required this.icon,
    super.key,
    this.size = 48,
    this.iconSize = 24,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          colors: [AppTheme.cyan, AppTheme.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4438E8FF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: AppTheme.background, size: iconSize),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    super.key,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 12,
        vertical: compact ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: compact ? 7 : 10, color: color),
          SizedBox(width: compact ? 4 : 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 9 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
