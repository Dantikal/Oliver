class ProductCategory {
  const ProductCategory(
      {required this.id,
      required this.name,
      this.children = const [],
      this.icon});

  final String id;
  final String name;
  final List<ProductCategory> children;
  final String? icon;

  /// Раздел «Отдам даром» (бэкенд помечает его иконкой `gift`).
  bool get isGiveaway => icon == 'gift' || icon == '🎁';

  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
        id: j['id'].toString(),
        name: j['name'] as String,
        icon: j['icon'] as String?,
        children: ((j['children'] ?? const []) as List)
            .map((e) =>
                ProductCategory.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Region {
  const Region({required this.id, required this.name});
  final String id;
  final String name;

  factory Region.fromJson(Map<String, dynamic> j) =>
      Region(id: j['id'].toString(), name: j['name'] as String);
}

class City {
  const City({required this.id, required this.name});
  final String id;
  final String name;

  factory City.fromJson(Map<String, dynamic> j) =>
      City(id: j['id'].toString(), name: j['name'] as String);
}
