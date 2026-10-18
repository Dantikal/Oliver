import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/pressable.dart';
import '../../cart/presentation/variant_sheet.dart';
import '../../catalog/domain/product.dart';

const _maxGroups = 3;

/// Палитра для цветовых вариантов: ключ строки → цвет.
const _palette = <(String, String)>[
  ('colBlack', '#1C1C1E'),
  ('colWhite', '#F2F2F2'),
  ('colGray', '#8E8E93'),
  ('colSilver', '#C7CBD1'),
  ('colGold', '#D4AF6A'),
  ('colBeige', '#E3D3B5'),
  ('colBrown', '#8A5A3B'),
  ('colRed', '#E5484D'),
  ('colPink', '#F49AC1'),
  ('colOrange', '#F28C28'),
  ('colYellow', '#F5D547'),
  ('colGreen', '#2FA35A'),
  ('colBlue', '#2F6FED'),
  ('colPurple', '#8E6CEF'),
];

/// Готовые группы: ключ названия, тип и подсказки значений.
const _presets = <(String, OptionKind, List<String>, IconData)>[
  (
    'optModel',
    OptionKind.text,
    [
      'iPhone 12',
      'iPhone 13',
      'iPhone 14',
      'iPhone 15',
      'iPhone 15 Pro',
      'iPhone 15 Pro Max',
      'iPhone 16',
      'iPhone 16 Pro',
      'iPhone 16 Pro Max',
      'Galaxy S24',
      'Galaxy S24 Ultra',
    ],
    Icons.smartphone_rounded
  ),
  ('optColor', OptionKind.color, [], Icons.palette_outlined),
  (
    'optSize',
    OptionKind.text,
    [
      'XS',
      'S',
      'M',
      'L',
      'XL',
      'XXL',
      '36',
      '37',
      '38',
      '39',
      '40',
      '41',
      '42',
      '43',
      '44',
      '45'
    ],
    Icons.straighten_rounded
  ),
  (
    'optMemory',
    OptionKind.text,
    ['64 ГБ', '128 ГБ', '256 ГБ', '512 ГБ', '1 ТБ'],
    Icons.sd_storage_outlined
  ),
];

/// Подсказки для уже созданной группы — по совпадению названия с пресетом.
List<String> _suggestionsFor(BuildContext c, ProductOption o) {
  for (final (key, _, values, _) in _presets) {
    if (c.tr(key) == o.name) return values;
  }
  return const [];
}

/// Варианты товара в форме создания. Родитель получает каждое изменение,
/// а редактор держит актуальную копию — шторки работают с ней, а не со
/// снимком на момент открытия.
class OptionsEditor extends StatefulWidget {
  const OptionsEditor(
      {super.key, required this.options, required this.onChanged});
  final List<ProductOption> options;
  final ValueChanged<List<ProductOption>> onChanged;

