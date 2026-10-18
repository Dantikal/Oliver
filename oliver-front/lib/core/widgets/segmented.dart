import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Сегментированный контрол со скользящей «пилюлей».
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.height = 48,
    this.badgeOf,
  });

  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final int Function(T)? badgeOf;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index = items.indexOf(value).clamp(0, items.length - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration:
          BoxDecoration(color: p.surface2, borderRadius: AppRadius.pillAll),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / items.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutBack,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: AppRadius.pillAll,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(item);
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                style: context.text.labelMedium!.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: item == value
                                      ? Colors.white
                                      : p.textSecondary,
                                ),
                                child: Text(labelOf(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            if (badgeOf != null && badgeOf!(item) > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: item == value
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : AppColors.leaf,
                                  borderRadius: AppRadius.pillAll,
                                ),
                                child: Text('${badgeOf!(item)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
