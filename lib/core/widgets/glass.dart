import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Матовое стекло: размытие фона + полупрозрачная заливка + тонкий блик по краю.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
    this.blur = 22,
    this.tint,
    this.padding,
    this.shadow = true,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final double blur;

  /// Цвет заливки; по умолчанию — `palette.glass`.
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = BorderRadius.circular(radius);
    final edge = context.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.75);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow ? AppShadows.soft(p.shadow) : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(color: tint ?? p.glass, borderRadius: r),
            // Блик и ободок — слоем поверх: градиент в decoration заменил бы
            // заливку, а рамка в decoration добавила бы к размеру свою толщину.
            foregroundDecoration: BoxDecoration(
              borderRadius: r,
              border: border ? Border.all(color: edge, width: 1) : null,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: context.isDark ? 0.05 : 0.14),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Тёмное стекло поверх фото (цена, счётчики, кнопки на галерее).
class PhotoGlass extends StatelessWidget {
  const PhotoGlass(
      {super.key,
      required this.child,
      this.radius = AppRadius.pill,
      this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4)});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: r,
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Периодический диагональный блик поверх [child] (для главных кнопок).
class ShineSweep extends StatefulWidget {
  const ShineSweep(
      {super.key,
      required this.child,
      this.period = const Duration(milliseconds: 3600),
      this.enabled = true});
  final Widget child;
  final Duration period;
  final bool enabled;

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        // Блик пробегает за первые 30% периода, дальше пауза.
        final t = (_c.value / 0.3).clamp(0.0, 1.0);
        if (t >= 1) return child!;
        final x = -1.5 + 3.0 * Curves.easeInOut.transform(t);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 0.6, -1),
            end: Alignment(x + 0.6, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Кольцо с вращающимся градиентом бренда вокруг [child] (аватарки и т.п.).
class SpinningRing extends StatefulWidget {
  const SpinningRing(
      {super.key,
      required this.child,
      this.radius,
      this.width = 3,
      this.gap = 3,
      this.period = const Duration(seconds: 6)});
  final Widget child;

  /// null — круг.
  final double? radius;
  final double width;
  final double gap;
  final Duration period;

  @override
  State<SpinningRing> createState() => _SpinningRingState();
}

class _SpinningRingState extends State<SpinningRing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.radius == null;
    final outer = circle ? null : BorderRadius.circular(widget.radius!);
    final inner = circle
        ? null
        : BorderRadius.circular(
            (widget.radius! - widget.width).clamp(0, double.infinity));
    return AnimatedBuilder(
      animation: _c,
      child: Container(
        padding: EdgeInsets.all(widget.gap),
        decoration: BoxDecoration(
          color: context.palette.bg,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: inner,
        ),
        child: widget.child,
      ),
      builder: (_, child) => Container(
        padding: EdgeInsets.all(widget.width),
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: outer,
          gradient: SweepGradient(
            transform: GradientRotation(_c.value * 6.283185),
            colors: const [
              AppColors.lime,
              AppColors.primary,
              AppColors.teal,
              AppColors.mint,
              AppColors.lime,
            ],
          ),
          boxShadow: AppShadows.glow(AppColors.primary, strength: 0.7),
        ),
        child: child,
      ),
    );
  }
}
