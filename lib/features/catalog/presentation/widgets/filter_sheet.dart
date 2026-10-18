import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/picker_sheet.dart';
import '../../../../core/widgets/pressable.dart';
import '../../data/catalog_providers.dart';
import '../../domain/product.dart';
import '../../domain/reference.dart';
import '../catalog_controllers.dart';

Future<void> showFilterSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _FilterSheet(),
    );

/// Быстрые диапазоны цены (в сомах): (от, до).
const _ranges = <(double?, double?)>[
  (null, 1000),
  (1000, 10000),
  (10000, 50000),
  (50000, null),
];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ProductFilter _f = ref.read(productFilterProvider);
  late final _min =
      TextEditingController(text: _f.minPrice?.toStringAsFixed(0) ?? '');
  late final _max =
      TextEditingController(text: _f.maxPrice?.toStringAsFixed(0) ?? '');
  final _debounce = Debouncer(const Duration(milliseconds: 350));
  String? _regionName;
  String? _cityName;

  /// Сколько найдётся с текущими настройками; null — считаем.
  int? _count;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _debounce.dispose();
    super.dispose();
  }

  ProductFilter get _result => _f.copyWith(
        minPrice: () => double.tryParse(_min.text.replaceAll(' ', '')),
        maxPrice: () => double.tryParse(_max.text.replaceAll(' ', '')),
      );

  /// Живой счётчик результатов на кнопке.
  void _recount() {
    setState(() => _count = null);
    final gen = ++_gen;
    _debounce(() async {
      try {
        final r =
            await ref.read(productRepositoryProvider).getProducts(_result, 0);
        if (mounted && gen == _gen) setState(() => _count = r.total);
      } catch (_) {
        if (mounted && gen == _gen) setState(() => _count = -1);
      }
    });
  }

  void _set(ProductFilter f) {
    HapticFeedback.selectionClick();
    setState(() => _f = f);
    _recount();
  }

  Future<void> _pickRegion() async {
    final regions =
        await ref.read(regionsProvider.future).catchError((Object e) {
      if (mounted) context.showError(e);
      return <Never>[];
    });
    if (!mounted || regions.isEmpty) return;
    final r = await showPickerSheet(
      context,
      title: context.tr('region'),
      items: regions,
      labelOf: (r) => r.name,
      isSelected: (r) => r.id == _f.regionId,
    );
    if (r != null) {
      _regionName = r.name;
      _cityName = null;
      _set(_f.copyWith(regionId: () => r.id, cityId: () => null));
    }
  }

  Future<void> _pickCity() async {
    if (_f.regionId == null) return;
    final cities = await ref.read(citiesProvider(_f.regionId!).future);
    if (!mounted) return;
    final c = await showPickerSheet(
      context,
      title: context.tr('city'),
      items: cities,
      labelOf: (c) => c.name,
      isSelected: (c) => c.id == _f.cityId,
    );
    if (c != null) {
      _cityName = c.name;
      _set(_f.copyWith(cityId: () => c.id));
    }
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    ref.read(productFilterProvider.notifier).state = _result;
    Navigator.pop(context);
  }

  void _reset() {
    _min.clear();
    _max.clear();
    _regionName = null;
    _cityName = null;
    _set(ProductFilter(q: _f.q));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final regions = ref.watch(regionsProvider).valueOrNull ?? const [];
    _regionName ??= regions.where((r) => r.id == _f.regionId).firstOrNull?.name;
    if (_f.regionId != null && _cityName == null && _f.cityId != null) {
      _cityName = ref
          .watch(citiesProvider(_f.regionId!))
          .valueOrNull
          ?.where((c) => c.id == _f.cityId)
          .firstOrNull
          ?.name;
    }
    // Выбранная корневая категория (если выбрана подкатегория — её родитель).
    ProductCategory? root;
    for (final c in cats) {
      if (c.id == _f.categoryId ||
          c.children.any((s) => s.id == _f.categoryId)) {
        root = c;
      }
    }
    final minV = double.tryParse(_min.text);
    final maxV = double.tryParse(_max.text);

    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(t, style: context.text.titleMedium),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                      child: Text(context.tr('filters'),
                          style: context.text.headlineMedium)),
                  TextButton(
                    onPressed: _reset,
                    child: Text(context.tr('reset'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // Сортировка — самое частое действие, всегда наверху.
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                children: [
                  for (final s in ProductSort.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ChoiceChip(
                        label: context.tr('sort_${s.name}'),
                        icon: switch (s) {
                          ProductSort.newest => Icons.schedule_rounded,
                          ProductSort.cheap => Icons.south_rounded,
                          ProductSort.expensive => Icons.north_rounded,
                        },
                        selected: _f.sort == s,
                        onTap: () => _set(_f.copyWith(sort: s)),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                children: [
                  section(context.tr('category')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoiceChip(
                        label: context.tr('all'),
                        icon: Icons.apps_rounded,
                        selected: _f.categoryId == null,
                        onTap: () => _set(_f.copyWith(categoryId: () => null)),
                      ),
                      for (final c in cats)
                        _ChoiceChip(
                          label: c.name,
                          icon: categoryIcon(c.icon),
                          selected: root?.id == c.id,
                          onTap: () =>
                              _set(_f.copyWith(categoryId: () => c.id)),
                        ),
                    ],
                  ),
                  // Подкатегории выезжают под выбранной категорией.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: root == null || root.children.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.surface2,
                              borderRadius: AppRadius.lgAll,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${context.tr('subcategory')} · ${root.name}',
                                    style: context.text.labelMedium
                                        ?.copyWith(color: p.textSecondary)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ChoiceChip(
                                      label: context.tr('all'),
                                      small: true,
                                      selected: _f.categoryId == root.id,
                                      onTap: () => _set(_f.copyWith(
                                          categoryId: () => root!.id)),
                                    ),
                                    for (final s in root.children)
                                      _ChoiceChip(
                                        label: s.name,
                                        small: true,
                                        selected: _f.categoryId == s.id,
                                        onTap: () => _set(_f.copyWith(
                                            categoryId: () => s.id)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                  section(context.tr('price')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (from, to) in _ranges)
                        _ChoiceChip(
                          small: true,
                          label: from == null
                              ? context
                                  .tr('priceUpTo')
                                  .replaceAll('{n}', formatNumber(to!))
                              : to == null
                                  ? context
                                      .tr('priceFrom')
                                      .replaceAll('{n}', formatNumber(from))
                                  : '${formatNumber(from)} – ${formatNumber(to)}',
                          selected: minV == from && maxV == to,
                          onTap: () {
                            final same = minV == from && maxV == to;
                            _min.text = same || from == null
                                ? ''
                                : from.toStringAsFixed(0);
                            _max.text =
                                same || to == null ? '' : to.toStringAsFixed(0);
                            _set(_f);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _min,
                          hint: context.tr('from'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _recount(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                            width: 12,
                            height: 2,
                            decoration: BoxDecoration(
                                color: p.textTertiary,
                                borderRadius: AppRadius.pillAll)),
                      ),
                      Expanded(
                        child: AppTextField(
                          controller: _max,
                          hint: context.tr('to'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _recount(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                      ),
                    ],
                  ),
                  section(context.tr('currency')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoiceChip(
                        label: context.tr('any'),
                        selected: _f.currency == null,
                        onTap: () => _set(_f.copyWith(currency: () => null)),
                      ),
                      for (final c in Currency.priced)
                        _ChoiceChip(
                          label: c == Currency.negotiable
                              ? context.tr('negotiable')
                              : c.api,
                          selected: _f.currency == c,
                          onTap: () => _set(_f.copyWith(currency: () => c)),
                        ),
                    ],
                  ),
                  section(context.tr('location')),
                  SelectField(
                    placeholder: context.tr('allRegions'),
                    value: _regionName,
                    icon: Icons.map_rounded,
                    onTap: _pickRegion,
                  ),
                  const SizedBox(height: 10),
                  SelectField(
                    placeholder: context.tr('allCities'),
                    value: _cityName,
                    icon: Icons.location_city_rounded,
                    enabled: _f.regionId != null,
                    onTap: _pickCity,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_outline_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(context.tr('withVideo'),
                              style: context.text.titleSmall),
                        ),
                        Switch(
                          value: _f.hasVideo,
                          onChanged: (v) => _set(_f.copyWith(hasVideo: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                child: AppButton(
                  label: switch (_count) {
                    null => context.tr('showResults'),
                    0 => context.tr('nothingMatches'),
                    -1 => context.tr('showResults'),
                    final n =>
                      context.tr('showN').replaceAll('{n}', formatNumber(n)),
                  },
                  icon: Icons.check_rounded,
                  onPressed: _apply,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon,
      this.small = false});
  final String label;
  final IconData? icon;
  final bool selected;
  final bool small;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 14, vertical: small ? 8 : 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : p.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: selected ? Colors.transparent : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 17, color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: selected ? Colors.white : p.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
