import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'glass.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, lime, secondary, outline, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.height = 58,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final AppButtonVariant variant;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    final filled =
        variant == AppButtonVariant.primary || variant == AppButtonVariant.lime;
    final fg = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.lime => AppColors.ink,
      AppButtonVariant.danger => AppColors.danger,
      _ => p.text,
    };
    final radius = BorderRadius.circular(height * 0.34);

    return Pressable(
      onTap: enabled ? onPressed : null,
      scale: 0.97,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: filled && enabled
                ? AppShadows.glow(variant == AppButtonVariant.lime
                    ? AppColors.lime
                    : AppColors.primary)
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ShineSweep(
              enabled: filled && enabled,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  gradient: switch (variant) {
                    AppButtonVariant.primary => AppColors.brandGradient,
                    AppButtonVariant.lime => AppColors.limeGradient,
                    _ => null,
                  },
                  color: switch (variant) {
                    AppButtonVariant.secondary => p.surface2,
                    AppButtonVariant.danger =>
                      AppColors.danger.withValues(alpha: 0.1),
                    _ => null,
                  },
                  border: variant == AppButtonVariant.outline
                      ? Border.all(color: p.surface3, width: 1.5)
                      : null,
                  borderRadius: radius,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(
                            scale: Tween(begin: 0.8, end: 1.0).animate(a),
                            child: c)),
                    child: loading
                        ? SizedBox(
                            key: const ValueKey('l'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                strokeCap: StrokeCap.round,
                                color: fg),
                          )
                        : Row(
                            key: const ValueKey('c'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, color: fg, size: 20),
                                const SizedBox(width: 8)
                              ],
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelLarge
                                      ?.copyWith(color: fg),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Круглая кнопка-иконка (glass / surface).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.glass = false,
    this.color,
    this.iconColor,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool glass;
  final Color? color;
  final Color? iconColor;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final icn = Icon(icon,
        size: size * 0.46, color: iconColor ?? (glass ? Colors.white : p.text));
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (glass && color == null)
            SizedBox(
              width: size,
              height: size,
              child: PhotoGlass(
                  padding: EdgeInsets.zero, child: Center(child: icn)),
            )
          else
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color ?? p.surface,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
                boxShadow:
                    color == null ? AppShadows.soft(p.shadow, lift: 0.5) : null,
              ),
              child: icn,
            ),
          if (badge != null) Positioned(top: -2, right: -2, child: badge!),
        ],
      ),
    );
  }
}
