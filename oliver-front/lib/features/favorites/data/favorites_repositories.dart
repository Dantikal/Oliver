import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/pagination/paged.dart';
import '../../catalog/domain/product.dart';
import '../domain/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => AppConfig.useMock
      ? MockFavoritesRepository()
      : FavoritesRepositoryImpl(ref.watch(dioProvider)),
);

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<Product>> list(int page, {int size = AppConfig.pageSize}) =>
      apiCall(() async {
        final r = await _dio
            .get('/favorites', queryParameters: {'page': page, 'size': size});
        return PageResult.fromJson(r.data, Product.fromJson);
      });

  @override
  Future<int> count() => apiCall(
      () async => (await _dio.get('/favorites/count')).data['count'] as int);

  @override
  Future<void> add(String productId) =>
      apiCall(() => _dio.post('/favorites/$productId'));

  @override
  Future<void> remove(String productId) =>
      apiCall(() => _dio.delete('/favorites/$productId'));
}

class MockFavoritesRepository implements FavoritesRepository {
  final _db = MockDb.instance;

  @override
  Future<PageResult<Product>> list(int page,
      {int size = AppConfig.pageSize}) async {
    await _db.delay();
    final items = _db.products
        .where((p) => _db.favorites.contains(p.id))
        .map(_db.withFav)
        .toList();
    return _db.page(items, page, size);
  }

  @override
  Future<int> count() async => _db.favorites.length;

  @override
  Future<void> add(String productId) async {
    await _db.delay(150, 350);
    _db.favorites.add(productId.split('~').first);
  }

  @override
  Future<void> remove(String productId) async {
    await _db.delay(150, 350);
    _db.favorites.remove(productId.split('~').first);
  }
}
