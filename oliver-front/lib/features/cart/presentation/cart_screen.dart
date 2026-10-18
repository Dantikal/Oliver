import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/motion.dart';
import '../data/cart.dart';
import 'variant_sheet.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  String? _sending;

  Future<void> _checkout(List<CartItem> items) async {
    final sellerId = items.first.seller.id;
    setState(() => _sending = sellerId);
    try {
      await sendOrder(context, ref, items);
      ref.read(cartProvider.notifier).removeSeller(sellerId);
      HapticFeedback.mediumImpact();
      if (mounted) {
        context.showSnack(context.tr('orderSent'), type: SnackType.success);
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final groups = <String, List<CartItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.seller.id, () => []).add(i);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('cart'), style: context.text.headlineMedium),
      ),
      body: items.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: context.tr('cartEmpty'),
                subtitle: context.tr('cartEmptySub'),
                action: context.tr('toShopping'),
                onAction: () => context.go('/home'),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                for (final (i, g) in groups.values.indexed)
                  FadeSlideIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _SellerGroup(
                        items: g,
                        sending: _sending == g.first.seller.id,
                        onCheckout: () => _checkout(g),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SellerGroup extends ConsumerWidget {
  const _SellerGroup(
      {required this.items, required this.sending, required this.onCheckout});
  final List<CartItem> items;
  final bool sending;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final seller = items.first.seller;
    return Glass(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(url: seller.avatarUrl, name: seller.fullName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(seller.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final it in items)
            Dismissible(
              key: ValueKey(it.key),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                HapticFeedback.lightImpact();
                ref.read(cartProvider.notifier).remove(it.key);
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: AppRadius.lgAll,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/product/${it.productId}'),
                      child: ClipRRect(
                        borderRadius: AppRadius.mdAll,
                        child: SizedBox(
                            width: 64, height: 64, child: AppImage(it.cover)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (it.selection.isNotEmpty)
                            Text(it.selectionText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall),
                          const SizedBox(height: 2),
                          Text(formatPrice(context, it.total, it.currency),
                              style: context.text.titleSmall
                                  ?.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                    QtyStepper(
                      value: it.qty,
                      min: 0,
                      onChanged: (v) =>
                          ref.read(cartProvider.notifier).setQty(it.key, v),
                    ),
                  ],
                ),
              ),
            ),
          Divider(color: p.border, height: 20),
          Row(
            children: [
              Text(context.tr('orderTotal'),
                  style: context.text.bodyMedium
                      ?.copyWith(color: p.textSecondary)),
              const Spacer(),
              Text(cartTotalText(context, items),
                  style: context.text.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: context.tr('checkoutSeller'),
            icon: Icons.send_rounded,
            loading: sending,
            onPressed: onCheckout,
          ),
        ],
      ),
    );
  }
}
