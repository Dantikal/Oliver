import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/paged_sliver.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/domain/user.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/editorial.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../chats/presentation/chat_actions.dart';
import '../data/profile_repositories.dart';
import '../../store/data/store_repositories.dart';
import 'profile_cover.dart';
import 'profile_header.dart';

final publicUserProvider = FutureProvider.autoDispose.family<User, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).user(id),
);

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.userId, this.initial});
  final String userId;
  final User? initial;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final async = ref.watch(publicUserProvider(widget.userId));
    final user = async.valueOrNull ?? widget.initial;
    final state = ref.watch(userProductsPagedProvider(widget.userId));
    final ctrl = ref.read(userProductsPagedProvider(widget.userId).notifier);

    if (user == null && async.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
            child: ErrorView(
                error: async.error,
                onRetry: () =>
                    ref.invalidate(publicUserProvider(widget.userId)))),
      );
    }

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (shouldLoadMore(n)) ctrl.loadMore();
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ProfileHeader(
                name: user?.fullName ?? '',
                avatarUrl: user?.avatarUrl,
                cover: ProfileCover.forUser(widget.userId),
                topActions: [
                  CoverButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => context.pop()),
                  const Spacer(),
                  CoverButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: () => context.showSnack(context.tr('soon')),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    user == null
                        ? const ShimmerWrap(child: Bone(width: 180, height: 28))
                        : Text(user.fullName,
                            style: context.text.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700, height: 1.05)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 4),
                        Text(context.tr('verified'),
                            style: context.text.labelMedium
                                ?.copyWith(color: AppColors.success)),
                        if (user?.createdAt != null) ...[
                          Text('  ·  ',
                              style: TextStyle(color: p.textTertiary)),
                          Text(
                              '${context.tr('onOliverSince')} ${user!.createdAt!.year}',
                              style: context.text.bodySmall),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: context.tr('write'),
                      icon: Icons.chat_bubble_rounded,
                      loading: _opening,
                      onPressed: user == null
                          ? null
                          : () async {
                              setState(() => _opening = true);
                              await openChatWith(context, ref, user);
                              if (mounted) setState(() => _opening = false);
                            },
                    ),
                    if (ref.watch(storeOfProvider(widget.userId)).valueOrNull !=
                        null) ...[
                      const SizedBox(height: 10),
                      AppButton(
                        label: context.tr('store'),
                        icon: Icons.storefront_outlined,
                        variant: AppButtonVariant.outline,
                        onPressed: () =>
                            context.push('/store/${widget.userId}'),
                      ),
                    ],
                    const SizedBox(height: 26),
                    SectionTitle(
                      number: '01',
                      title: context.tr('userAds'),
                      trailing: Text('${state.total}'.padLeft(2, '0'),
                          style: context.text.labelSmall?.copyWith(
                              color: p.textSecondary, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            PagedSliver<Product>(
              state: state,
              onRetry: ctrl.refresh,
              onRetryMore: ctrl.retryLoadMore,
              skeleton: const ProductGridSkeleton(count: 4),
              showEnd: false,
              empty: EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: context.tr('noUserAds'),
                  subtitle: context.tr('noUserAdsSub')),
              itemsBuilder: (_, items) =>
                  ProductsSliver(items: items, grid: true, hero: false),
            ),
            SliverToBoxAdapter(
                child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }
}
