import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/pressable.dart';
import 'profile_cover.dart';

/// Обложка во всю ширину и квадратная аватарка «внахлёст» слева.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.cover,
    this.avatarUrl,
    this.topActions = const [],
    this.avatarBadge,
    this.onAvatarTap,
    this.avatarLoading = false,
  });

  final String name;
  final ProfileCover cover;
  final String? avatarUrl;
  final List<Widget> topActions;
  final Widget? avatarBadge;
  final VoidCallback? onAvatarTap;
  final bool avatarLoading;

  static const _coverHeight = 190.0;
  static const _avatar = 108.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + _coverHeight + _avatar / 2 + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: top + _coverHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.xl + 8)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, if (current != null) current],
                ),
                child: CoverArt(key: ValueKey(cover.encode()), cover: cover),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Row(children: topActions),
          ),
          Positioned(
            top: top + _coverHeight - _avatar / 2,
            left: 20,
            child: FadeSlideIn(
              child: GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SpinningRing(
                      radius: _avatar * 0.3 + 6,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AppAvatar(
                              url: avatarUrl,
                              name: name,
                              size: _avatar,
                              square: true),
                          if (avatarLoading)
                            Container(
                              width: _avatar,
                              height: _avatar,
                              decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius:
                                      BorderRadius.circular(_avatar * 0.3)),
                              padding: const EdgeInsets.all(38),
                              child: const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.6),
                            ),
                        ],
                      ),
                    ),
                    if (avatarBadge != null)
                      Positioned(right: -6, bottom: -6, child: avatarBadge!),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка поверх обложки: полупрозрачный тёмный квадрат.
class CoverButton extends StatelessWidget {
  const CoverButton({super.key, required this.icon, this.label, this.onTap});
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        width: label == null ? 40 : null,
        child: PhotoGlass(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.cream, size: 20),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label!,
                    style: context.text.labelMedium?.copyWith(
                        color: AppColors.cream, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Журнальная статистика: крупное число и подпись, между блоками — линии.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.items});
  final List<({String value, String label, VoidCallback? onTap})> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Glass(
      radius: AppRadius.lg,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(width: 1, thickness: 1, color: p.border),
              Expanded(
                child: Pressable(
                  scale: 0.94,
                  onTap: items[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        CountUpText(items[i].value,
                            style: context.text.headlineLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(items[i].label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                                color: p.textSecondary,
                                letterSpacing: 0.8,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
