import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/animated_blobs.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/paged_sliver.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeletons.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/editorial.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../data/seller_repositories.dart';
import '../domain/seller_stats.dart';
import 'listing_quality.dart';
import 'listing_tools.dart';

/// Сортировка «моих объявлений» (по загруженным страницам).
enum _MySort { newest, views, priceDesc, attention }

class SellerDashboardScreen extends ConsumerStatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  ConsumerState<SellerDashboardScreen> createState() =>
      _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends ConsumerState<SellerDashboardScreen> {
  int _days = 7;
  ProductStatus _tab = ProductStatus.active;
  final _search = TextEditingController();
  String _q = '';
  _MySort _sort = _MySort.newest;

  /// Выбранные для массовых действий (долгий тап по объявлению).
  final Set<String> _selected = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _apply(List<Product> items) {
    final q = _q.trim().toLowerCase();
    final list = [
      for (final p in items)
        if (q.isEmpty || p.title.toLowerCase().contains(q)) p
    ];
    switch (_sort) {
      case _MySort.newest:
        break;
      case _MySort.views:
        list.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
      case _MySort.priceDesc:
        list.sort((a, b) => (b.price ?? -1).compareTo(a.price ?? -1));
      case _MySort.attention:
        list.sort((a, b) =>
            listingQuality(a).score.compareTo(listingQuality(b).score));
    }
    return list;
  }

  void _toggle(Product p) {
    HapticFeedback.selectionClick();
    setState(() => _selected.contains(p.id)
        ? _selected.remove(p.id)
        : _selected.add(p.id));
  }

  /// Одно действие сразу для всех выбранных.
  Future<void> _bulk(String action) async {
    final ids = _selected.toList();
    if (action == 'delete') {
      final ok = await showConfirmDialog(context,
          title: context.tr('deleteAdsQ').replaceAll('{n}', '${ids.length}'),
          message: '',
          confirm: context.tr('delete'),
          destructive: true,
          icon: Icons.delete_outline_rounded);
      if (!ok) return;
    }
    final repo = ref.read(productRepositoryProvider);
    try {
      for (final id in ids) {
        await switch (action) {
          'bump' => repo.bump(id),
          'sold' => repo.setStatus(id, ProductStatus.sold),
          'archive' => repo.setStatus(id, ProductStatus.archived),
          'restore' => repo.setStatus(id, ProductStatus.active),
          _ => repo.delete(id),
        };
      }
      HapticFeedback.mediumImpact();
      if (mounted) {
        context.showSnack(
            context.tr('bulkDone').replaceAll('{n}', '${ids.length}'),
            type: SnackType.success);
      }
    } catch (e) {
      if (mounted) context.showError(e);
    }
    setState(_selected.clear);
    _refreshAll();
  }

  Future<void> _changePrice(Product p) async {
    if (await showQuickPriceSheet(context, ref, p)) {
      HapticFeedback.lightImpact();
      _refreshAll();
      if (mounted) {
        context.showSnack(context.tr('priceUpdated'), type: SnackType.success);
      }
    }
  }

  /// Обновить всё, что зависит от моих объявлений.
  void _refreshAll() {
    for (final s in ProductStatus.values) {
      ref.invalidate(myProductsByStatusProvider(s));
    }
    ref.read(myProductsPagedProvider.notifier).refresh();
    ref.read(productsPagedProvider.notifier).refresh();
  }

  Future<void> _run(Future<void> Function() action, String okKey) async {
    try {
      await action();
      HapticFeedback.lightImpact();
      _refreshAll();
      if (mounted)
        context.showSnack(context.tr(okKey), type: SnackType.success);
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  Future<void> _setStatus(Product p, ProductStatus s) => _run(
      () => ref.read(productRepositoryProvider).setStatus(p.id, s),
      switch (s) {
        ProductStatus.sold => 'markedSold',
        ProductStatus.archived => 'archivedMsg',
        ProductStatus.active => 'restoredMsg',
      });

  Future<void> _delete(Product p) async {
    final ok = await showConfirmDialog(context,
        title: context.tr('deleteAdQ'),
        message: p.title,
        confirm: context.tr('delete'),
        destructive: true,
        icon: Icons.delete_outline_rounded);
    if (ok) {
      await _run(
          () => ref.read(productRepositoryProvider).delete(p.id), 'adDeleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = ref.watch(sellerStatsProvider(_days));
    final rawTabState = ref.watch(myProductsByStatusProvider(_tab));
    final tabState = rawTabState.copyWith(items: _apply(rawTabState.items));
    final tabCtrl = ref.read(myProductsByStatusProvider(_tab).notifier);
    final activeState =
        ref.watch(myProductsByStatusProvider(ProductStatus.active));
    final counts = {
      for (final s in ProductStatus.values)
        s: ref.watch(myProductsByStatusProvider(s).select((st) => st.total)),
    };
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (shouldLoadMore(n)) tabCtrl.loadMore();
              return false;
            },
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(sellerStatsProvider(_days));
                _refreshAll();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: staggered([
                          _SquareButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => context.pop()),
                          const SizedBox(height: 18),
                          Text(context.tr('sellerCabinet'),
                              style: context.text.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700, height: 1.05)),
                          const SizedBox(height: 4),
                          Text(context.tr('sellerSub'),
                              style: context.text.bodyMedium?.copyWith(
                                  color: p.textSecondary,
                                  fontStyle: FontStyle.italic)),
                          const SizedBox(height: 12),
                          Pressable(
                            onTap: () => context.push('/store/manage'),
                            scale: 0.97,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                gradient: AppColors.limeGradient,
                                borderRadius: AppRadius.pillAll,
                                boxShadow: AppShadows.glow(AppColors.lime,
                                    strength: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_rounded,
                                      size: 18, color: AppColors.ink),
                                  const SizedBox(width: 8),
                                  Text(context.tr('myStore'),
                                      style: context.text.labelMedium?.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: AppColors.ink),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const ListingDraftCard(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final d in [7, 30])
                                _Chip(
                                  label: context.tr('days$d'),
                                  selected: d == _days,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _days = d);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          stats.when(
                            loading: () => const _StatsSkeleton(),
                            error: (e, _) => ErrorView(
                                error: e,
                                onRetry: () =>
                                    ref.invalidate(sellerStatsProvider(_days))),
                            data: (s) => Column(
                              children: [
                                _KpiGrid(
                                    stats: s,
                                    active: counts[ProductStatus.active] ?? 0),
                                const SizedBox(height: 22),
                                _ViewsChart(values: s.viewsByDay),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _SellTips(products: activeState.items),
                          const SizedBox(height: 26),
                          SectionTitle(
                              number: '01', title: context.tr('myAds')),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.none,
                            child: Row(
                              children: [
                                for (final s in ProductStatus.values)
                                  _Chip(
                                    label: '${context.tr(switch (s) {
                                      ProductStatus.active => 'tabActive',
                                      ProductStatus.sold => 'tabSold',
                                      ProductStatus.archived => 'tabArchive',
                                    })} ${counts[s] ?? 0}',
                                    selected: s == _tab,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _tab = s;
                                        _selected.clear();
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                          if (rawTabState.items.length > 1) ...[
                            const SizedBox(height: 12),
                            _SearchSortBar(
                              controller: _search,
                              sort: _sort,
                              onQuery: (v) => setState(() => _q = v),
                              onSort: (v) {
                                HapticFeedback.selectionClick();
                                setState(() => _sort = v);
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(context.tr('longPressHint'),
                                style: context.text.bodySmall?.copyWith(
                                    color: p.textTertiary,
                                    fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 6),
                        ]),
                      ),
                    ),
                  ),
                  PagedSliver<Product>(
                    state: tabState,
                    onRetry: tabCtrl.refresh,
                    onRetryMore: tabCtrl.retryLoadMore,
                    skeleton: const SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: ShimmerWrap(
                                child: Bone(
                                    width: double.infinity, height: 120)))),
                    showEnd: false,
                    empty: switch (_tab) {
                      _ when _q.trim().isNotEmpty => EmptyState(
                          icon: Icons.search_off_rounded,
                          title: context.tr('nothingFound'),
                          subtitle: context.tr('nothingFoundSub')),
                      ProductStatus.active => EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: context.tr('noMyAds'),
                          subtitle: context.tr('noMyAdsSub'),
                          action: context.tr('publish'),
                          onAction: () => context.push('/create'),
                        ),
                      ProductStatus.sold => EmptyState(
                          icon: Icons.sell_outlined,
                          title: context.tr('noSold'),
                          subtitle: context.tr('noSoldSub')),
                      ProductStatus.archived => EmptyState(
                          icon: Icons.archive_outlined,
                          title: context.tr('noArchive'),
                          subtitle: context.tr('noArchiveSub')),
                    },
                    itemsBuilder: (_, items) => SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          key: ValueKey('${items[i].id}-${items[i].status}'),
                          index: i,
                          child: _ListingTile(
                            product: items[i],
                            selecting: _selected.isNotEmpty,
                            selected: _selected.contains(items[i].id),
                            onToggle: () => _toggle(items[i]),
                            onPrice: () => _changePrice(items[i]),
                            onSimilar: () =>
                                context.push('/create', extra: items[i]),
                            onBump: () => _run(
                                () => ref
                                    .read(productRepositoryProvider)
                                    .bump(items[i].id),
                                'bumped'),
                            onEdit: () => context.push('/edit/${items[i].id}',
                                extra: items[i]),
                            onStatus: (s) => _setStatus(items[i], s),
                            onDelete: () => _delete(items[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),
          // Главное действие продавца — всегда под рукой;
          // в режиме выбора на его месте массовые действия.
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position:
                          Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                              .animate(a),
                      child: c)),
              child: _selected.isNotEmpty
                  ? _BulkBar(
                      key: const ValueKey('bulk'),
                      count: _selected.length,
                      tab: _tab,
                      onClose: () => setState(_selected.clear),
                      onSelectAll: () => setState(() =>
                          _selected.addAll(tabState.items.map((e) => e.id))),
                      onAction: _bulk,
                    )
                  : Pressable(
                      key: const ValueKey('post'),
                      onTap: () => context.push('/create'),
                      scale: 0.98,
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: AppColors.limeGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            ...AppShadows.glow(AppColors.lime),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: AppColors.ink),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(context.tr('postAd'),
                                  style: context.text.titleMedium
                                      ?.copyWith(color: AppColors.ink)),
                            ),
                            const Icon(Icons.arrow_forward_rounded,
                                color: AppColors.ink),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: p.border),
            boxShadow: AppShadows.soft(p.shadow, lift: 0.4)),
        child: Icon(icon, size: 18, color: p.text),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? p.text : p.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: selected ? p.text : p.border),
          ),
          child: Text(label,
              style: context.text.labelMedium?.copyWith(
                  color: selected ? p.bg : p.textSecondary,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// 4 ключевые цифры: просмотры, избранное, чаты, активные.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.active});
  final SellerStats stats;
  final int active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tile(String label, int value, int? delta) => Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: p.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall
                      ?.copyWith(color: p.textSecondary, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              CountUpText('$value',
                  style: context.text.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              if (delta != null)
                Row(
                  children: [
                    Icon(
                        delta >= 0
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 18,
                        color:
                            delta >= 0 ? AppColors.success : AppColors.danger),
                    Text('${delta.abs()}%',
                        style: context.text.labelMedium?.copyWith(
                            color: p.text, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(context.tr('vsPrev'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall
                              ?.copyWith(color: p.textTertiary, fontSize: 11)),
                    ),
                  ],
                )
              else
                const SizedBox(height: 18),
            ],
          ),
        );
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: tile(context.tr('statViews'), stats.views,
                  deltaPercent(stats.views, stats.prevViews))),
          const SizedBox(width: 8),
          Expanded(
              child: tile(context.tr('statSaved'), stats.favorites,
                  deltaPercent(stats.favorites, stats.prevFavorites))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: tile(context.tr('statChats'), stats.chats,
                  deltaPercent(stats.chats, stats.prevChats))),
          const SizedBox(width: 8),
          Expanded(child: tile(context.tr('statActive'), active, null)),
        ]),
      ],
    );
  }
}

