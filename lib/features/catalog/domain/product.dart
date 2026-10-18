import '../../auth/domain/user.dart';

enum Currency {
  kgs('KGS'),
  usd('USD'),
  negotiable('NEGOTIABLE'),

  /// «Отдам даром» — вещь отдаётся бесплатно.
  free('FREE');

  const Currency(this.api);
  final String api;

  /// Варианты, которые продавец выбирает в поле цены. «Даром» ставится
  /// автоматически разделом «Отдам даром».
  static const priced = [kgs, usd, negotiable];

  /// Без суммы: договорная или даром.
  bool get isPriceless => this == negotiable || this == free;

  static Currency fromApi(String? v) => Currency.values
      .firstWhere((c) => c.api == v?.toUpperCase(), orElse: () => Currency.kgs);
}

/// Статус объявления в кабинете продавца.
enum ProductStatus {
  active('ACTIVE'),
  sold('SOLD'),
  archived('ARCHIVED');

  const ProductStatus(this.api);
  final String api;

  static ProductStatus fromApi(String? v) =>
      ProductStatus.values.firstWhere((s) => s.api == v?.toUpperCase(),
          orElse: () => ProductStatus.active);
}

enum MediaType {
  image('IMAGE'),
  video('VIDEO');

  const MediaType(this.api);
  final String api;

  static MediaType fromApi(String? v) =>
      v?.toUpperCase() == 'VIDEO' ? MediaType.video : MediaType.image;
}

/// Как показывать значения варианта: текстом или цветным кружком.
enum OptionKind {
  text('TEXT'),
  color('COLOR');

  const OptionKind(this.api);
  final String api;

  static OptionKind fromApi(String? v) =>
      v?.toUpperCase() == 'COLOR' ? OptionKind.color : OptionKind.text;
}

/// Одно значение варианта: «iPhone 15» или «Чёрный» (+ цвет #RRGGBB).
class OptionValue {
  const OptionValue({required this.label, this.color});
  final String label;
  final String? color;

  factory OptionValue.fromJson(Map<String, dynamic> j) => OptionValue(
      label: (j['label'] ?? '') as String, color: j['color'] as String?);

  Map<String, dynamic> toJson() =>
      {'label': label, if (color != null) 'color': color};
}

/// Группа вариантов товара: «Модель», «Цвет», «Размер»…
/// Покупатель выбирает по одному значению из каждой группы.
class ProductOption {
  const ProductOption(
      {required this.name,
      this.kind = OptionKind.text,
      this.values = const []});
  final String name;
  final OptionKind kind;
  final List<OptionValue> values;

  ProductOption copyWith({String? name, List<OptionValue>? values}) =>
      ProductOption(
          name: name ?? this.name, kind: kind, values: values ?? this.values);

  factory ProductOption.fromJson(Map<String, dynamic> j) => ProductOption(
        name: (j['name'] ?? '') as String,
        kind: OptionKind.fromApi(j['kind'] as String?),
        values: [
          for (final v in (j['values'] ?? const []) as List)
            OptionValue.fromJson(Map<String, dynamic>.from(v as Map))
        ],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.api,
        'values': values.map((v) => v.toJson()).toList(),
      };

  static List<ProductOption> listFromJson(dynamic v) => [
        for (final o in (v ?? const []) as List)
          ProductOption.fromJson(Map<String, dynamic>.from(o as Map))
      ];
}

class MediaItem {
  const MediaItem(
      {required this.id,
      required this.url,
      required this.type,
      this.thumbnailUrl});

  final String id;
  final String url;
  final MediaType type;
  final String? thumbnailUrl;