  @override
  State<OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<OptionsEditor> {
  late List<ProductOption> options = [...widget.options];

  @override
  void didUpdateWidget(OptionsEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.options, widget.options)) {
      options = [...widget.options];
    }
  }

  void onChanged(List<ProductOption> next) {
    setState(() => options = next);
    widget.onChanged(next);
  }

  void _update(int i, ProductOption o) {
    if (i >= options.length) return;
    onChanged([...options]..[i] = o);
  }

  Future<void> _addGroup(BuildContext context) async {
    final p = context.palette;
    final r = await showModalBottomSheet<(String, OptionKind)>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                child: Text(ctx.tr('addVariantGroup'),
                    style: ctx.text.headlineSmall),
              ),
              for (final (key, kind, _, icon) in _presets)
                if (!options.any((o) => o.name == ctx.tr(key)))
                  ListTile(
                    leading: Icon(icon, color: AppColors.primary),
                    title: Text(ctx.tr(key), style: ctx.text.titleSmall),
                    trailing: Icon(Icons.add_rounded, color: p.textTertiary),
                    onTap: () => Navigator.pop(ctx, (ctx.tr(key), kind)),
                  ),
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: Text(ctx.tr('optCustom'), style: ctx.text.titleSmall),
                trailing: Icon(Icons.add_rounded, color: p.textTertiary),
                onTap: () => Navigator.pop(ctx, ('', OptionKind.text)),
              ),
            ],
          ),
        ),
      ),
    );
    if (r == null || !context.mounted) return;
    var name = r.$1;
    if (name.isEmpty) {
      name = await _askText(context, context.tr('optCustomName')) ?? '';
      if (name.trim().isEmpty) return;
    }
    HapticFeedback.selectionClick();
    final group = ProductOption(name: name.trim(), kind: r.$2);
    final index = options.length;
    onChanged([...options, group]);
    if (r.$2 == OptionKind.text && context.mounted) {
      _addValues(context, index, group);
    }
  }

  /// Шторка добавления значений: поле ввода + подсказки в один тап.
  Future<void> _addValues(
      BuildContext context, int index, ProductOption o) async {
    final suggestions = _suggestionsFor(context, o);
    final c = TextEditingController();
    var current = o;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void add(String v) {
          final t = v.trim();
          if (t.isEmpty || current.values.any((x) => x.label == t)) return;
          HapticFeedback.selectionClick();
          current = current
              .copyWith(values: [...current.values, OptionValue(label: t)]);
          _update(index, current);
          setSheet(() {});
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(current.name, style: ctx.text.headlineSmall),
              const SizedBox(height: 14),
              AppTextField(
                controller: c,
                autofocus: suggestions.isEmpty,
                hint: ctx.tr('optValueHint'),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  add(v);
                  c.clear();
                },
                suffix: IconButton(
                  icon: const Icon(Icons.add_circle_rounded,
                      color: AppColors.primary),
                  onPressed: () {
                    add(c.text);
                    c.clear();
                  },
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in suggestions)
                      _Chip(
                        label: s,
                        selected: current.values.any((v) => v.label == s),
                        onTap: () {
                          if (current.values.any((v) => v.label == s)) {
                            current = current.copyWith(values: [
                              for (final v in current.values)
                                if (v.label != s) v
                            ]);
                            _update(index, current);
                            setSheet(() {});
                          } else {
                            add(s);
                          }
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              AppButton(
                  label: ctx.tr('done'),
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        );
      }),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('variantsHint'),
            style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
        const SizedBox(height: 12),
        for (final (i, o) in options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GroupCard(
              option: o,
              onRemove: () {
                HapticFeedback.lightImpact();
                onChanged([...options]..removeAt(i));
              },
              onAdd: () => _addValues(context, i, o),
              onToggleColor: (key, hex) {
                final label = context.tr(key);
                final has = o.values.any((v) => v.label == label);
                HapticFeedback.selectionClick();
                _update(
                    i,
                    o.copyWith(
                        values: has
                            ? [
                                for (final v in o.values)
                                  if (v.label != label) v
                              ]
                            : [
                                ...o.values,
                                OptionValue(label: label, color: hex)
                              ]));
              },
              onRemoveValue: (label) => _update(
                  i,
                  o.copyWith(values: [
                    for (final v in o.values)
                      if (v.label != label) v
                  ])),
            ),
          ),
        if (options.length < _maxGroups)
          Pressable(
            onTap: () => _addGroup(context),
            scale: 0.97,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 1.4),
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(context.tr('addVariantGroup'),
                      style: context.text.labelLarge
                          ?.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.option,
    required this.onRemove,
    required this.onAdd,
    required this.onToggleColor,
    required this.onRemoveValue,
  });
  final ProductOption option;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final void Function(String key, String hex) onToggleColor;
  final ValueChanged<String> onRemoveValue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = option.kind == OptionKind.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
            color: option.values.isEmpty
                ? AppColors.warning.withValues(alpha: 0.6)
                : p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(color ? Icons.palette_outlined : Icons.tune_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${option.name}${option.values.isEmpty ? '' : ' · ${option.values.length}'}',
                    style: context.text.titleSmall),
              ),
              IconButton(
                onPressed: onRemove,
                icon:
                    Icon(Icons.close_rounded, size: 20, color: p.textTertiary),
              ),
            ],
          ),
          if (color)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, hex) in _palette)
                  _Swatch(
                    hex: hex,
                    label: context.tr(key),
                    selected:
                        option.values.any((v) => v.label == context.tr(key)),
                    onTap: () => onToggleColor(key, hex),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in option.values)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(v.label,
                            style: context.text.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        GestureDetector(
                          onTap: () => onRemoveValue(v.label),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: p.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                Pressable(
                  onTap: onAdd,
                  scale: 0.92,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(context.tr('add'),
                            style: context.text.labelMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.hex,
      required this.label,
      required this.selected,
      required this.onTap});
  final String hex;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = optionColor(hex);
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.2),
          ),
          child: Container(
            decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: p.border)),
            child: selected
                ? Icon(Icons.check_rounded,
                    size: 16,
                    color: c.computeLuminance() > 0.6
                        ? AppColors.ink
                        : Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : p.surface2,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: context.text.labelMedium?.copyWith(
                    color: selected ? Colors.white : p.text,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askText(BuildContext context, String title) async {
  final c = TextEditingController();
  final r = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ctx.text.headlineSmall),
          const SizedBox(height: 14),
          AppTextField(
            controller: c,
            autofocus: true,
            hint: ctx.tr('optCustomHint'),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 16),
          AppButton(
              label: ctx.tr('done'),
              onPressed: () => Navigator.pop(ctx, c.text)),
        ],
      ),
    ),
  );
  c.dispose();
  return r;
}