/// Столбики просмотров по дням. Тап по столбику — его значение.
class _ViewsChart extends StatefulWidget {
  const _ViewsChart({required this.values});
  final List<int> values;

  @override
  State<_ViewsChart> createState() => _ViewsChartState();
}

class _ViewsChartState extends State<_ViewsChart> {
  int? _sel;

  @override
  void didUpdateWidget(_ViewsChart old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) _sel = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = widget.values;
    if (v.isEmpty) return const SizedBox.shrink();
    final maxV = max(1, v.reduce(max));
    final sel = _sel ?? v.length - 1;
    final now = DateTime.now();
    final days = context.tr('weekdaysShort').split('|');
    final dayOf = (int i) => now.subtract(Duration(days: v.length - 1 - i));
    String label(int i) {
      final d = dayOf(i);
      return v.length <= 7
          ? days[d.weekday - 1]
          : '${two(d.day)}.${two(d.month)}';
    }

    final selDay = dayOf(sel);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.tr('viewsByDay').toUpperCase(),
                  style: context.text.labelSmall
                      ?.copyWith(color: p.textSecondary, letterSpacing: 1.2)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '${sel == v.length - 1 ? context.tr('today') : '${two(selDay.day)}.${two(selDay.month)}'} · ${formatNumber(v[sel])}',
                  key: ValueKey(sel),
                  style: context.text.labelMedium
                      ?.copyWith(color: p.text, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: LayoutBuilder(builder: (context, c) {
              final gap = v.length <= 7 ? 8.0 : 2.0;
              final w = (c.maxWidth - gap * (v.length - 1)) / v.length;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _pick(d.localPosition.dx, w + gap),
                onHorizontalDragUpdate: (d) =>
                    _pick(d.localPosition.dx, w + gap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < v.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: v[i] / maxV),
                        duration: Duration(milliseconds: 500 + i * 20),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, __) => Container(
                          width: w,
                          height: max(3, 120 * t),
                          decoration: BoxDecoration(
                            gradient: i == sel
                                ? AppColors.limeGradient
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.45),
                                    ],
                                  ),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(min(8, w / 2))),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),
          Container(height: 1.2, color: p.text),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < v.length; i++)
                Expanded(
                  child: (v.length <= 7 || i % 7 == (v.length - 1) % 7)
                      ? Text(label(i),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: context.text.labelSmall?.copyWith(
                              color: i == sel ? p.text : p.textTertiary,
                              fontSize: 10))
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _pick(double dx, double step) {
    final i = (dx / step).floor().clamp(0, widget.values.length - 1);
    if (i != _sel) {
      HapticFeedback.selectionClick();
      setState(() => _sel = i);
    }
  }
}

