import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/fx/fx.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/product.dart';
import 'heart_button.dart';

class ProductGridCard extends StatelessWidget {
  const ProductGridCard(
      {super.key,
      required this.product,
      this.trailingMenu,
      this.hero = true,
      this.imageAspect = 0.8});

  final Product product;
  final bool hero;
  final Widget? trailingMenu;

  /// Ширина / высота фото.
  final double imageAspect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      scale: 0.98,
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: imageAspect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                boxShadow: AppShadows.soft(p.shadow, lift: 0.7),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.lgAll,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _maybeHero(hero, product.id, AppImage(product.coverUrl)),
                    // Мягкое затемнение снизу — цена читается на любом фото.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.55, 1],
                          colors: [Colors.transparent, Color(0x66000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: trailingMenu ?? HeartButton(productId: product.id),
                    ),
                    if (product.hasVideo || product.photoCount > 1)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          children: [
                            if (product.hasVideo)
                              const _Chip(
                                  icon: Icons.play_arrow_rounded,
                                  label: 'Video'),
                            if (product.hasVideo && product.photoCount > 1)
                              const SizedBox(width: 4),
                            if (product.photoCount > 1)
                              _Chip(
                                  icon: Icons.photo_library_outlined,
                                  label: '${product.photoCount}'),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: PriceTag(product: product),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Всегда место под 2 строки — ряды карточек не «гуляют».
          ConstrainedBox(
            constraints: BoxConstraints(
                minHeight:
                    MediaQuery.textScalerOf(context).scale(14) * 1.25 * 2),
            child: Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: p.text),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${product.cityName} · ${timeAgo(context, product.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
                color: p.textTertiary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Лаймовая плашка с ценой поверх фото.
class PriceTag extends ConsumerWidget {
  const PriceTag({super.key, required this.product, this.size = 14.5});
  final Product product;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = displayPrice(context, product,
        ref.watch(priceDisplayProvider), ref.watch(fxRatesProvider));
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 11, 5),
      decoration: BoxDecoration(
        gradient: AppColors.limeGradient,
        borderRadius: AppRadius.pillAll,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (product.currency == Currency.free) ...[
            Icon(Icons.volunteer_activism_rounded,
                size: size, color: AppColors.ink),
            const SizedBox(width: 5),
          ],
          Text(
            price.text,
            maxLines: 1,
            style: context.text.titleMedium?.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductListCard extends StatelessWidget {
  const ProductListCard(
      {super.key, required this.product, this.actions, this.hero = true});

  final Product product;
  final bool hero;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      scale: 0.98,
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: ClipRRect(
                borderRadius: AppRadius.lgAll,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _maybeHero(hero, product.id, AppImage(product.coverUrl)),
                    if (product.hasVideo)
                      const Positioned(
                          left: 6,
                          bottom: 6,
                          child: _Chip(
                              icon: Icons.play_arrow_rounded, label: 'Video')),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(fontSize: 15)),
                    const SizedBox(height: 6),
                    PriceText(product: product, size: 17),
                    const Spacer(),
                    LocationLine(text: product.location),
                    const SizedBox(height: 4),
                    Text(timeAgo(context, product.createdAt),
                        style: context.text.bodySmall
                            ?.copyWith(color: p.textTertiary, fontSize: 11.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HeartButton(productId: product.id, glass: false, size: 38),
                if (actions != null) actions!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PriceText extends ConsumerWidget {
  const PriceText({super.key, required this.product, this.size = 16});
  final Product product;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negotiable = product.currency.isPriceless;
    final price = displayPrice(context, product,
        ref.watch(priceDisplayProvider), ref.watch(fxRatesProvider));
    return Text(
      price.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.titleMedium?.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: negotiable ? AppColors.primary : null,
      ),
    );
  }
}

class LocationLine extends StatelessWidget {
  const LocationLine({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: 14, color: p.textTertiary),
        const SizedBox(width: 3),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                  color: p.textTertiary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PhotoGlass(
      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(label == 'Video' ? context.tr('video') : label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Сетка/список товаров как sliver.
class ProductsSliver extends StatelessWidget {
  const ProductsSliver(
      {super.key,
      required this.items,
      required this.grid,
      this.menuBuilder,
      this.hero = true});

  final bool hero;

  final List<Product> items;
  final bool grid;
  final Widget Function(Product)? menuBuilder;

  @override
  Widget build(BuildContext context) {
    if (grid) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 22,
          crossAxisSpacing: 12,
          childCount: items.length,
          itemBuilder: (_, i) => FadeSlideIn(
            index: i % 6,
            child: ProductGridCard(
                product: items[i],
                hero: hero,
                trailingMenu: menuBuilder?.call(items[i])),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => FadeSlideIn(
          index: i % 6,
          child: ProductListCard(
              product: items[i],
              hero: hero,
              actions: menuBuilder?.call(items[i])),
        ),
      ),
    );
  }
}

Widget _maybeHero(bool hero, String id, Widget child) =>
    hero ? Hero(tag: 'product-$id', child: child) : child;
