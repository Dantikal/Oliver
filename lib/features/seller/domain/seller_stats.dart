/// Сводка продавца за период (GET /me/seller-stats?days=N).
class SellerStats {
  const SellerStats({
    required this.days,
    required this.viewsByDay,
    required this.views,
    required this.favorites,
    required this.chats,
    required this.prevViews,
    required this.prevFavorites,
    required this.prevChats,
  });

  final int days;

  /// Просмотры по дням, последний элемент — сегодня.
  final List<int> viewsByDay;
  final int views;
  final int favorites;
  final int chats;

  /// Те же метрики за предыдущий такой же период — для «▲ 12%».
  final int prevViews;
  final int prevFavorites;
  final int prevChats;

  factory SellerStats.fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] ?? 0) as int;
    return SellerStats(
      days: i('days'),
      viewsByDay: [
        for (final v in (j['viewsByDay'] ?? const []) as List) v as int
      ],
      views: i('views'),
      favorites: i('favorites'),
      chats: i('chats'),
      prevViews: i('prevViews'),
      prevFavorites: i('prevFavorites'),
      prevChats: i('prevChats'),
    );
  }
}

/// Изменение к прошлому периоду в процентах (null — сравнивать не с чем).
int? deltaPercent(int now, int prev) =>
    prev == 0 ? null : ((now - prev) / prev * 100).round();

abstract class SellerRepository {
  Future<SellerStats> stats(int days);
}
