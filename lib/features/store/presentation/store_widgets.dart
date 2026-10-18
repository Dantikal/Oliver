import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/pressable.dart';
import '../../profile/presentation/profile_cover.dart';

/// Иконки для отделов: свои + иконки категорий.
const kStoreIcons = [
  'tag', 'star', 'sale', 'new', 'gift', 'bolt', 'box', 'leaf', //
  'phone', 'car', 'home', 'clothes', 'furniture', 'hobby', 'pets',
  'services', 'livestock',
];

IconData storeIcon(String key) => switch (key) {
      'tag' => Icons.sell_outlined,
      'star' => Icons.star_outline_rounded,
      'sale' => Icons.percent_rounded,
      'new' => Icons.fiber_new_outlined,
      'gift' => Icons.card_giftcard_rounded,
      'bolt' => Icons.bolt_rounded,
      'box' => Icons.inventory_2_outlined,
      'leaf' => Icons.eco_outlined,
      _ => categoryIcon(key),
    };

/// Шапка магазина: обложка, квадратный логотип, название и описание.
class StoreHeader extends StatelessWidget {
  const StoreHeader({
    super.key,
    required this.cover,
    required this.name,
    required this.ownerName,
    this.avatarUrl,
    this.description = '',
    this.chips = const [],
    this.topActions = const [],
  });

  final ProfileCover cover;
  final String name;
  final String ownerName;
  final String? avatarUrl;
  final String description;
  final List<String> chips;
  final List<Widget> topActions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    const coverH = 150.0, logo = 84.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: top + coverH + logo / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                  height: top + coverH,
                  width: double.infinity,
                  child: CoverArt(cover: cover)),
              Positioned(
                  top: top + 8,
                  left: 12,
                  right: 12,
                  child: Row(children: topActions)),
              Positioned(
                left: 20,
                top: top + coverH - logo / 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration:
                      BoxDecoration(color: p.bg, shape: BoxShape.circle),
                  child: AppAvatar(
                      url: avatarUrl,
                      name: ownerName,
                      size: logo,
                      square: true),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(context.tr('store').toUpperCase(),
                      style: context.text.labelSmall?.copyWith(
                          color: p.textSecondary, letterSpacing: 1.4)),
                ],
              ),
              const SizedBox(height: 4),
              Text(name,
                  style: context.text.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.05)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description,
                    style: context.text.bodyMedium?.copyWith(
                        color: p.textSecondary, fontStyle: FontStyle.italic)),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: p.surface2, borderRadius: AppRadius.pillAll),
                        child: Text(c,
                            style: context.text.labelSmall?.copyWith(
                                color: p.text, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Тёмная полупрозрачная кнопка поверх обложки.
class OverCoverButton extends StatelessWidget {
  const OverCoverButton(
      {super.key, required this.icon, this.label, required this.onTap});
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          height: 40,
          width: label == null ? 40 : null,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
          decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.55),
              borderRadius: AppRadius.pillAll),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.cream, size: 19),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label!,
                    style: context.text.labelMedium?.copyWith(
                        color: AppColors.cream, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      );
}

/// Плоский чип-переключатель (вкладки, сортировки).
class FlatChip extends StatelessWidget {
  const FlatChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: selected ? p.text : p.surface2,
            borderRadius: AppRadius.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? p.bg : p.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: context.text.labelMedium?.copyWith(
                    color: selected ? p.bg : p.textSecondary,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Шторка «Новый отдел / Изменить отдел»: название + иконка.
Future<({String name, String icon})?> showSectionSheet(BuildContext context,
    {String? name, String icon = 'tag'}) {
  final c = TextEditingController(text: name);
  var selected = icon;
  return showModalBottomSheet<({String name, String icon})>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final p = ctx.palette;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr(name == null ? 'newSection' : 'edit'),
                  style: ctx.text.headlineSmall),
              const SizedBox(height: 16),
              AppTextField(
                controller: c,
                label: ctx.tr('sectionName'),
                autofocus: name == null,
                prefixIcon: storeIcon(selected),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Text(ctx.tr('sectionIcon').toUpperCase(),
                  style: ctx.text.labelSmall
                      ?.copyWith(color: p.textSecondary, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in kStoreIcons)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        set(() => selected = k);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: k == selected ? AppColors.lime : p.surface2,
                            borderRadius: AppRadius.mdAll),
                        child: Icon(storeIcon(k),
                            size: 21,
                            color: k == selected ? AppColors.ink : p.text),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: ctx.tr('save'),
                onPressed: () {
                  final n = c.text.trim();
                  if (n.isEmpty) return;
                  Navigator.pop(ctx, (name: n, icon: selected));
                },
              ),
            ],
          ),
        );
      },
    ),
  ).whenComplete(c.dispose);
}
