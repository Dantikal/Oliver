import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/product.dart';

/// Медиа черновика: уже загруженное (url + id) или локальный файл (path).
class DraftMediaData {
  const DraftMediaData({required this.type, this.uploaded, this.path});
  final MediaType type;
  final MediaItem? uploaded;
  final String? path;

  Map<String, dynamic> toJson() => {
        'type': type.api,
        if (uploaded != null)
          'uploaded': {
            ...uploaded!.toJson(),
            'thumbnailUrl': uploaded!.thumbnailUrl
          },
        if (path != null) 'path': path,
      };

  static DraftMediaData? fromJson(Map<String, dynamic> j) {
    final up = j['uploaded'];
    final path = j['path'] as String?;
    // Локальные файлы из tmp iOS может вычистить — такие пропускаем.
    if (up == null && (path == null || !File(path).existsSync())) return null;
    return DraftMediaData(
      type: MediaType.fromApi(j['type'] as String?),
      uploaded:
          up is Map ? MediaItem.fromJson(Map<String, dynamic>.from(up)) : null,
      path: path,
    );
  }
}

/// Незаконченное новое объявление. Хранится на устройстве, пока не опубликовано.
class ListingDraft {
  const ListingDraft({
    this.title = '',
    this.price = '',
    this.description = '',
    this.currency = Currency.kgs,
    this.categoryId,
    this.categoryName,
    this.regionId,
    this.regionName,
    this.cityId,
    this.cityName,
    this.phone = '',
    this.whatsapp = '',
    this.telegram = '',
    this.media = const [],
    this.options = const [],
    required this.updatedAt,
  });

  final String title;
  final String price;
  final String description;
  final Currency currency;
  final String? categoryId;
  final String? categoryName;
  final String? regionId;
  final String? regionName;
  final String? cityId;
  final String? cityName;
  final String phone;
  final String whatsapp;
  final String telegram;
  final List<DraftMediaData> media;
  final List<ProductOption> options;
  final DateTime updatedAt;

  /// Есть что сохранять (телефон из профиля не считается).
  bool get hasContent =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      price.isNotEmpty ||
      categoryId != null ||
      media.isNotEmpty;

