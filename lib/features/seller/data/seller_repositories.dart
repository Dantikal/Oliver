import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/seller_stats.dart';

final sellerRepositoryProvider = Provider<SellerRepository>((ref) =>
    AppConfig.useMock
        ? MockSellerRepository()
        : SellerRepositoryImpl(ref.watch(dioProvider)));

/// Статистика за 7 или 30 дней.
final sellerStatsProvider =
    FutureProvider.autoDispose.family<SellerStats, int>((ref, days) {
  return ref.watch(sellerRepositoryProvider).stats(days);
});

class SellerRepositoryImpl implements SellerRepository {
  SellerRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<SellerStats> stats(int days) => apiCall(() async {
        final r =
            await _dio.get('/me/seller-stats', queryParameters: {'days': days});
        return SellerStats.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
}

class MockSellerRepository implements SellerRepository {
  final _db = MockDb.instance;

  @override
  Future<SellerStats> stats(int days) async {
    await _db.delay(300, 600);
    final mine = _db.products.where((p) => p.seller.id == MockDb.meId);
    final total = mine.fold<int>(0, (s, p) => s + p.viewsCount);
    final likes = mine.fold<int>(0, (s, p) => s + p.likesCount);
    // Стабильная «живая» кривая: выходные чуть выше, лёгкий рост к сегодня.
    final rnd = Random(days);
    final now = DateTime.now();
    final perDay = total / 30;
    final byDay = [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = now.subtract(Duration(days: i));
          final weekend = d.weekday >= 6 ? 1.25 : 1.0;
          final trend = 0.8 + 0.4 * (1 - i / days);
          return (perDay * weekend * trend * (0.7 + rnd.nextDouble() * 0.6))
              .round();
        }()
    ];
    final views = byDay.fold<int>(0, (s, v) => s + v);
    final chats = _db.chats.length + (days > 7 ? 9 : 2);
    final favorites = (likes * days / 30).round();
    return SellerStats(
      days: days,
      viewsByDay: byDay,
      views: views,
      favorites: favorites,
      chats: chats,
      prevViews: (views * 0.86).round(),
      prevFavorites: (favorites * 1.08).round(),
      prevChats: (chats * 0.75).round(),
    );
  }
}
