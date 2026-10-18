import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'app_button.dart';
import 'motion.dart';

enum SnackType { success, error, info }

String errorText(BuildContext c, Object? e) {
  if (e is ApiException) {
    if (e.isNetwork) return c.tr('errNetwork');
    if (e.message == 'generic') return c.tr('errGeneric');
    return e.message;
  }
  return c.tr('errGeneric');
}

extension SnackX on BuildContext {
  void showSnack(String message, {SnackType type = SnackType.info}) {
    final (icon, color) = switch (type) {
      SnackType.success => (Icons.check_rounded, AppColors.success),
      SnackType.error => (Icons.priority_high_rounded, AppColors.danger),
      SnackType.info => (Icons.info_outline_rounded, AppColors.primary),
    };
    if (type == SnackType.error) HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 2600),
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ));
  }

  void showError(Object? e) =>
      showSnack(errorText(this, e), type: SnackType.error);
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final p = context.palette;
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack);
      return FadeTransition(
          opacity: a,
          child: ScaleTransition(
              scale: Tween(begin: 0.88, end: 1.0).animate(c), child: child));
    },
    pageBuilder: (ctx, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Material(
          color: p.surface,
          borderRadius: AppRadius.xlAll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (destructive ? AppColors.danger : AppColors.primary)
                        .withValues(alpha: 0.12),
                  ),
                  child: Icon(icon,
                      size: 30,
                      color:
                          destructive ? AppColors.danger : AppColors.primary),
                ),
                const SizedBox(height: 18),
                Text(title,
                    textAlign: TextAlign.center, style: ctx.text.headlineSmall),
                const SizedBox(height: 10),
                Text(message,
                    textAlign: TextAlign.center,
                    style:
                        ctx.text.bodyMedium?.copyWith(color: p.textSecondary)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: ctx.tr('cancel'),
                        variant: AppButtonVariant.secondary,
                        height: 52,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: confirm,
                        variant: destructive
                            ? AppButtonVariant.danger
                            : AppButtonVariant.primary,
                        height: 52,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return r ?? false;
}

/// Иллюстрированное пустое состояние (без растровых ассетов).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
    this.gradient = AppColors.brandGradient,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: 0.6 + v * 0.4, child: child),
            child: SizedBox(
              width: 180,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 50,
                            spreadRadius: 4),
                      ],
                    ),
                  ),
                  Breathing(
                    period: const Duration(milliseconds: 2600),
                    builder: (_, t, child) => Transform.translate(
                        offset: Offset(0, -6 * t),
                        child: Transform.rotate(
                            angle: -0.14 + 0.06 * t, child: child)),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: AppRadius.xlAll,
                        border: Border.all(color: p.border),
                        boxShadow: [
                          BoxShadow(
                              color: p.shadow,
                              blurRadius: 30,
                              offset: const Offset(0, 14))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 46, color: AppColors.primary),
                    ),
                  ),
                  const Positioned(
                      top: 8,
                      right: 18,
                      child: _Dot(size: 14, color: AppColors.lime)),
                  const Positioned(
                      bottom: 18,
                      left: 10,
                      child: _Dot(size: 10, color: AppColors.mint)),
                  const Positioned(
                      top: 30,
                      left: 6,
                      child: _Dot(size: 7, color: AppColors.teal)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(title,
              textAlign: TextAlign.center, style: context.text.headlineSmall),
          const SizedBox(height: 10),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
          if (action != null) ...[
            const SizedBox(height: 24),
            AppButton(
                label: action!, onPressed: onAction, expand: false, height: 52),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final net = error is ApiException && (error as ApiException).isNetwork;
    return EmptyState(
      icon: net ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: net ? context.tr('errNetworkTitle') : context.tr('errTitle'),
      subtitle: errorText(context, error),
      action: context.tr('retry'),
      onAction: onRetry,
      gradient: AppColors.leafGradient,
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.small = false});
  final int count;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: count <= 0
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(count),
              constraints: BoxConstraints(minWidth: small ? 18 : 22),
              height: small ? 18 : 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: AppRadius.pillAll,
                border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: small ? 2 : 0),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 10 : 12,
                    fontWeight: FontWeight.w800),
              ),
            ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(this.text,
      {super.key, this.style, this.gradient = AppColors.brandGradient});
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) =>
            gradient.createShader(Rect.fromLTWH(0, 0, r.width, r.height)),
        child: Text(text, style: style),
      );
}