/// Советы по всем активным объявлениям: чего не хватает и сколько таких.
class _SellTips extends StatelessWidget {
  const _SellTips({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final counts = <QualityTip, int>{};
    for (final pr in products) {
      for (final t in listingQuality(pr).tips) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadows.soft(context.palette.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.lime, size: 18),
              const SizedBox(width: 8),
              Text(context.tr('sellTips').toUpperCase(),
                  style: context.text.labelSmall
                      ?.copyWith(color: AppColors.lime, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in top.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(width: 6, height: 6, color: AppColors.lime),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(context.tr(e.key.l10nKey),
                        style: context.text.bodyMedium?.copyWith(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text('${e.value} ${context.tr('tipsAds')}',
                      style: context.text.labelSmall?.copyWith(
                          color: AppColors.cream.withValues(alpha: 0.6))),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) => const ShimmerWrap(
        child: Column(
          children: [
            Row(children: [
              Expanded(child: Bone(width: double.infinity, height: 96)),
              SizedBox(width: 8),
              Expanded(child: Bone(width: double.infinity, height: 96)),
            ]),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: Bone(width: double.infinity, height: 96)),
              SizedBox(width: 8),
              Expanded(child: Bone(width: double.infinity, height: 96)),
            ]),
            SizedBox(height: 22),
            Bone(width: double.infinity, height: 180),
          ],
        ),
      );
}

/// Объявление в кабинете: статистика, качество, действия.
class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.product,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onPrice,
    required this.onSimilar,
    required this.onBump,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final Product product;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onPrice;
  final VoidCallback onSimilar;
  final VoidCallback onBump;
  final VoidCallback onEdit;
  final ValueChanged<ProductStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pr = product;
    final q = listingQuality(pr);
    final qColor = qualityColor(q.score);
    final active = pr.status == ProductStatus.active;

    Widget stat(IconData icon, int n) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(children: [
            Icon(icon, size: 14, color: p.textTertiary),
            const SizedBox(width: 3),
            Text(formatNumber(n),
                style: context.text.labelSmall?.copyWith(
                    color: p.textSecondary, fontWeight: FontWeight.w700)),
          ]),
        );

    PopupMenuItem<int> item(int v, IconData icon, String label,
            {Color? color}) =>
        PopupMenuItem(
          value: v,
          child: Row(children: [
            Icon(icon, size: 20, color: color ?? p.text),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color)),
          ]),
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: selected ? AppColors.lime.withValues(alpha: 0.18) : null,
          border: Border(bottom: BorderSide(color: p.border))),
      child: Column(
        children: [
          Pressable(
            scale: 0.98,
            onTap: selecting
                ? onToggle
                : () => context.push('/product/${pr.id}', extra: pr),
            onLongPress: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: ClipRRect(
                    borderRadius: AppRadius.lgAll,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                            opacity: active ? 1 : 0.55,
                            child: AppImage(pr.coverUrl)),
                        if (pr.status == ProductStatus.sold)
                          Center(
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: AppColors.danger, width: 2),
                                    color: AppColors.cream
                                        .withValues(alpha: 0.85)),
                                child: Text(context.tr('soldStamp'),
                                    style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                        letterSpacing: 1)),
                              ),
                            ),
                          ),
                        if (selecting)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.lime
                                    : Colors.black.withValues(alpha: 0.35),
                                border: Border.all(
                                    color:
                                        selected ? AppColors.ink : Colors.white,
                                    width: 1.6),
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded,
                                      size: 16, color: AppColors.ink)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pr.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall
                              ?.copyWith(fontSize: 15, height: 1.25)),
                      const SizedBox(height: 4),
                      // Тап по цене — быстрая смена без открытия формы.
                      GestureDetector(
                        onTap: selecting ? onToggle : onPrice,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PriceText(product: pr, size: 16),
                            if (!selecting) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.edit_outlined,
                                  size: 14, color: p.textTertiary),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        stat(Icons.visibility_outlined, pr.viewsCount),
                        stat(Icons.favorite_border_rounded, pr.likesCount),
                        stat(Icons.chat_bubble_outline_rounded,
                            pr.commentsCount),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (active && !selecting) ...[
            const SizedBox(height: 12),
            // Полоса качества + первая подсказка; тап — весь чек-лист.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showQualityChecklist(context, pr, onImprove: onEdit),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${context.tr('quality')} ${q.score}%',
                          style: context.text.labelSmall?.copyWith(
                              color: p.text, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.surface3,
                            borderRadius: AppRadius.pillAll,
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: q.score / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: qColor,
                                borderRadius: AppRadius.pillAll,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      q.tips.isEmpty
                          ? context.tr('qualityGood')
                          : context.tr(q.tips.first.l10nKey),
                      style: context.text.bodySmall?.copyWith(
                          color: p.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!selecting) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Кнопки прокручиваются, если не влезают в ширину.
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        if (active) ...[
                          _Action(
                              icon: Icons.north_rounded,
                              label: context.tr('bump'),
                              primary: true,
                              onTap: onBump),
                          const SizedBox(width: 8),
                          _Action(
                              icon: Icons.edit_outlined,
                              label: context.tr('edit'),
                              onTap: onEdit),
                          const SizedBox(width: 8),
                          _Action(
                              icon: Icons.check_rounded,
                              label: context.tr('markSold'),
                              onTap: () => onStatus(ProductStatus.sold)),
                        ] else
                          _Action(
                              icon: Icons.replay_rounded,
                              label: context.tr('restore'),
                              primary: true,
                              onTap: () => onStatus(ProductStatus.active)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<int>(
                  padding: EdgeInsets.zero,
                  onSelected: (v) => switch (v) {
                    0 => onStatus(ProductStatus.archived),
                    1 => onDelete(),
                    2 => onPrice(),
                    3 => onSimilar(),
                    _ => shareListing(pr),
                  },
                  itemBuilder: (ctx) => [
                    item(2, Icons.sell_outlined, ctx.tr('changePrice')),
                    item(3, Icons.copy_all_rounded, ctx.tr('makeSimilar')),
                    if (active)
                      item(4, Icons.ios_share_rounded, ctx.tr('share')),
                    if (pr.status != ProductStatus.archived)
                      item(0, Icons.archive_outlined, ctx.tr('toArchive')),
                    item(1, Icons.delete_outline_rounded, ctx.tr('delete'),
                        color: AppColors.danger),
                  ],
                  child: Container(
                    width: 38,
                    height: 36,
                    decoration: BoxDecoration(
                        color: p.surface2, borderRadius: AppRadius.pillAll),
                    child: Icon(Icons.more_horiz_rounded, color: p.text),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Поиск по своим объявлениям + сортировка.
class _SearchSortBar extends StatelessWidget {
  const _SearchSortBar({
    required this.controller,
    required this.sort,
    required this.onQuery,
    required this.onSort,
  });
  final TextEditingController controller;
  final _MySort sort;
  final ValueChanged<String> onQuery;
  final ValueChanged<_MySort> onSort;

  static String _label(_MySort s) => switch (s) {
        _MySort.newest => 'sortNewest',
        _MySort.views => 'sortViews',
        _MySort.priceDesc => 'sortExpensive',
        _MySort.attention => 'sortAttention',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.pillAll,
              border: Border.all(color: p.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: p.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onQuery,
                    textInputAction: TextInputAction.search,
                    style: context.text.bodyMedium,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: context.tr('searchMyAds'),
                      hintStyle: context.text.bodyMedium
                          ?.copyWith(color: p.textTertiary),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      controller.clear();
                      onQuery('');
                    },
                    child: Icon(Icons.close_rounded,
                        size: 18, color: p.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_MySort>(
          padding: EdgeInsets.zero,
          initialValue: sort,
          onSelected: onSort,
          itemBuilder: (ctx) => [
            for (final s in _MySort.values)
              PopupMenuItem(
                value: s,
                child: Row(children: [
                  Icon(
                      s == sort
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 18,
                      color: s == sort ? AppColors.primary : p.textTertiary),
                  const SizedBox(width: 10),
                  Text(ctx.tr(_label(s))),
                ]),
              ),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: sort == _MySort.newest ? p.surface : p.text,
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: p.border)),
            child: Row(
              children: [
                Icon(Icons.swap_vert_rounded,
                    size: 18, color: sort == _MySort.newest ? p.text : p.bg),
                const SizedBox(width: 4),
                Text(context.tr(_label(sort)),
                    style: context.text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: sort == _MySort.newest ? p.text : p.bg)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Нижняя панель режима выбора: счётчик и действия для всех выбранных.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    super.key,
    required this.count,
    required this.tab,
    required this.onClose,
    required this.onSelectAll,
    required this.onAction,
  });
  final int count;
  final ProductStatus tab;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (tab == ProductStatus.active) ...[
        ('bump', Icons.north_rounded, context.tr('bump')),
        ('sold', Icons.check_rounded, context.tr('markSold')),
        ('archive', Icons.archive_outlined, context.tr('toArchive')),
      ] else
        ('restore', Icons.replay_rounded, context.tr('restore')),
      ('delete', Icons.delete_outline_rounded, context.tr('delete')),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: onClose,
                  icon:
                      const Icon(Icons.close_rounded, color: AppColors.cream)),
              Expanded(
                child: Text(context.tr('selectedN').replaceAll('{n}', '$count'),
                    style: context.text.titleSmall
                        ?.copyWith(color: AppColors.cream)),
              ),
              TextButton(
                onPressed: onSelectAll,
                child: Text(context.tr('selectAll'),
                    style: const TextStyle(
                        color: AppColors.lime, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          Row(
            children: [
              for (final (key, icon, label) in actions)
                Expanded(
                  child: Pressable(
                    onTap: () => onAction(key),
                    scale: 0.9,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Icon(icon,
                              color: key == 'delete'
                                  ? AppColors.danger
                                  : AppColors.lime),
                          const SizedBox(height: 4),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
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

class _Action extends StatelessWidget {
  const _Action(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: primary ? AppColors.limeGradient : null,
          borderRadius: AppRadius.pillAll,
          border: primary ? null : Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primary ? AppColors.ink : p.text),
            const SizedBox(width: 5),
            Text(label,
                style: context.text.labelMedium?.copyWith(
                    color: primary ? AppColors.ink : p.text,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Карточка-вход в кабинет из профиля: просмотры за неделю + мини-график.
class SellerCabinetCard extends ConsumerWidget {
  const SellerCabinetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(sellerStatsProvider(7)).valueOrNull;
    final bars = stats?.viewsByDay ?? List.filled(7, 0);
    final maxV = max(1, bars.fold<int>(0, max));
    return Pressable(
      onTap: () => context.push('/seller'),
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlAll,
          boxShadow: AppShadows.soft(context.palette.shadow, lift: 1.2),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.xlAll,
          child: Stack(
            children: [
              const Positioned.fill(
                  child: AnimatedBlobs(base: AppColors.forest, intensity: 0.7)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('sellerCabinet').toUpperCase(),
                              style: context.text.labelSmall?.copyWith(
                                  color: AppColors.lime, letterSpacing: 1.4)),
                          const SizedBox(height: 6),
                          CountUpText('${stats?.views ?? 0}',
                              style: context.text.displaySmall?.copyWith(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '${context.tr('statViews').toLowerCase()} · ${context.tr('days7')}',
                              style: context.text.bodySmall?.copyWith(
                                  color:
                                      AppColors.cream.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 52,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < bars.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: bars[i] / maxV),
                                duration: Duration(milliseconds: 500 + i * 40),
                                curve: Curves.easeOutCubic,
                                builder: (_, t, __) => Container(
                                  width: 8,
                                  height: max(3, 52 * t),
                                  decoration: BoxDecoration(
                                    color: i == bars.length - 1
                                        ? AppColors.lime
                                        : AppColors.cream
                                            .withValues(alpha: 0.35),
                                    borderRadius: AppRadius.pillAll,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.lime),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
