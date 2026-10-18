import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/fx/fx.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/pressable.dart';

String _date(DateTime d) => '${two(d.day)}.${two(d.month)}';

/// Лента курсов НБКР + переключатель валюты цен. Тап — конвертер.
class FxStrip extends ConsumerWidget {
  const FxStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final fx = ref.watch(fxRatesProvider);
    final display = ref.watch(priceDisplayProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Glass(
        radius: AppRadius.lg,
        child: Column(
          children: [
            Pressable(
              scale: 0.98,
              onTap: () => showConverterSheet(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('fxTitle').toUpperCase(),
                            style: context.text.labelSmall
                                ?.copyWith(color: p.text, letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(
                            fx.stale
                                ? '${_date(fx.date)} · ${context.tr('fxStale')}'
                                : _date(fx.date),
                            style: context.text.bodySmall?.copyWith(
                                color: p.textTertiary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent
                          ],
                          stops: [0, 0.85, 1],
                        ).createShader(r),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              for (final code in fxCodes) _RateChip(code: code),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.currency_exchange_rounded,
                        size: 20, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  Text(context.tr('priceIn'),
                      style: context.text.labelMedium
                          ?.copyWith(color: p.textSecondary)),
                  const Spacer(),
                  for (final d in PriceDisplay.values)
                    _DisplayChip(
                      label: switch (d) {
                        PriceDisplay.original => context.tr('asListed'),
                        PriceDisplay.kgs => context.tr('som'),
                        PriceDisplay.usd => '\$',
                      },
                      selected: d == display,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(priceDisplayProvider.notifier).set(d);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateChip extends ConsumerWidget {
  const _RateChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final fx = ref.watch(fxRatesProvider);
    final ch = fx.change(code);
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          Text(code,
              style: context.text.labelSmall
                  ?.copyWith(color: p.textTertiary, letterSpacing: 0.8)),
          const SizedBox(width: 5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(formatRate(fx.rate(code)),
                key: ValueKey(fx.rate(code)),
                style: context.text.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          if (ch != 0) ...[
            const SizedBox(width: 2),
            Icon(
              ch > 0
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
              size: 18,
              color: ch > 0 ? AppColors.success : AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _DisplayChip extends StatelessWidget {
  const _DisplayChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? p.text : p.surface2,
          borderRadius: AppRadius.pillAll,
        ),
        child: Text(label,
            style: context.text.labelMedium?.copyWith(
                color: selected ? p.bg : p.textSecondary,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Шторка-конвертер: сумма + валюта → все остальные валюты сразу.
Future<void> showConverterSheet(BuildContext context,
    {double? amount, String from = 'USD'}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Converter(amount: amount, from: from),
  );
}

class _Converter extends ConsumerStatefulWidget {
  const _Converter({this.amount, required this.from});
  final double? amount;
  final String from;

  @override
  ConsumerState<_Converter> createState() => _ConverterState();
}

class _ConverterState extends ConsumerState<_Converter> {
  late final _c = TextEditingController(
      text: widget.amount == null ? '100' : widget.amount!.toStringAsFixed(0));
  late String _from = widget.from;

  static const _all = ['KGS', ...fxCodes];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fx = ref.watch(fxRatesProvider);
    final amount =
        double.tryParse(_c.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('converter'), style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Text('${context.tr('fxNote')} ${_date(fx.date)}.${fx.date.year}',
              style: context.text.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s,\.]'))
            ],
            onChanged: (_) => setState(() {}),
            style: context.text.displaySmall
                ?.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: context.tr('amount'),
              suffixText: fxSymbol(_from),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final code in _all)
                _DisplayChip(
                  label: code,
                  selected: code == _from,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _from = code);
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          for (final code in _all.where((c) => c != _from))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(code,
                        style: context.text.labelMedium?.copyWith(
                            color: p.textTertiary, letterSpacing: 0.8)),
                  ),
                  Expanded(
                    child: Text(
                      formatMoney(
                          context, fx.convert(amount, _from, code), code),
                      style: context.text.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                  if (code != 'KGS')
                    Text(
                        '1 $code = ${formatRate(fx.rate(code))} ${context.tr('som')}',
                        style: context.text.bodySmall
                            ?.copyWith(color: p.textTertiary, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
