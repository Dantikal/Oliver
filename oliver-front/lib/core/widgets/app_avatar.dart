import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_image.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar(
      {super.key,
      this.url,
      required this.name,
      this.size = 48,
      this.online = false,
      this.ring = false,
      this.square = false});

  final String? url;
  final String name;
  final double size;
  final bool online;
  final bool ring;

  /// Скруглённый квадрат (профиль) вместо круга.
  final bool square;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return parts.isEmpty
        ? '?'
        : parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        AppColors.accents[name.hashCode.abs() % AppColors.accents.length];
    final Widget box = SizedBox(
      width: size,
      height: size,
      child: url != null && url!.isNotEmpty
          ? AppImage(url)
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.6)]),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.36),
                ),
              ),
            ),
    );
    Widget avatar = square
        ? ClipRRect(borderRadius: BorderRadius.circular(size * 0.3), child: box)
        : ClipOval(child: box);
    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: AppColors.brandGradient),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor),
          child: avatar,
        ),
      );
    }
    if (!online) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: size * 0.27,
            height: size * 0.27,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}
