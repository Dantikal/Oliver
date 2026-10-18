import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/fx/fx.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeletons.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../chats/presentation/chat_actions.dart';
import '../../domain/product.dart';
import '../catalog_controllers.dart';
import '../widgets/heart_button.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/media_gallery.dart';
import '../../../cart/presentation/variant_sheet.dart';
import 'home_screen.dart' show CartButton;

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen(
      {super.key, required this.productId, this.initial});

  final String productId;
  final Product? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productDetailsProvider(productId));
    final product = async.valueOrNull ?? initial;

    if (product == null) {
      return Scaffold(
        body: async.hasError
            ? Center(
                child: ErrorView(
                    error: async.error,
                    onRetry: () =>
                        ref.invalidate(productDetailsProvider(productId))))
            : const _DetailsSkeleton(),
      );
    }
    return _DetailsView(product: product, loadingFull: async.isLoading);
  }
}

class _DetailsView extends ConsumerWidget {
  const _DetailsView({required this.product, required this.loadingFull});
  final Product product;
  final bool loadingFull;

  String get _link =>
      '${AppConfig.shareBaseUrl}/${product.id.split('~').first}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final me = ref.watch(currentUserProvider);
    final isMine = me?.id == product.seller.id;
    final width = MediaQuery.sizeOf(context).width;
    final top = MediaQuery.paddingOf(context).top;

    void share() {
      HapticFeedback.selectionClick();
      Share.share(
          '${product.title} — ${formatPrice(context, product.price, product.currency)}\n$_link');
    }

