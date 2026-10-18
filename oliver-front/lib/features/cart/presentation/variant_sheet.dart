import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/sound/sfx.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../catalog/domain/product.dart';
import '../data/cart.dart';

/// «#RRGGBB» → Color (без цвета — серый).
Color optionColor(String? hex) {
  final h = (hex ?? '').replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? const Color(0xFF9E9E9E) : Color(v);
}

/// «В корзину» / «Купить»: выбор вариантов и количества.
/// Купить — сразу отправляет заказ продавцу в чат.
Future<void> openBuyFlow(BuildContext context, WidgetRef ref, Product product,
    {required bool buyNow}) async {
  final r = await showModalBottomSheet<(Map<String, String>, int)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VariantSheet(product: product, buyNow: buyNow),
  );
  if (r == null || !context.mounted) return;
  final item = CartItem.fromProduct(product, r.$1, r.$2);
  HapticFeedback.mediumImpact();
  if (buyNow) {
    try {
      await sendOrder(context, ref, [item]);
      if (context.mounted) {
        context.showSnack(context.tr('orderSent'), type: SnackType.success);
      }
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  } else {
    ref.read(cartProvider.notifier).add(item);
    Sfx.cart();
    context.showSnack(context.tr('addedToCart'), type: SnackType.success);
  }
}

class _VariantSheet extends StatefulWidget {
  const _VariantSheet({required this.product, required this.buyNow});
  final Product product;
  final bool buyNow;

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  final Map<String, String> _sel = {};
  int _qty = 1;

  List<ProductOption> get _options => widget.product.options;

  List<String> get _missing => [
        for (final o in _options)
          if (!_sel.containsKey(o.name)) o.name
      ];

  @override
  void initState() {
    super.initState();
    // Единственное значение выбирать не заставляем.
    for (final o in _options) {
      if (o.values.length == 1) _sel[o.name] = o.values.first.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pr = widget.product;
    final total = (pr.price ?? 0) * _qty;
    final missing = _missing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.mdAll,
                      child: SizedBox(
                          width: 72, height: 72, child: AppImage(pr.coverUrl)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pr.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall),
                          const SizedBox(height: 4),
                          Text(formatPrice(context, pr.price, pr.currency),
                              style: context.text.titleMedium
                                  ?.copyWith(color: AppColors.primary)),
                          if (_sel.isNotEmpty)
                            Text(_sel.values.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                for (final o in _options) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text(o.name, style: context.text.titleMedium),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(_sel[o.name] ?? '',
                            key: ValueKey(_sel[o.name]),
                            style: context.text.bodyMedium
                                ?.copyWith(color: p.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final v in o.values)
                        o.kind == OptionKind.color
                            ? _ColorDot(
                                value: v,
                                selected: _sel[o.name] == v.label,
                                onTap: () => _pick(o, v))
                            : _TextChip(
                                label: v.label,
                                selected: _sel[o.name] == v.label,
                                onTap: () => _pick(o, v)),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                        child: Text(context.tr('quantity'),
                            style: context.text.titleMedium)),
                    QtyStepper(
                        value: _qty,
                        onChanged: (v) => setState(() => _qty = v)),
                  ],
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: missing.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                              '${context.tr('chooseOptions')}: ${missing.join(', ').toLowerCase()}',
                              style: context.text.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700)),
                        ),
                ),
                AppButton(
                  label:
                      '${context.tr(widget.buyNow ? 'buyNow' : 'addToCart')} · ${formatPrice(context, total, pr.currency)}',
                  icon: widget.buyNow
                      ? Icons.flash_on_rounded
                      : Icons.shopping_bag_outlined,
                  variant: widget.buyNow
                      ? AppButtonVariant.primary
                      : AppButtonVariant.lime,
                  onPressed: missing.isEmpty
                      ? () => Navigator.pop(context, (Map.of(_sel), _qty))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _pick(ProductOption o, OptionValue v) {
    HapticFeedback.selectionClick();
    setState(() => _sel[o.name] = v.label);
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color:
              selected ? (dark ? AppColors.lime : AppColors.ink) : p.surface2,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: selected ? Colors.transparent : p.border),
        ),
        child: Text(label,
            style: context.text.labelLarge?.copyWith(
                fontSize: 14,
                color:
                    selected ? (dark ? AppColors.ink : Colors.white) : p.text)),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(
      {required this.value, required this.selected, required this.onTap});
  final OptionValue value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = optionColor(value.color);
    final light = c.computeLuminance() > 0.6;
    return Tooltip(
      message: value.label,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Icon(Icons.check_rounded,
                  size: 20, color: light ? AppColors.ink : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// − 2 + : количество.
class QtyStepper extends StatelessWidget {
  const QtyStepper(
      {super.key, required this.value, required this.onChanged, this.min = 1});
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget btn(IconData icon, int next, bool enabled) => Pressable(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onChanged(next);
                }
              : null,
          scale: 0.85,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: enabled ? p.surface : p.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            child:
                Icon(icon, size: 18, color: enabled ? p.text : p.textTertiary),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration:
          BoxDecoration(color: p.surface2, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, value - 1, value > min),
          SizedBox(
            width: 36,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text('$value',
                  key: ValueKey(value),
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium),
            ),
          ),
          btn(Icons.add_rounded, value + 1, value < 99),
        ],
      ),
    );
  }
}
