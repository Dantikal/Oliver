import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_blobs.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/oliver_logo.dart';
import '../../../../core/widgets/paged_sliver.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeletons.dart';
import '../../../cart/data/cart.dart';
import '../../../notifications/presentation/counters_controller.dart';
import '../../../shell/main_shell.dart';
import '../../data/catalog_providers.dart';
import '../../domain/product.dart';
import '../../domain/reference.dart';
import '../catalog_controllers.dart';
import '../widgets/editorial.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/home_header.dart';
import '../widgets/product_card.dart';

/// Высота раскрытой шапки: логотип + поиск.
const double _kHeaderExpanded = 140;

/// Полка «Отдам даром» на главной: раздел и первые вещи из него.
final giveawayProvider = FutureProvider.autoDispose<
    ({ProductCategory category, List<Product> items})?>((ref) async {
  final cats = await ref.watch(categoriesProvider.future);
  final cat = cats.where((c) => c.isGiveaway).firstOrNull;
  if (cat == null) return null;
  final page = await ref
      .watch(productRepositoryProvider)
      .getProducts(ProductFilter(categoryId: cat.id), 0);
  final unique = {for (final p in page.items) p.id.split('~').first: p};
  return (category: cat, items: unique.values.take(10).toList());
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  final _debouncer = Debouncer(AppConfig.searchDebounce);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _debouncer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {});
    _debouncer(() {
      final f = ref.read(productFilterProvider);
      if (f.q != v.trim()) {
        ref.read(productFilterProvider.notifier).state =
            f.copyWith(q: v.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(productsPagedProvider);
    final ctrl = ref.read(productsPagedProvider.notifier);
    final filter = ref.watch(productFilterProvider);
    final grid = ref.watch(viewModeGridProvider);
    // «Выбор редакции» — самые просматриваемые из уже загруженных.
    final picks = ([...state.items]
          ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount)))
        .take(5)
        .toList();
    final notif =
        ref.watch(countersProvider.select((c) => c.unreadNotifications));
    final giveaway = ref.watch(giveawayProvider).valueOrNull;
    // Номера разделов идут подряд, сколько бы блоков ни показалось.
    var section = 0;
    String num() => (++section).toString().padLeft(2, '0');

    ref.listen(productsPagedProvider, (prev, next) {
      if (next.error != null && next.items.isNotEmpty && prev?.error == null) {
        context.showError(next.error);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (shouldLoadMore(n)) ctrl.loadMore();
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.primary,
              edgeOffset: MediaQuery.paddingOf(context).top + 60,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(categoriesProvider);
                ref.invalidate(giveawayProvider);
                await ctrl.refresh();
              },
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 0,
                    expandedHeight: _kHeaderExpanded,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: LayoutBuilder(builder: (context, c) {
                      // 1 — шапка раскрыта, 0 — свёрнута до поиска.
                      final top = MediaQuery.paddingOf(context).top;
                      final t =
                          ((c.maxHeight - top - 72) / (_kHeaderExpanded - 72))
                              .clamp(0.0, 1.0);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Живой aurora-фон — часть шапки и уезжает вместе
                          // с ней, низ растворяется в фон.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: t,
                                child: const AnimatedBlobs(
                                    intensity: 0.95, fadeBottom: true),
                              ),
                            ),
                          ),
                          // Свёрнутая шапка превращается в матовое стекло.
                          if (t < 0.99)
                            Opacity(
                              opacity: (1 - t).clamp(0.0, 1.0),
                              child: ClipRect(
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: p.glass,
                                      border: Border(
                                          bottom: BorderSide(color: p.border)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ClipRect(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, top + 10, 16, 0),
                              child: Opacity(
                                opacity: Curves.easeIn.transform(t),
                                child: Transform.translate(
                                  offset: Offset(0, -18 * (1 - t)),
                                  child: Transform.scale(
                                    alignment: Alignment.topLeft,
                                    scale: 0.94 + 0.06 * t,
                                    child: _Header(hasNotif: notif > 0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(72),
                      child: Padding(
                        // 8 + 52 + 12 = ровно 72 — иначе свёрнутая шапка
                        // переполняется на пару пикселей.
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: _SearchBar(
                          controller: _search,
                          onChanged: _onSearch,
                          filterCount: filter.activeCount,
                          grid: grid,
                          onClear: () {
                            _search.clear();
                            _onSearch('');
                          },
                          onFilter: () => showFilterSheet(context),
                          onToggleView: () =>
                              ref.read(viewModeGridProvider.notifier).toggle(),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: _CategoriesRow()),
                  const SliverToBoxAdapter(child: _ActiveFilters()),
                  if (filter.isDefault) ...[
                    const SliverToBoxAdapter(
                        child: FadeSlideIn(index: 3, child: FxStrip())),
                    if (picks.length >= 3) ...[
                      SliverToBoxAdapter(
                        child: FadeSlideIn(
                          index: 3,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
                            child: SectionTitle(
                              number: num(),
                              title: context.tr('editorsPick'),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: FadeSlideIn(
                            index: 4,
                            child: EditorsPickCarousel(products: picks)),
                      ),
                    ],
                    if (giveaway != null && giveaway.items.isNotEmpty)
                      SliverToBoxAdapter(
                        child: FadeSlideIn(
                          index: 5,
                          child: _GiveawayShelf(
                            number: num(),
                            items: giveaway.items,
                            onSeeAll: () {
                              HapticFeedback.selectionClick();
                              ref.read(productFilterProvider.notifier).state =
                                  filter.copyWith(
                                      categoryId: () => giveaway.category.id);
                            },
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: FadeSlideIn(index: 6, child: _PromoBanner())),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 18),
                      child: SectionTitle(
                        number: num(),
                        title: filter.isDefault
                            ? context.tr('freshAds')
                            : context.tr('searchResults'),
                        trailing: AnimatedSwitcher(
                          duration: Motion.normal,
                          transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                  position: Tween(
                                          begin: const Offset(0, 0.4),
                                          end: Offset.zero)
                                      .animate(a),
                                  child: c)),
                          child: state.isLoading
                              ? const SizedBox.shrink()
                              : Text(
                                  '${formatNumber(state.total)} ${context.tr('adsShort')}'
                                      .toUpperCase(),
                                  key: ValueKey(state.total),
                                  style: context.text.labelSmall?.copyWith(
                                      color: p.textSecondary,
                                      letterSpacing: 1.2)),
                        ),
                      ),
                    ),
                  ),
                  PagedSliver<Product>(
                    state: state,
                    onRetry: ctrl.refresh,
                    onRetryMore: ctrl.retryLoadMore,
                    skeleton: const ProductGridSkeleton(),
                    empty: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.tr('nothingFound'),
                      subtitle: context.tr('nothingFoundSub'),
                      action: context.tr('resetFilters'),
                      onAction: () {
                        _search.clear();
                        ref.read(productFilterProvider.notifier).state =
                            const ProductFilter();
                      },
                    ),
                    itemsBuilder: (_, items) => ProductsSliver(
                        key: ValueKey(grid), items: items, grid: grid),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: kNavBarSpace)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onFilter,
    required this.onToggleView,
    required this.filterCount,
    required this.grid,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilter;
  final VoidCallback onToggleView;
  final int filterCount;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Glass(
            radius: 18,
            child: SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: context.text.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: p.text),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: p.textTertiary, size: 20),
                              onPressed: onClear,
                            ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                  if (controller.text.isEmpty)
                    Positioned(
                      left: 48,
                      right: 8,
                      child: IgnorePointer(
                        child: RotatingSearchHint(
                            style: context.text.bodyLarge?.copyWith(
                                color: p.textTertiary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Pressable(
          onTap: onFilter,
          scale: 0.9,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: context.isDark ? AppColors.limeGradient : null,
                  color: context.isDark ? null : AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppShadows.glow(
                      context.isDark ? AppColors.lime : AppColors.ink,
                      strength: 0.6),
                ),
                child: Icon(Icons.tune_rounded,
                    color: context.isDark ? AppColors.ink : AppColors.lime),
              ),
              if (filterCount > 0)
                Positioned(
                    top: -4,
                    right: -4,
                    child: CountBadge(count: filterCount, small: true)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Pressable(
          onTap: onToggleView,
          scale: 0.9,
          child: Glass(
            radius: 18,
            child: SizedBox(
              width: 48,
              height: 52,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(a),
                    child: FadeTransition(opacity: a, child: c)),
                child: Icon(
                    grid ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                    key: ValueKey(grid),
                    color: p.text,
                    size: 21),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesRow extends ConsumerWidget {
  const _CategoriesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cats = ref.watch(categoriesProvider);
    final selected =
        ref.watch(productFilterProvider.select((f) => f.categoryId));

    void select(String? id) {
      HapticFeedback.selectionClick();
      final f = ref.read(productFilterProvider);
      ref.read(productFilterProvider.notifier).state =
          f.copyWith(categoryId: () => id);
    }

    return SizedBox(
      height: 60,
      child: cats.when(
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) =>
              const ShimmerWrap(child: Bone(width: 96, height: 40, radius: 20)),
        ),
        error: (e, _) => Center(
          child: TextButton(
              onPressed: () => ref.invalidate(categoriesProvider),
              child: Text(context.tr('retry'))),
        ),
        data: (list) {
          final all = <ProductCategory?>[null, ...list];
          final dark = context.isDark;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = all[i];
              final isSel = c?.id == selected;
              // «Отдам даром» подсвечен лаймом, чтобы его сразу находили.
              final gift = c?.isGiveaway ?? false;
              final fg = isSel ? (dark ? AppColors.ink : Colors.white) : p.text;
              return FadeSlideIn(
                index: i,
                offset: 12,
                child: Pressable(
                  onTap: () => select(c?.id),
                  scale: 0.92,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Motion.ease,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSel
                          ? (dark ? AppColors.lime : AppColors.ink)
                          : gift
                              ? AppColors.lime
                                  .withValues(alpha: dark ? 0.2 : 0.5)
                              : p.surface.withValues(alpha: dark ? 0.6 : 0.75),
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(
                          color: isSel
                              ? Colors.transparent
                              : gift
                                  ? AppColors.lime
                                  : p.border),
                      boxShadow: isSel
                          ? AppShadows.glow(
                              dark ? AppColors.lime : AppColors.ink,
                              strength: 0.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                            c == null
                                ? Icons.apps_rounded
                                : categoryIcon(c.icon),
                            size: 17,
                            color: isSel
                                ? (dark ? AppColors.ink : AppColors.lime)
                                : AppColors.primary),
                        const SizedBox(width: 7),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: context.text.titleSmall!.copyWith(
                            fontSize: 14,
                            color: fg,
                            fontWeight:
                                isSel ? FontWeight.w800 : FontWeight.w600,
                          ),
                          child: Text(c?.name ?? context.tr('all')),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Pressable(
        scale: 0.98,
        onTap: () => context.push('/create'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xlAll,
            boxShadow: AppShadows.soft(context.palette.shadow, lift: 1.3),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xlAll,
            child: Stack(
              children: [
                const Positioned.fill(
                    child:
                        AnimatedBlobs(base: AppColors.forest, intensity: 0.9)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('promoTag').toUpperCase(),
                                style: context.text.labelSmall?.copyWith(
                                    color: AppColors.lime, letterSpacing: 1.6)),
                            const SizedBox(height: 8),
                            Text(context.tr('promoTitle'),
                                style: context.text.headlineMedium?.copyWith(
                                    color: AppColors.cream, height: 1.1)),
                            const SizedBox(height: 14),
                            Text(context.tr('promoAction'),
                                style: context.text.labelMedium?.copyWith(
                                    color:
                                        AppColors.cream.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.limeGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.glow(AppColors.lime),
                        ),
                        child: Breathing(
                          period: const Duration(milliseconds: 1100),
                          builder: (_, t, child) => Transform.translate(
                              offset: Offset(3 * t, -3 * t), child: child),
                          child: const Icon(Icons.north_east_rounded,
                              color: AppColors.ink, size: 26),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasNotif});
  final bool hasNotif;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(
          index: 0,
          child: Row(
            children: [
              const OliverWordmark(fontSize: 36),
              const Spacer(),
              const CartButton(),
              const SizedBox(width: 10),
              Pressable(
                onTap: () => context.go('/chats?tab=activity'),
                scale: 0.9,
                child: Glass(
                  radius: 23,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            color: p.text, size: 22),
                        if (hasNotif)
                          Positioned(
                            top: 10,
                            right: 11,
                            child: Breathing(
                              builder: (_, t, child) => Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors.lime,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: p.surface, width: 1.6),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.lime
                                            .withValues(alpha: 0.4 + 0.4 * t),
                                        blurRadius: 4 + 6 * t)
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Полка «Отдам даром»: лаймовая подложка, горизонтальная лента вещей.
class _GiveawayShelf extends StatelessWidget {
  const _GiveawayShelf(
      {required this.number, required this.items, required this.onSeeAll});
  final String number;
  final List<Product> items;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 26, 12, 0),
      padding: const EdgeInsets.only(top: 18, bottom: 16),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lime.withValues(alpha: dark ? 0.16 : 0.42),
            AppColors.mint.withValues(alpha: dark ? 0.06 : 0.18),
          ],
        ),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.limeGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.glow(AppColors.lime, strength: 0.5),
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded,
                      color: AppColors.ink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(context.tr('giveaway'),
                      style: context.text.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Pressable(
                  onTap: onSeeAll,
                  scale: 0.92,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: 0.85),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      children: [
                        Text(context.tr('seeAll'),
                            style: context.text.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: p.text),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 272,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 158,
                child: ProductGridCard(product: items[i], hero: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Корзина в шапке: стеклянный круг со счётчиком, счётчик «подпрыгивает».
class CartButton extends ConsumerWidget {
  const CartButton({super.key, this.photo = false});

  /// Поверх фото (экран товара) — тёмное стекло.
  final bool photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final count = ref.watch(cartCountProvider);
    final icon = Icon(Icons.shopping_bag_outlined,
        color: photo ? Colors.white : p.text, size: 22);
    return Pressable(
      onTap: () => context.push('/cart'),
      scale: 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: photo ? 44 : 46,
            height: photo ? 44 : 46,
            child: photo
                ? PhotoGlass(
                    padding: EdgeInsets.zero, child: Center(child: icon))
                : Glass(radius: 23, child: Center(child: icon)),
          ),
          Positioned(
              top: -4, right: -4, child: CountBadge(count: count, small: true)),
        ],
      ),
    );
  }
}

/// Активные фильтры чипами под категориями: видно, что включено,
/// и любой можно снять одним тапом.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final f = ref.watch(productFilterProvider);
    final regions = ref.watch(regionsProvider).valueOrNull ?? const [];
    void set(ProductFilter v) {
      HapticFeedback.selectionClick();
      ref.read(productFilterProvider.notifier).state = v;
    }

    String money(double v) => formatNumber(v);
    final chips = <(String, VoidCallback)>[
      if (f.sort != ProductSort.newest)
        (
          context.tr('sort_${f.sort.name}'),
          () => set(f.copyWith(sort: ProductSort.newest))
        ),
      if (f.minPrice != null || f.maxPrice != null)
        (
          f.minPrice != null && f.maxPrice != null
              ? '${money(f.minPrice!)} – ${money(f.maxPrice!)}'
              : f.minPrice != null
                  ? context
                      .tr('priceFrom')
                      .replaceAll('{n}', money(f.minPrice!))
                  : context
                      .tr('priceUpTo')
                      .replaceAll('{n}', money(f.maxPrice!)),
          () => set(f.copyWith(minPrice: () => null, maxPrice: () => null))
        ),
      if (f.currency != null)
        (
          f.currency == Currency.negotiable
              ? context.tr('negotiable')
              : f.currency!.api,
          () => set(f.copyWith(currency: () => null))
        ),
      if (f.regionId != null)
        (
          regions.where((r) => r.id == f.regionId).firstOrNull?.name ??
              context.tr('region'),
          () => set(f.copyWith(regionId: () => null, cityId: () => null))
        ),
      if (f.hasVideo)
        (context.tr('withVideo'), () => set(f.copyWith(hasVideo: false))),
    ];
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: chips.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                children: [
                  for (final (label, clear) in chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Pressable(
                        onTap: clear,
                        scale: 0.92,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: AppRadius.pillAll,
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Text(label,
                                  style: context.text.labelMedium?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 4),
                              const Icon(Icons.close_rounded,
                                  size: 15, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Pressable(
                    onTap: () =>
                        set(ProductFilter(q: f.q, categoryId: f.categoryId)),
                    scale: 0.92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surface2,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(context.tr('reset'),
                          style: context.text.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