    void copy() {
      Clipboard.setData(ClipboardData(text: _link));
      HapticFeedback.lightImpact();
      context.showSnack(context.tr('linkCopied'), type: SnackType.success);
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ParallaxHeader(
                  height: width * 1.08,
                  child: MediaGallery(
                      media: product.media,
                      heroTag: 'product-${product.id}',
                      height: width * 1.08),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.bg,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl + 6)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, -8)),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: staggered([
                        Row(
                          children: [
                            Expanded(
                              child: product.currency.isPriceless
                                  ? GradientText(
                                      formatPrice(context, product.price,
                                          product.currency),
                                      style: context.text.displaySmall)
                                  : GradientText(
                                      formatPrice(context, product.price,
                                          product.currency),
                                      gradient: context.isDark
                                          ? AppColors.limeGradient
                                          : AppColors.brandGradient,
                                      style: context.text.displaySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                            ),
                            if (!product.currency.isPriceless)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: const BoxDecoration(
                                  gradient: AppColors.limeGradient,
                                  borderRadius: AppRadius.pillAll,
                                ),
                                child: Text(product.currency.api,
                                    style: context.text.labelSmall?.copyWith(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        if (priceEquivalent(
                                context, product, ref.watch(fxRatesProvider)) !=
                            null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: GestureDetector(
                              onTap: () => showConverterSheet(context,
                                  amount: product.price,
                                  from: product.currency.api),
                              child: Row(
                                children: [
                                  Text(
                                      '${priceEquivalent(context, product, ref.watch(fxRatesProvider))!} · ${context.tr('byNbkr')}',
                                      style: context.text.bodyMedium?.copyWith(
                                          color: p.textSecondary,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.currency_exchange_rounded,
                                      size: 16, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(product.title,
                            style: context.text.titleLarge
                                ?.copyWith(fontSize: 21, height: 1.25)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                                icon: Icons.sell_rounded,
                                label: product.categoryName),
                            _InfoChip(
                                icon: Icons.schedule_rounded,
                                label: timeAgo(context, product.createdAt)),
                            _InfoChip(
                                icon: Icons.visibility_rounded,
                                label: formatNumber(product.viewsCount)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _ActionsRow(
                          commentsCount: product.commentsCount,
                          onShare: share,
                          onCopy: copy,
                          onComments: () =>
                              context.push('/product/${product.id}/comments'),
                        ),
                        if (product.options.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          _OptionsPreview(
                            product: product,
                            onTap: isMine || !product.buyable
                                ? null
                                : () => openBuyFlow(context, ref, product,
                                    buyNow: false),
                          ),
                        ],
                        const SizedBox(height: 26),
                        Text(context.tr('description'),
                            style: context.text.headlineSmall),
                        const SizedBox(height: 10),
                        Text(product.description,
                            style: context.text.bodyLarge?.copyWith(
                                color: p.textSecondary, height: 1.55)),
                        const SizedBox(height: 26),
                        _LocationCard(product: product),
                        const SizedBox(height: 14),
                        _SellerCard(product: product, isMine: isMine),
                        if (!isMine &&
                            (product.phone != null ||
                                product.whatsappLink != null ||
                                product.telegramLink != null)) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (product.phone != null) ...[
                                Expanded(
                                  child: _MessengerButton(
                                    label: context.tr('call'),
                                    color: AppColors.success,
                                    icon: Icons.call_rounded,
                                    onTap: () =>
                                        copyAndNotify(context, product.phone!),
                                  ),
                                ),
                                if (product.whatsappLink != null ||
                                    product.telegramLink != null)
                                  const SizedBox(width: 10),
                              ],
                              if (product.whatsappLink != null)
                                Expanded(
                                  child: _MessengerButton(
                                    label: 'WhatsApp',
                                    color: const Color(0xFF25D366),
                                    icon: Icons.chat_rounded,
                                    onTap: () => copyAndNotify(
                                        context, product.whatsappLink!),
                                  ),
                                ),
                              if (product.whatsappLink != null &&
                                  product.telegramLink != null)
                                const SizedBox(width: 10),
                              if (product.telegramLink != null)
                                Expanded(
                                  child: _MessengerButton(
                                    label: 'Telegram',
                                    color: const Color(0xFF29A9EB),
                                    icon: Icons.send_rounded,
                                    onTap: () => copyAndNotify(
                                        context, product.telegramLink!),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    glass: true,
                    onTap: () => context.pop()),
                const Spacer(),
                const CartButton(photo: true),
                const SizedBox(width: 10),
                CircleIconButton(
                    icon: Icons.ios_share_rounded, glass: true, onTap: share),
                const SizedBox(width: 10),
                HeartButton(productId: product.id, size: 44),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(product: product, isMine: isMine),
          ),
        ],
      ),
    );
  }
}

void copyAndNotify(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  context.showSnack('${context.tr('copied')}: $text', type: SnackType.success);
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: p.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: context.text.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow(
      {required this.commentsCount,
      required this.onShare,
      required this.onCopy,
      required this.onComments});
  final int commentsCount;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, VoidCallback onTap, Color color,
            {String? badge}) =>
        Expanded(
          child: Pressable(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: context.palette.border),
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      if (badge != null)
                        Positioned(
                          top: -6,
                          right: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: const BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: AppRadius.pillAll),
                            child: Text(badge,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      style: context.text.labelSmall?.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        tile(Icons.ios_share_rounded, context.tr('share'), onShare,
            AppColors.primary),
        const SizedBox(width: 10),
        tile(
            Icons.link_rounded, context.tr('copyLink'), onCopy, AppColors.teal),
        const SizedBox(width: 10),
        tile(Icons.chat_bubble_outline_rounded, context.tr('comments'),
            onComments, AppColors.mint,
            badge: commentsCount > 0 ? '$commentsCount' : null),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: p.border)),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
                gradient: AppColors.forestGradient,
                borderRadius: AppRadius.lgAll),
            child: const Icon(Icons.location_on_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.cityName, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(product.regionName, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.product, required this.isMine});
  final Product product;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = product.seller;
    return Pressable(
      scale: 0.98,
      onTap: isMine
          ? () => context.go('/profile')
          : () => context.push('/user/${s.id}', extra: s),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: p.border)),
        child: Row(
          children: [
            AppAvatar(url: s.avatarUrl, name: s.fullName, size: 52, ring: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('seller'), style: context.text.bodySmall),
                  const SizedBox(height: 2),
                  Text(s.fullName, style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 15, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(context.tr('verified'),
                          style: context.text.labelSmall
                              ?.copyWith(color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _MessengerButton extends StatelessWidget {
  const _MessengerButton(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.lgAll),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Text(label,
                  style: context.text.labelLarge?.copyWith(color: color)),
            ],
          ),
        ),
      );
}

class _BottomBar extends ConsumerStatefulWidget {
  const _BottomBar({required this.product, required this.isMine});
  final Product product;
  final bool isMine;

  @override
  ConsumerState<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<_BottomBar> {
  bool _opening = false;

  Future<void> _chat() async {
    setState(() => _opening = true);
    await openChatWith(context, ref, widget.product.seller,
        productId: widget.product.id);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? bottom - 4 : 12),
      child: Glass(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(8),
        child: widget.isMine
            ? AppButton(
                label: context.tr('editAd'),
                icon: Icons.edit_rounded,
                onPressed: () => context.push('/edit/${widget.product.id}',
                    extra: widget.product),
              )
            : !widget.product.buyable
                // Договорная / даром — сразу к разговору с продавцом.
                ? AppButton(
                    label: context.tr('goToChat'),
                    icon: Icons.chat_bubble_rounded,
                    loading: _opening,
                    onPressed: _chat,
                  )
                : Row(
                    children: [
                      Pressable(
                        onTap: _opening ? null : _chat,
                        scale: 0.9,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: _opening
                              ? const Padding(
                                  padding: EdgeInsets.all(19),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4),
                                )
                              : const Icon(Icons.chat_bubble_outline_rounded,
                                  color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: context.tr('addToCart'),
                          icon: Icons.shopping_bag_outlined,
                          variant: AppButtonVariant.lime,
                          onPressed: () => openBuyFlow(
                              context, ref, widget.product,
                              buyNow: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: context.tr('buyNow'),
                          icon: Icons.flash_on_rounded,
                          onPressed: () => openBuyFlow(
                              context, ref, widget.product,
                              buyNow: true),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ShimmerWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Bone(width: w, height: w * 1.08, radius: 0),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 180, height: 30),
                SizedBox(height: 14),
                Bone(width: double.infinity, height: 18),
                SizedBox(height: 8),
                Bone(width: 200, height: 18),
                SizedBox(height: 24),
                Bone(width: double.infinity, height: 90, radius: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Варианты товара на экране товара: «Цвет ● ● ●», «Модель 13 · 14 · 15».
class _OptionsPreview extends StatelessWidget {
  const _OptionsPreview({required this.product, this.onTap});
  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(context.tr('variants'),
                      style: context.text.headlineSmall),
                ),
                if (onTap != null)
                  Text(context.tr('chooseVariant'),
                      style: context.text.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800)),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
              ],
            ),
            for (final o in product.options) ...[
              const SizedBox(height: 12),
              Text('${o.name} · ${o.values.length}',
                  style: context.text.labelMedium
                      ?.copyWith(color: p.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in o.values)
                    o.kind == OptionKind.color
                        ? Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: optionColor(v.color),
                              shape: BoxShape.circle,
                              border: Border.all(color: p.border, width: 1.5),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: p.surface2,
                              borderRadius: AppRadius.pillAll,
                            ),
                            child: Text(v.label,
                                style: context.text.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