  bool get isVideo => type == MediaType.video;

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: (j['mediaId'] ?? j['id']).toString(),
        url: j['url'] as String,
        type: MediaType.fromApi(j['type'] as String?),
        thumbnailUrl: j['thumbnailUrl'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'mediaId': id, 'url': url, 'type': type.api};
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.categoryId,
    required this.categoryName,
    required this.regionId,
    required this.regionName,
    required this.cityId,
    required this.cityName,
    required this.media,
    required this.seller,
    required this.createdAt,
    this.phone,
    this.whatsappLink,
    this.telegramLink,
    this.isFavorite = false,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.status = ProductStatus.active,
    this.options = const [],
  });

  final String id;
  final String title;
  final String description;
  final double? price;
  final Currency currency;
  final String categoryId;
  final String categoryName;
  final String regionId;
  final String regionName;
  final String cityId;
  final String cityName;
  final String? phone;
  final String? whatsappLink;
  final String? telegramLink;
  final List<MediaItem> media;
  final User seller;
  final DateTime createdAt;
  final bool isFavorite;
  final int commentsCount;
  final int viewsCount;
  final int likesCount;
  final ProductStatus status;
  final List<ProductOption> options;

  /// Покупка в один тап имеет смысл, только если есть цена.
  bool get buyable => !currency.isPriceless && (price ?? 0) > 0;

  String? get coverUrl {
    for (final m in media) {
      if (!m.isVideo) return m.url;
    }
    return media.isNotEmpty
        ? (media.first.thumbnailUrl ?? media.first.url)
        : null;
  }

  bool get hasVideo => media.any((m) => m.isVideo);
  int get photoCount => media.where((m) => !m.isVideo).length;
  String get location =>
      cityName == regionName ? cityName : '$cityName, $regionName';

  static String _name(dynamic v) =>
      v is Map ? (v['name'] ?? '').toString() : '';
  static String _id(dynamic v, dynamic fallback) =>
      (v is Map ? v['id'] : fallback)?.toString() ?? '';

  factory Product.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] is Map ? j['location'] as Map : const {};
    final region = j['region'] ?? loc['region'];
    final city = j['city'] ?? loc['city'];
    return Product(
      id: j['id'].toString(),
      title: (j['title'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      price: (j['price'] as num?)?.toDouble(),
      currency: Currency.fromApi(j['currency'] as String?),
      categoryId: _id(j['category'], j['categoryId']),
      categoryName: (j['categoryName'] ?? _name(j['category'])) as String,
      regionId: _id(region, j['regionId']),
      regionName: (j['regionName'] ?? _name(region)) as String,
      cityId: _id(city, j['cityId']),
      cityName: (j['cityName'] ?? _name(city)) as String,
      phone: j['phone'] as String?,
      whatsappLink: j['whatsappLink'] as String?,
      telegramLink: j['telegramLink'] as String?,
      media: ((j['media'] ?? const []) as List)
          .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      seller: j['seller'] is Map
          ? User.fromJson(Map<String, dynamic>.from(j['seller'] as Map))
          : const User(id: '', fullName: ''),
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      isFavorite: (j['isFavorite'] ?? false) as bool,
      commentsCount: (j['commentsCount'] ?? 0) as int,
      viewsCount: (j['viewsCount'] ?? 0) as int,
      likesCount: (j['likesCount'] ?? 0) as int,
      status: ProductStatus.fromApi(j['status'] as String?),
      options: ProductOption.listFromJson(j['options']),
    );
  }

  Product copyWith({
    String? title,
    String? description,
    double? price,
    Currency? currency,
    String? categoryId,
    String? categoryName,
    String? regionId,
    String? regionName,
    String? cityId,
    String? cityName,
    String? phone,
    String? whatsappLink,
    String? telegramLink,
    List<MediaItem>? media,
    int? commentsCount,
    ProductStatus? status,
    DateTime? createdAt,
    List<ProductOption>? options,
  }) =>
      Product(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        price: price ?? this.price,
        currency: currency ?? this.currency,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        regionId: regionId ?? this.regionId,
        regionName: regionName ?? this.regionName,
        cityId: cityId ?? this.cityId,
        cityName: cityName ?? this.cityName,
        phone: phone ?? this.phone,
        whatsappLink: whatsappLink ?? this.whatsappLink,
        telegramLink: telegramLink ?? this.telegramLink,
        media: media ?? this.media,
        seller: seller,
        createdAt: createdAt ?? this.createdAt,
        isFavorite: isFavorite,
        commentsCount: commentsCount ?? this.commentsCount,
        viewsCount: viewsCount,
        likesCount: likesCount,
        status: status ?? this.status,
        options: options ?? this.options,
      );
}

