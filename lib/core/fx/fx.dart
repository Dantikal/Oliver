import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../storage/prefs.dart';
import '../../features/catalog/domain/product.dart';
import '../utils/formatters.dart';

/// Валюты, которые показываем в курсах и конвертере.
const fxCodes = ['USD', 'EUR', 'RUB', 'KZT', 'CNY'];

const _symbols = {
  'KGS': 'сом',
  'USD': '\$',
  'EUR': '€',
  'RUB': '₽',
  'KZT': '₸',
  'CNY': '¥',
};

/// Официальные курсы НБКР: сколько сомов стоит 1 единица валюты.
class FxRates {
  const FxRates({
    required this.date,
    required this.kgsPer,
    this.prev = const {},
    this.stale = false,
  });

  final DateTime date;
  final Map<String, double> kgsPer;

  /// Предыдущий курс — для стрелок ▲▼.
  final Map<String, double> prev;

  /// true — показан сохранённый или встроенный курс (нет сети).
  final bool stale;

  double rate(String code) => code == 'KGS' ? 1 : (kgsPer[code] ?? 0);

  double convert(double amount, String from, String to) {
    final r = rate(to);
    return r == 0 ? 0 : amount * rate(from) / r;
  }

  /// >0 — вырос, <0 — упал, 0 — без изменений или нет данных.
  double change(String code) {
    final p = prev[code];
    final c = kgsPer[code];
    if (p == null || c == null) return 0;
    return c - p;
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'rates': kgsPer,
        'prev': prev,
      };

  static FxRates? fromJson(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      Map<String, double> m(Object? v) => {
            for (final e in (v as Map? ?? {}).entries)
              e.key as String: (e.value as num).toDouble()
          };
      return FxRates(
        date: DateTime.parse(j['date'] as String),
        kgsPer: m(j['rates']),
        prev: m(j['prev']),
        stale: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Встроенный запасной курс (НБКР, 16.10.2026) — если ни сети, ни кеша.
  static final fallback = FxRates(
    date: DateTime(2026, 10, 16),
    kgsPer: const {
      'USD': 87.45,
      'EUR': 98.0839,
      'RUB': 1.0409,
      'KZT': 0.1926,
      'CNY': 13.0689,
    },
    stale: true,
  );
}

final fxRatesProvider =
    NotifierProvider<FxRatesNotifier, FxRates>(FxRatesNotifier.new);

class FxRatesNotifier extends Notifier<FxRates> {
  static const _key = 'fx_rates';
  static const _url = 'https://www.nbkr.kg/XML/daily.xml';

  @override
  FxRates build() {
    Future.microtask(refresh);
    return FxRates.fromJson(ref.read(sharedPrefsProvider).getString(_key)) ??
        FxRates.fallback;
  }

  Future<void> refresh() async {
    try {
      final r = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        responseType: ResponseType.bytes,
      )).get<List<int>>(_url);
      // Файл в windows-1251, но нужные поля — ASCII.
      final xml = latin1.decode(r.data!);
      final rates = <String, double>{};
      for (final m in RegExp(
              r'ISOCode="(\w+)">\s*<Nominal>(\d+)</Nominal>\s*<Value>([\d,\.]+)</Value>')
          .allMatches(xml)) {
        final value = double.parse(m[3]!.replaceAll(',', '.'));
        rates[m[1]!] = value / int.parse(m[2]!);
      }
      final d = RegExp(r'Date="(\d{2})\.(\d{2})\.(\d{4})"').firstMatch(xml);
      if (rates.isEmpty || d == null) return;
      final date =
          DateTime(int.parse(d[3]!), int.parse(d[2]!), int.parse(d[1]!));
      final old = state;
      // Прошлый курс берём только с другой даты, иначе стрелки «залипнут» на 0.
      final prev = isSameDay(old.date, date) ? old.prev : old.kgsPer;
      state = FxRates(date: date, kgsPer: rates, prev: prev);
      ref.read(sharedPrefsProvider).setString(_key, jsonEncode(state.toJson()));
    } catch (_) {
      // Остаёмся на кеше/встроенном курсе.
    }
  }
}

/// В какой валюте показывать цены в ленте.
enum PriceDisplay { original, kgs, usd }

final priceDisplayProvider =
    NotifierProvider<PriceDisplayNotifier, PriceDisplay>(
        PriceDisplayNotifier.new);

class PriceDisplayNotifier extends Notifier<PriceDisplay> {
  static const _key = 'price_display';

  @override
  PriceDisplay build() {
    final v = ref.read(sharedPrefsProvider).getString(_key);
    return PriceDisplay.values
        .firstWhere((e) => e.name == v, orElse: () => PriceDisplay.original);
  }

  void set(PriceDisplay v) {
    state = v;
    ref.read(sharedPrefsProvider).setString(_key, v.name);
  }
}

/// Сумма в валюте: «2 055 000 сом», «$23 500», «€1 200».
String formatMoney(BuildContext c, double amount, String code) {
  final n = formatNumber(amount.roundToDouble());
  return switch (code) {
    'KGS' => '$n ${c.tr('som')}',
    'USD' || 'EUR' || 'CNY' => '${_symbols[code]}$n',
    _ => '$n ${_symbols[code] ?? code}',
  };
}

String fxSymbol(String code) => _symbols[code] ?? code;

/// Курс с 2–4 знаками: 87.45, 0.1926.
String formatRate(double v) =>
    v >= 10 ? v.toStringAsFixed(2) : v.toStringAsFixed(4);

/// Цена объявления с учётом выбранной валюты показа.
/// approx = true — сумма пересчитана по курсу и помечается «≈».
({String text, bool approx}) displayPrice(
    BuildContext c, Product p, PriceDisplay display, FxRates fx) {
  final original = (text: formatPrice(c, p.price, p.currency), approx: false);
  if (p.currency.isPriceless || p.price == null) return original;
  final from = p.currency.api;
  final to = switch (display) {
    PriceDisplay.original => from,
    PriceDisplay.kgs => 'KGS',
    PriceDisplay.usd => 'USD',
  };
  if (to == from) return original;
  return (
    text: '≈ ${formatMoney(c, fx.convert(p.price!, from, to), to)}',
    approx: true
  );
}

/// Эквивалент в «другой» валюте для экрана товара: $ → сом, сом → $.
String? priceEquivalent(BuildContext c, Product p, FxRates fx) {
  if (p.currency.isPriceless || p.price == null) return null;
  final from = p.currency.api;
  final to = from == 'USD' ? 'KGS' : 'USD';
  return '≈ ${formatMoney(c, fx.convert(p.price!, from, to), to)}';
}
