import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Универсальный bottom sheet для выбора одного значения из списка.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  bool Function(T)? isSelected,
  Widget? Function(T)? leading,
  String? Function(T)? subtitleOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final p = ctx.palette;
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Text(title, style: ctx.text.headlineSmall),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final selected = isSelected?.call(item) ?? false;
                  final lead = leading?.call(item);
                  final sub = subtitleOf?.call(item);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: AppRadius.mdAll,
                      child: InkWell(
                        borderRadius: AppRadius.mdAll,
                        onTap: () => Navigator.pop(ctx, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: Row(
                            children: [
                              if (lead != null) ...[
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: p.surface2,
                                      borderRadius: AppRadius.mdAll),
                                  child: lead,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(labelOf(item),
                                        style: ctx.text.titleSmall?.copyWith(
                                          fontSize: 15.5,
                                          color: selected
                                              ? AppColors.primary
                                              : p.text,
                                        )),
                                    if (sub != null)
                                      Text(sub, style: ctx.text.bodySmall),
                                  ],
                                ),
                              ),
                              AnimatedScale(
                                scale: selected ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