/// Тело запроса POST/PATCH /products.
class ProductDraft {
  const ProductDraft({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.currency,
    required this.regionId,
    required this.cityId,
    required this.phone,
    this.whatsappLink,
    this.telegramLink,
    required this.media,
    this.options = const [],
  });

  final String title;
  final String description;
  final String categoryId;
  final double? price;
  final Currency currency;
  final String regionId;
  final String cityId;
  final String phone;
  final String? whatsappLink;
  final String? telegramLink;
  final List<MediaItem> media;
  final List<ProductOption> options;

  /// Тело PATCH из существующего объявления — для быстрых правок (цена и т.п.).
  factory ProductDraft.fromProduct(Product p,
          {double? price, Currency? currency}) =>
      ProductDraft(
        title: p.title,
        description: p.description,
        categoryId: p.categoryId,
        price: price ?? p.price,
        currency: currency ?? p.currency,
        regionId: p.regionId,
        cityId: p.cityId,
        phone: p.phone ?? '',
        whatsappLink: p.whatsappLink,
        telegramLink: p.telegramLink,
        media: p.media,
        options: p.options,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'price': currency.isPriceless ? null : price,
        'currency': currency.api,
        'regionId': regionId,
        'cityId': cityId,
        'phone': phone,
        'whatsappLink': whatsappLink,
        'telegramLink': telegramLink,
        'media': media.map((m) => m.toJson()).toList(),
        'options': options.map((o) => o.toJson()).toList(),
      };
}

enum ProductSort {
  newest('createdAt,desc'),
  cheap('price,asc'),
  expensive('price,desc');

  const ProductSort(this.api);
  final String api;
}

class ProductFilter {
  const ProductFilter({
    this.q = '',
    this.categoryId,
    this.regionId,
    this.cityId,
    this.currency,
    this.minPrice,
    this.maxPrice,
    this.hasVideo = false,
    this.sort = ProductSort.newest,
  });

  final String q;
  final String? categoryId;
  final String? regionId;
  final String? cityId;
  final Currency? currency;
  final double? minPrice;
  final double? maxPrice;

  /// Только объявления с видео.
  final bool hasVideo;
  final ProductSort sort;

  /// Количество активных фильтров (без поиска и категории — они видны на экране).
  int get activeCount =>
      [regionId, currency, minPrice, maxPrice].where((e) => e != null).length +
      (hasVideo ? 1 : 0) +
      (sort != ProductSort.newest ? 1 : 0);

  bool get isDefault => q.isEmpty && categoryId == null && activeCount == 0;

  ProductFilter copyWith({
    String? q,
    String? Function()? categoryId,
    String? Function()? regionId,
    String? Function()? cityId,
    Currency? Function()? currency,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    bool? hasVideo,
    ProductSort? sort,
  }) =>
      ProductFilter(
        q: q ?? this.q,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        regionId: regionId != null ? regionId() : this.regionId,
        cityId: cityId != null ? cityId() : this.cityId,
        currency: currency != null ? currency() : this.currency,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        hasVideo: hasVideo ?? this.hasVideo,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toQuery(int page, int size) => {
        if (q.isNotEmpty) 'q': q,
        if (categoryId != null) 'categoryId': categoryId,
        if (regionId != null) 'regionId': regionId,
        if (cityId != null) 'cityId': cityId,
        if (currency != null) 'currency': currency!.api,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (hasVideo) 'hasVideo': true,
        'page': page,
        'size': size,
        'sort': sort.api,
      };
}
