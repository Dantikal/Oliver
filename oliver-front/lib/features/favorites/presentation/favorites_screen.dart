import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/paged_sliver.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeletons.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/widgets/heart_button.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../chats/presentation/chat_actions.dart';
import '../../shell/main_shell.dart';
import 'favorites_controller.dart';
import '../../../core/widgets/motion.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final state = ref.watch(favoritesPagedProvider);
    final ctrl = ref.read(favoritesPagedProvider.notifier);
    final ids = ref.watch(favoriteIdsProvider);
    final count = ref.watch(favoritesCountProvider);
    final visible =
        state.items.where((x) => ids.contains(x.id.split('~').first)).toList();

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (shouldLoadMore(n)) ctrl.loadMore();
          return false;
        },
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: ctrl.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('favorites'),
                                  style: context.text.displaySmall),
                              const SizedBox(height: 4),
                              Text(context.tr('favoritesSub'),
                                  style: context.text.bodyMedium
                                      ?.copyWith(color: p.textSecondary)),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Container(
                            key: ValueKey(count),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: AppColors.leafGradient,
                              borderRadius: AppRadius.mdAll,
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        AppColors.leaf.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6))
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text('$count',
                                    style: context.text.titleMedium
                                        ?.copyWith(color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PagedSliver<Product>(
                state: state.copyWith(items: visible),
                onRetry: ctrl.refresh,
                onRetryMore: ctrl.retryLoadMore,
                skeleton:
                    const ListSkeleton(avatar: 100, square: true, count: 5),
                showEnd: false,
                empty: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: context.tr('favEmpty'),
                  subtitle: context.tr('favEmptySub'),
                  action: context.tr('browseAds'),
                  onAction: () => context.go('/home'),
                  gradient: AppColors.leafGradient,
                ),
                itemsBuilder: (_, items) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => FadeSlideIn(
                        key: ValueKey(items[i].id),
                        index: i,
                        child: _FavoriteTile(product: items[i])),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends ConsumerStatefulWidget {
  const _FavoriteTile({required this.product});
  final Product product;

  @override
  ConsumerState<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends ConsumerState<_FavoriteTile> {
  bool _opening = false;

  Future<void> _remove() async {
    try {
      await ref.read(favoriteIdsProvider.notifier).toggle(widget.product.id);
      if (mounted) context.showSnack(context.tr('removedFromFav'));
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final product = widget.product;
    return Dismissible(
      key: ValueKey('fav-${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0x00FF3B5C), AppColors.danger]),
          borderRadius: AppRadius.mdAll,
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Pressable(
        scale: 0.98,
        onTap: () => context.push('/product/${product.id}', extra: product),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              AppImage(product.coverUrl, width: 104, height: 104, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              context.text.titleSmall?.copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      PriceText(product: product),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(child: LocationLine(text: product.cityName)),
                          Pressable(
                            onTap: _opening
                                ? null
                                : () async {
                                    setState(() => _opening = true);
                                    await openChatWith(
                                        context, ref, product.seller,
                                        productId: product.id);
                                    if (mounted) {
                                      setState(() => _opening = false);
                                    }
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  borderRadius: AppRadius.mdAll),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _opening
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.chat_bubble_rounded,
                                          color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(context.tr('toChat'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Align(
                  alignment: Alignment.topCenter,
                  child: HeartButton(
                      productId: product.id, glass: false, size: 38)),
            ],
          ),
        ),
      ),
    );
  }
}
