import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../chats/presentation/chat_actions.dart';
import '../../profile/presentation/profile_cover.dart';
import '../../profile/presentation/user_profile_screen.dart';
import '../data/store_repositories.dart';
import '../domain/store.dart';
import 'store_manage_screen.dart';
import 'store_widgets.dart';

/// Витрина магазина для покупателя (и предпросмотр для владельца).
class StorefrontScreen extends ConsumerStatefulWidget {
  const StorefrontScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends ConsumerState<StorefrontScreen> {
  /// null — «Все», '★' — хиты, иначе id отдела.
  String? _tab;
  StoreSort _sort = StoreSort.seller;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = ref.watch(currentUserProvider);
    final isMine = me?.id == widget.userId;
    final storeAsync = isMine
        ? ref.watch(myStoreProvider)
        : ref.watch(storeOfProvider(widget.userId));
    final owner =
        isMine ? me : ref.watch(publicUserProvider(widget.userId)).valueOrNull;
    final productsAsync = ref.watch(storeProductsProvider(widget.userId));
    final cover = isMine
        ? ref.watch(profileCoverProvider)
        : ProfileCover.forUser(widget.userId);

    return Scaffold(
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: ErrorView(
                error: e,
                onRetry: () => ref.invalidate(storeOfProvider(widget.userId)))),
        data: (store) {
          if (store == null) {
            return Center(
              child: EmptyState(
                icon: Icons.storefront_outlined,
                title: context.tr('store'),
                subtitle: context.tr('storeSub'),
                action: isMine ? context.tr('createStore') : null,
                onAction: isMine ? () => context.push('/store/manage') : null,
              ),
            );
          }
          final all = productsAsync.valueOrNull ?? const <Product>[];
          final byId = {for (final x in all) x.id: x};
          // Порядок продавца: отделы по порядку, затем всё неразложенное.
          final manual = [
            for (final s in store.sections) ...s.productIds,
            for (final x in all)
              if (store.sectionOf(x.id) == null) x.id,
          ];
          final hits = [
            for (final id in store.featuredIds)
              if (byId[id] != null) byId[id]!
          ];
          final section = store.sections.where((s) => s.id == _tab).firstOrNull;
          var items = switch (_tab) {
            null => all,
            '★' => hits,
            _ => [
                for (final id in section?.productIds ?? const <String>[])
                  if (byId[id] != null) byId[id]!
              ],
          };
          if (_q.isNotEmpty) {
            final q = _q.toLowerCase();
            items =
                items.where((x) => x.title.toLowerCase().contains(q)).toList();
          }
          items = sortStoreProducts(
              items, _sort, _tab == '★' ? store.featuredIds : manual);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: StoreHeader(
                  cover: cover,
                  name: store.name,
                  ownerName: owner?.fullName ?? store.name,
                  avatarUrl: owner?.avatarUrl,
                  description: store.description,
                  chips: [
                    if (store.pickup) context.tr('pickup'),
                    if (store.delivery) context.tr('deliveryOpt'),
                    '${context.tr('itemsCap')} · ${all.length}',
                    '${context.tr('sections')} · ${store.sections.length}',
                  ],
                  topActions: [
                    OverCoverButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop()),
                    const Spacer(),
                    OverCoverButton(
                      icon: Icons.ios_share_rounded,
                      onTap: () => Share.share(
                          '${store.name}\n${storeLink(widget.userId)}'),
                    ),
                    const SizedBox(width: 8),
                    if (isMine)
                      OverCoverButton(
                          icon: Icons.tune_rounded,
                          label: context.tr('edit'),
                          onTap: () => context.push('/store/manage'))
                    else if (owner != null)
                      OverCoverButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: context.tr('write'),
                          onTap: () => openChatWith(context, ref, owner)),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v.trim()),
                    decoration: InputDecoration(
                      hintText: context.tr('searchInStore'),
                      prefixIcon: Icon(Icons.search_rounded, color: p.text),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // Отделы — закреплены при прокрутке.
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsHeader(
                  bg: p.bg,
                  border: p.border,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    children: [
                      FlatChip(
                          label: '${context.tr('allItems')} ${all.length}',
                          selected: _tab == null,
                          onTap: () => setState(() => _tab = null)),
                      if (hits.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        FlatChip(
                            label: context.tr('hits'),
                            icon: Icons.star_rounded,
                            selected: _tab == '★',
                            onTap: () => setState(() => _tab = '★')),
                      ],
                      for (final s in store.sections) ...[
                        const SizedBox(width: 6),
                        FlatChip(
                            label: '${s.name} ${s.productIds.length}',
                            icon: storeIcon(s.icon),
                            selected: _tab == s.id,
                            onTap: () => setState(() => _tab = s.id)),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    children: [
                      for (final s in StoreSort.values) ...[
                        _SortChip(
                          label: context.tr(switch (s) {
                            StoreSort.seller => 'sortSeller',
                            StoreSort.newest => 'sortNewest',
                            StoreSort.cheap => 'sortCheap',
                            StoreSort.expensive => 'sortExpensive',
                            StoreSort.popular => 'sortPopular',
                          }),
                          selected: _sort == s,
                          onTap: () => setState(() => _sort = s),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ],
                  ),
                ),
              ),
              if (productsAsync.isLoading)
                const ProductGridSkeleton(count: 4)
              else if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: EmptyState(
                      icon: section == null
                          ? Icons.search_off_rounded
                          : storeIcon(section.icon),
                      title: context
                          .tr(_q.isEmpty ? 'emptySection' : 'nothingFound'),
                      subtitle: '',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 6),
                  sliver: ProductsSliver(
                      key: ValueKey('$_tab-$_sort-$_q'),
                      items: items,
                      grid: true,
                      hero: false),
                ),
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 30)),
            ],
          );
        },
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: context.text.labelMedium?.copyWith(
                  color: selected ? p.text : p.textTertiary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            width: selected ? 22 : 0,
            decoration: BoxDecoration(
                color: AppColors.lime, borderRadius: AppRadius.pillAll),
          ),
        ],
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({required this.child, required this.bg, required this.border});
  final Widget child;
  final Color bg;
  final Color border;

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(
        decoration: BoxDecoration(
            color: bg,
            border:
                overlaps ? Border(bottom: BorderSide(color: border)) : null),
        child: child,
      );

  @override
  bool shouldRebuild(_TabsHeader old) => true;
}
