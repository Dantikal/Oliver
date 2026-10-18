import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/segmented.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/product.dart';
import '../data/listing_draft.dart';
import 'listing_quality.dart';

void shareListing(Product p) =>
    Share.share('${p.title}\n${AppConfig.shareBaseUrl}/${p.id}');

/// Недописанное объявление — видно в профиле и кабинете, пока не опубликовано.
class ListingDraftCard extends ConsumerWidget {
  const ListingDraftCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(listingDraftProvider);
    final p = context.palette;
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: d == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: () => context.push('/create'),
                scale: 0.98,
                child: Glass(
                  radius: AppRadius.lg,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: d.coverPath == null
                              ? Container(
                                  color: p.surface2,
                                  child: Icon(Icons.edit_note_rounded,
                                      color: p.textTertiary))
                              : AppImage(d.coverPath),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('draft').toUpperCase(),
                                style: context.text.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    letterSpacing: 1.4)),
                            const SizedBox(height: 2),
                            Text(
                                d.title.trim().isEmpty
                                    ? context.tr('untitled')
                                    : d.title.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall),
                            Text(
                                context.tr('savedAgo').replaceAll(
                                    '{t}', timeAgo(context, d.updatedAt)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall
                                    ?.copyWith(color: p.textTertiary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: p.textSecondary),
                        onPressed: () async {
                          final ok = await showConfirmDialog(context,
                              title: context.tr('draftDeleteQ'),
                              message: d.title.trim().isEmpty
                                  ? context.tr('untitled')
                                  : d.title.trim(),
                              confirm: context.tr('delete'),
                              destructive: true,
                              icon: Icons.delete_outline_rounded);
                          if (ok) {
                            ref.read(listingDraftProvider.notifier).clear();
                          }
                        },
                      ),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: AppColors.limeGradient,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(context.tr('continueDraft'),
                            style: context.text.labelMedium?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Смена цены без открытия всей формы. true — цена сохранена.
Future<bool> showQuickPriceSheet(
    BuildContext context, WidgetRef ref, Product product) async {
  final c = TextEditingController(
      text: product.price == null || product.currency.isPriceless
          ? ''
          : product.price!.toStringAsFixed(0));
  // Из «даром» можно перейти только в обычную цену.
  var currency =
      product.currency == Currency.free ? Currency.kgs : product.currency;
  var saving = false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final p = ctx.palette;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              22, 0, 22, MediaQuery.viewInsetsOf(ctx).bottom + 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('changePrice'), style: ctx.text.headlineSmall),
              const SizedBox(height: 4),
              Text(product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ctx.text.bodySmall?.copyWith(color: p.textSecondary)),
              const SizedBox(height: 16),
              AppSegmented<Currency>(
                items: Currency.priced,
                value: currency,
                labelOf: (cur) =>
                    cur == Currency.negotiable ? ctx.tr('negotiable') : cur.api,
                onChanged: (cur) => setSheet(() => currency = cur),
              ),
              if (currency != Currency.negotiable) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: c,
                  hint: '0',
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12)
                  ],
                  prefixIcon: currency == Currency.usd
                      ? Icons.attach_money_rounded
                      : Icons.payments_rounded,
                ),
                Consumer(builder: (_, r, __) {
                  final hint = r
                      .watch(priceHintProvider((product.categoryId, currency)))
                      .valueOrNull;
                  return hint == null
                      ? const SizedBox.shrink()
                      : PriceHintLine(
                          hint: hint,
                          currency: currency,
                          onUse: () => setSheet(
                              () => c.text = hint.median.toStringAsFixed(0)));
                }),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: ctx.tr('save'),
                icon: Icons.check_rounded,
                loading: saving,
                onPressed: () async {
                  final price = double.tryParse(c.text);
                  if (currency != Currency.negotiable &&
                      (price == null || price <= 0)) {
                    HapticFeedback.heavyImpact();
                    return;
                  }
                  setSheet(() => saving = true);
                  try {
                    await ref.read(productRepositoryProvider).update(
                        product.id,
                        ProductDraft.fromProduct(product,
                            price: price, currency: currency));
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setSheet(() => saving = false);
                    if (ctx.mounted) ctx.showError(e);
                  }
                },
              ),
            ],
          ),
        );
      },
    ),
  );
  c.dispose();
  return saved ?? false;
}

/// «Похожие продают за 40 000 – 55 000 сом · обычно 48 000  [Подставить]».
class PriceHintLine extends StatelessWidget {
  const PriceHintLine(
      {super.key,
      required this.hint,
      required this.currency,
      required this.onUse});
  final PriceHint hint;
  final Currency currency;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String f(double v) =>
        currency == Currency.usd ? '\$${formatNumber(v)}' : formatNumber(v);
    final unit = currency == Currency.usd ? '' : ' ${context.tr('som')}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${context.tr('priceHint')} '),
                TextSpan(
                    text: '${f(hint.low)} – ${f(hint.high)}$unit',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(
                    text: ' · ${context.tr('priceTypical')} ${f(hint.median)}'),
              ]),
              style: context.text.bodySmall?.copyWith(color: p.text),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onUse();
            },
            child: Text(context.tr('usePrice'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Полный чек-лист качества: что уже есть и чего не хватает.
Future<void> showQualityChecklist(BuildContext context, Product product,
    {VoidCallback? onImprove}) {
  final q = listingQuality(product);
  return showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final p = ctx.palette;
      final items = [
        (product.title.trim().length >= 12, ctx.tr('tipTitle')),
        for (final t in QualityTip.values)
          (!q.tips.contains(t), ctx.tr(t.l10nKey)),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ctx.tr('qualityChecklist'),
                        style: ctx.text.headlineSmall),
                  ),
                  QualityRing(score: q.score),
                ],
              ),
              const SizedBox(height: 4),
              Text(ctx.tr('qualitySub'),
                  style: ctx.text.bodySmall?.copyWith(color: p.textSecondary)),
              const SizedBox(height: 14),
              for (final (done, label) in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                            color: done ? AppColors.success : p.surface2,
                            shape: BoxShape.circle),
                        child: Icon(
                            done ? Icons.check_rounded : Icons.close_rounded,
                            size: 15,
                            color: done ? Colors.white : p.textTertiary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label,
                            style: ctx.text.bodyMedium?.copyWith(
                                color: done ? p.textSecondary : p.text,
                                decoration:
                                    done ? TextDecoration.lineThrough : null,
                                fontWeight:
                                    done ? FontWeight.w500 : FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              if (onImprove != null && q.tips.isNotEmpty) ...[
                const SizedBox(height: 14),
                AppButton(
                  label: ctx.tr('improve'),
                  icon: Icons.auto_fix_high_rounded,
                  onPressed: () {
                    Navigator.pop(ctx);
                    onImprove();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Color qualityColor(int score) => score >= 80
    ? AppColors.success
    : score >= 50
        ? AppColors.warning
        : AppColors.danger;

/// Кольцо с процентом качества.
class QualityRing extends StatelessWidget {
  const QualityRing({super.key, required this.score, this.size = 46});
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: score / 100),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: t,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: p.surface3,
                color: qualityColor((t * 100).round()),
              ),
            ),
            Text('${(t * 100).round()}',
                style: context.text.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
