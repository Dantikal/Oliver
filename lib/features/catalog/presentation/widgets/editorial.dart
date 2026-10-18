import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/product.dart';
import 'product_card.dart';

/// Бесконечная бегущая строка на лаймовой ленте.
class TickerBand extends StatefulWidget {
  const TickerBand({
    super.key,
    required this.text,
    this.color = AppColors.lime,
    this.textColor = AppColors.ink,
    this.speed = 40,
    this.tilt = 0,
  });

  final String text;
  final Color color;
  final Color textColor;

  /// Пикселей в секунду.
  final double speed;

  /// Наклон ленты в радианах — для «журнального» эффекта.
  final double tilt;

  @override
  State<TickerBand> createState() => _TickerBandState();
}

class _TickerBandState extends State<TickerBand>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();
  double _unit = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelLarge!.copyWith(
      color: widget.textColor,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      fontSize: 13,
    );
    final chunk = '${widget.text.toUpperCase()}   ✦   ';
    final tp = TextPainter(
        text: TextSpan(text: chunk, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1)
      ..layout();
    if (tp.width != _unit) {
      _unit = tp.width;
      _c.duration =
          Duration(milliseconds: (_unit / widget.speed * 1000).round());
      _c.repeat();
    }
    return Transform.rotate(
      angle: widget.tilt,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient:
              widget.color == AppColors.lime ? AppColors.limeGradient : null,
          color: widget.color == AppColors.lime ? null : widget.color,
          boxShadow: AppShadows.glow(widget.color, strength: 0.6),
        ),
        alignment: Alignment.centerLeft,
        child: ClipRect(
          child: LayoutBuilder(builder: (context, c) {
            final copies = (c.maxWidth / _unit).ceil() + 2;
            return AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.translate(
                  offset: Offset(-_unit * _c.value, 0), child: child),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < copies; i++)
                      Text(chunk, style: style, maxLines: 1),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Журнальный заголовок раздела: номер, крупный serif-заголовок, подпись.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String number;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.lime : AppColors.ink,
                borderRadius: AppRadius.pillAll,
              ),
              child: Text(number,
                  style: context.text.labelSmall?.copyWith(
                      color: context.isDark ? AppColors.ink : AppColors.lime,
                      letterSpacing: 1,
                      fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [p.text.withValues(alpha: 0.35), p.border]),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
        const SizedBox(height: 12),
        Text(title,
            style: context.text.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.05)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
        ],
      ],
    );
  }
}

/// Карусель «Выбор редакции»: крупные карточки с параллаксом фото.
class EditorsPickCarousel extends StatefulWidget {
  const EditorsPickCarousel({super.key, required this.products});
  final List<Product> products;

  @override
  State<EditorsPickCarousel> createState() => _EditorsPickCarouselState();
}

class _EditorsPickCarouselState extends State<EditorsPickCarousel> {
  final _pc = PageController(viewportFraction: 0.8);
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = widget.products;
    final height = MediaQuery.sizeOf(context).width * 0.95;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pc,
            padEnds: false,
            itemCount: items.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _page = i);
            },
            itemBuilder: (_, i) => AnimatedBuilder(
              animation: _pc,
              builder: (context, child) {
                final page = _pc.hasClients && _pc.position.haveDimensions
                    ? _pc.page ?? 0
                    : 0.0;
                final delta = (i - page).clamp(-1.0, 1.0);
                // Соседние карточки уходят в глубину с лёгким 3D-поворотом.
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
                  child: Transform(
                    alignment: delta > 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(-0.28 * delta)
                      ..scaleByDouble(
                          1 - 0.08 * delta.abs(), 1 - 0.08 * delta.abs(), 1, 1),
                    child: _PickCard(
                      product: items[i],
                      index: i,
                      total: items.length,
                      parallax: delta,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Индикатор: квадратики, активный вытягивается в лаймовую полоску.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 28 : 7,
                height: 7,
                decoration: BoxDecoration(
                  gradient: i == _page ? AppColors.limeGradient : null,
                  color: i == _page ? null : p.surface3,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.product,
    required this.index,
    required this.total,
    required this.parallax,
  });

  final Product product;
  final int index;
  final int total;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Pressable(
      scale: 0.98,
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlAll,
          boxShadow: AppShadows.soft(context.palette.shadow, lift: 1.4),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.xlAll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фото шире карточки и смещается против прокрутки — параллакс.
              LayoutBuilder(
                builder: (_, c) => OverflowBox(
                  minWidth: c.maxWidth * 1.35,
                  maxWidth: c.maxWidth * 1.35,
                  child: Transform.translate(
                    offset: Offset(parallax * 60, 0),
                    child: AppImage(product.coverUrl),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Colors.transparent, Color(0xD90E1A13)],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: PhotoGlass(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text('${two(index + 1)} / ${two(total)}',
                      style: context.text.labelSmall
                          ?.copyWith(color: Colors.white, letterSpacing: 1.2)),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineMedium?.copyWith(
                          color: AppColors.cream,
                          fontWeight: FontWeight.w700,
                          height: 1.08),
                    ),
                    const SizedBox(height: 6),
                    Text(product.cityName.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(
                            color: AppColors.cream.withValues(alpha: 0.7),
                            letterSpacing: 1.4)),
                    const SizedBox(height: 12),
                    PriceTag(product: product, size: 17),
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