  String? get coverPath {
    for (final m in media) {
      if (m.type == MediaType.image) return m.uploaded?.url ?? m.path;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'price': price,
        'description': description,
        'currency': currency.api,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'regionId': regionId,
        'regionName': regionName,
        'cityId': cityId,
        'cityName': cityName,
        'phone': phone,
        'whatsapp': whatsapp,
        'telegram': telegram,
        'media': media.map((m) => m.toJson()).toList(),
        'options': options.map((o) => o.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ListingDraft.fromJson(Map<String, dynamic> j) => ListingDraft(
        title: (j['title'] ?? '') as String,
        price: (j['price'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        currency: Currency.fromApi(j['currency'] as String?),
        categoryId: j['categoryId'] as String?,
        categoryName: j['categoryName'] as String?,
        regionId: j['regionId'] as String?,
        regionName: j['regionName'] as String?,
        cityId: j['cityId'] as String?,
        cityName: j['cityName'] as String?,
        phone: (j['phone'] ?? '') as String,
        whatsapp: (j['whatsapp'] ?? '') as String,
        telegram: (j['telegram'] ?? '') as String,
        media: [
          for (final m in (j['media'] ?? const []) as List)
            if (DraftMediaData.fromJson(Map<String, dynamic>.from(m as Map))
                case final d?)
              d
        ],
        options: ProductOption.listFromJson(j['options']),
        updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
      );
}

final listingDraftProvider =
    NotifierProvider<ListingDraftNotifier, ListingDraft?>(
        ListingDraftNotifier.new);

class ListingDraftNotifier extends Notifier<ListingDraft?> {
  static const _key = 'listing_draft';

  @override
  ListingDraft? build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      final d = ListingDraft.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return d.hasContent ? d : null;
    } catch (_) {
      return null;
    }
  }

  void save(ListingDraft d) {
    if (!d.hasContent) return clear();
    state = d;
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode(d.toJson()));
  }

  void clear() {
    state = null;
    ref.read(sharedPrefsProvider).remove(_key);
  }
}

/// То, что продавец обычно указывает одинаково: место, мессенджеры,
/// последние категории. Подставляется в новые объявления.
class SellerDefaults {
  const SellerDefaults({
    this.regionId,
    this.regionName,
    this.cityId,
    this.cityName,
    this.whatsapp,
    this.telegram,
    this.recentCategories = const [],
  });

  final String? regionId;
  final String? regionName;
  final String? cityId;
  final String? cityName;
  final String? whatsapp;
  final String? telegram;

  /// (id, отображаемое имя), самые свежие первыми.
  final List<(String, String)> recentCategories;

  Map<String, dynamic> toJson() => {
        'regionId': regionId,
        'regionName': regionName,
        'cityId': cityId,
        'cityName': cityName,
        'whatsapp': whatsapp,
        'telegram': telegram,
        'recentCategories': [
          for (final (id, name) in recentCategories) {'id': id, 'name': name}
        ],
      };

  factory SellerDefaults.fromJson(Map<String, dynamic> j) => SellerDefaults(
        regionId: j['regionId'] as String?,
        regionName: j['regionName'] as String?,
        cityId: j['cityId'] as String?,
        cityName: j['cityName'] as String?,
        whatsapp: j['whatsapp'] as String?,
        telegram: j['telegram'] as String?,
        recentCategories: [
          for (final c in (j['recentCategories'] ?? const []) as List)
            ('${(c as Map)['id']}', '${c['name']}')
        ],
      );
}

final sellerDefaultsProvider =
    NotifierProvider<SellerDefaultsNotifier, SellerDefaults>(
        SellerDefaultsNotifier.new);

class SellerDefaultsNotifier extends Notifier<SellerDefaults> {
  static const _key = 'seller_defaults';

  @override
  SellerDefaults build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const SellerDefaults();
    try {
      return SellerDefaults.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const SellerDefaults();
    }
  }

  /// Запомнить после успешной публикации.
  void remember({
    required String regionId,
    required String regionName,
    required String cityId,
    required String cityName,
    required String categoryId,
    required String categoryName,
    String? whatsapp,
    String? telegram,
  }) {
    state = SellerDefaults(
      regionId: regionId,
      regionName: regionName,
      cityId: cityId,
      cityName: cityName,
      whatsapp: whatsapp,
      telegram: telegram,
      recentCategories: [
        (categoryId, categoryName),
        ...state.recentCategories.where((c) => c.$1 != categoryId),
      ].take(4).toList(),
    );
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode(state.toJson()));
  }
}

/// Диапазон цен похожих объявлений: нижний квартиль, медиана, верхний.
class PriceHint {
  const PriceHint(
      {required this.low,
      required this.median,
      required this.high,
      required this.count});
  final double low;
  final double median;
  final double high;
  final int count;
}

/// Подсказка цены по первой странице активных объявлений той же категории
/// и валюты. Без отдельного эндпоинта — обычный GET /products.
final priceHintProvider = FutureProvider.autoDispose
    .family<PriceHint?, (String, Currency)>((ref, key) async {
  final (categoryId, currency) = key;
  if (currency.isPriceless) return null;
  final page = await ref.watch(productRepositoryProvider).getProducts(
      ProductFilter(categoryId: categoryId, currency: currency), 0);
  final prices = {
    for (final p in page.items)
      if (p.price != null && p.price! > 0) p.id.split('~').first: p.price!
  }.values.toList()
    ..sort();
  if (prices.length < 3) return null;
  double at(double q) =>
      prices[min(prices.length - 1, (prices.length * q).floor())];
  return PriceHint(
      low: at(0.25), median: at(0.5), high: at(0.75), count: prices.length);
});
