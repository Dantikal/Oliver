import '../../catalog/domain/product.dart';

/// Отдел магазина: название, иконка и упорядоченный список товаров.
class StoreSection {
  const StoreSection({
    required this.id,
    required this.name,
    this.icon = 'tag',
    this.productIds = const [],
  });

  final String id;
  final String name;
  final String icon;

  /// Порядок, заданный продавцом.
  final List<String> productIds;

  StoreSection copyWith(
          {String? name, String? icon, List<String>? productIds}) =>
      StoreSection(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        productIds: productIds ?? this.productIds,
      );

  factory StoreSection.fromJson(Map<String, dynamic> j) => StoreSection(
        id: j['id'].toString(),
        name: (j['name'] ?? '') as String,
        icon: (j['icon'] ?? 'tag') as String,
        productIds: [
          for (final id in (j['productIds'] ?? const []) as List) id.toString()
        ],
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'icon': icon, 'productIds': productIds};
}

/// Личный магазин продавца.
class Store {
  const Store({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.pickup = true,
    this.delivery = false,
    this.sections = const [],
    this.featuredIds = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final bool pickup;
  final bool delivery;
  final List<StoreSection> sections;

  /// «Хиты» — товары, закреплённые наверху витрины.
  final List<String> featuredIds;

  /// Отдел, в котором лежит товар (товар — максимум в одном отделе).
  StoreSection? sectionOf(String productId) {
    for (final s in sections) {
      if (s.productIds.contains(productId)) return s;
    }
    return null;
  }

  Store copyWith({
    String? name,
    String? description,
    bool? pickup,
    bool? delivery,
    List<StoreSection>? sections,
    List<String>? featuredIds,
  }) =>
      Store(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        description: description ?? this.description,
        pickup: pickup ?? this.pickup,
        delivery: delivery ?? this.delivery,
        sections: sections ?? this.sections,
        featuredIds: featuredIds ?? this.featuredIds,
      );

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'].toString(),
        ownerId: j['ownerId'].toString(),
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        pickup: (j['pickup'] ?? true) as bool,
        delivery: (j['delivery'] ?? false) as bool,
        sections: [
          for (final s in (j['sections'] ?? const []) as List)
            StoreSection.fromJson(Map<String, dynamic>.from(s as Map))
        ],
        featuredIds: [
          for (final id in (j['featuredIds'] ?? const []) as List) id.toString()
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'description': description,
        'pickup': pickup,
        'delivery': delivery,
        'sections': [for (final s in sections) s.toJson()],
        'featuredIds': featuredIds,
      };
}

/// Сортировка витрины для покупателя.
enum StoreSort { seller, newest, cheap, expensive, popular }

/// Товары в порядке выбранной сортировки; [manual] — порядок продавца.
List<Product> sortStoreProducts(
    List<Product> items, StoreSort sort, List<String> manual) {
  final list = [...items];
  int pos(Product p) {
    final i = manual.indexOf(p.id);
    return i < 0 ? 1 << 30 : i;
  }

  double price(Product p) => p.price ?? double.infinity;
  switch (sort) {
    case StoreSort.seller:
      list.sort((a, b) => pos(a).compareTo(pos(b)));
    case StoreSort.newest:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case StoreSort.cheap:
      list.sort((a, b) => price(a).compareTo(price(b)));
    case StoreSort.expensive:
      list.sort((a, b) => (b.price ?? -1).compareTo(a.price ?? -1));
    case StoreSort.popular:
      list.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
  }
  return list;
}

abstract class StoreRepository {
  /// Свой магазин; null — ещё не создан.
  Future<Store?> myStore();
  Future<Store> create({required String name, String description = ''});
  Future<Store> update(
      {String? name, String? description, bool? pickup, bool? delivery});

  /// Магазин пользователя для витрины; null — магазина нет.
  Future<Store?> storeOf(String userId);

  Future<StoreSection> addSection(String name, String icon);
  Future<StoreSection> updateSection(String id, {String? name, String? icon});
  Future<void> deleteSection(String id);
  Future<void> reorderSections(List<String> ids);

  /// Полный упорядоченный список товаров отдела.
  Future<void> setSectionProducts(String sectionId, List<String> productIds);
  Future<void> setFeatured(List<String> productIds);

  /// Все активные товары продавца — для витрины и раскладки по отделам.
  Future<List<Product>> products(String userId);
}
