import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/prefs.dart';
import '../../catalog/domain/product.dart';
import '../domain/store.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) =>
    AppConfig.useMock
        ? MockStoreRepository(ref.read(sharedPrefsProvider))
        : StoreRepositoryImpl(ref.watch(dioProvider)));

/// 404 → null: магазина нет.
Future<T?> _orNull<T>(Future<T> Function() call) async {
  try {
    return await apiCall(call);
  } on ApiException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
}

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._dio);
  final Dio _dio;

  Store _store(dynamic d) =>
      Store.fromJson(Map<String, dynamic>.from(d as Map));
  StoreSection _section(dynamic d) =>
      StoreSection.fromJson(Map<String, dynamic>.from(d as Map));

  @override
  Future<Store?> myStore() =>
      _orNull(() async => _store((await _dio.get('/stores/me')).data));

  @override
  Future<Store> create({required String name, String description = ''}) =>
      apiCall(() async => _store((await _dio.post('/stores',
              data: {'name': name, 'description': description}))
          .data));

  @override
  Future<Store> update(
          {String? name, String? description, bool? pickup, bool? delivery}) =>
      apiCall(() async => _store((await _dio.patch('/stores/me', data: {
            if (name != null) 'name': name,
            if (description != null) 'description': description,
            if (pickup != null) 'pickup': pickup,
            if (delivery != null) 'delivery': delivery,
          }))
              .data));

  @override
  Future<Store?> storeOf(String userId) => _orNull(
      () async => _store((await _dio.get('/users/$userId/store')).data));

  @override
  Future<StoreSection> addSection(String name, String icon) =>
      apiCall(() async => _section((await _dio
              .post('/stores/me/sections', data: {'name': name, 'icon': icon}))
          .data));

  @override
  Future<StoreSection> updateSection(String id, {String? name, String? icon}) =>
      apiCall(() async =>
          _section((await _dio.patch('/stores/me/sections/$id', data: {
            if (name != null) 'name': name,
            if (icon != null) 'icon': icon,
          }))
              .data));

  @override
  Future<void> deleteSection(String id) =>
      apiCall(() => _dio.delete('/stores/me/sections/$id'));

  @override
  Future<void> reorderSections(List<String> ids) =>
      apiCall(() => _dio.put('/stores/me/sections/order', data: {'ids': ids}));

  @override
  Future<void> setSectionProducts(String sectionId, List<String> productIds) =>
      apiCall(() => _dio.put('/stores/me/sections/$sectionId/products',
          data: {'productIds': productIds}));

  @override
  Future<void> setFeatured(List<String> productIds) => apiCall(
      () => _dio.put('/stores/me/featured', data: {'productIds': productIds}));

  @override
  Future<List<Product>> products(String userId) => apiCall(() async {
        final r = await _dio.get('/users/$userId/products',
            queryParameters: {'page': 0, 'size': 500});
        final d = r.data;
        final raw = d is List ? d : (d['items'] ?? d['content'] ?? []) as List;
        return [
          for (final e in raw)
            Product.fromJson(Map<String, dynamic>.from(e as Map))
        ];
      });
}

/// Mock: свой магазин хранится в SharedPreferences, чужие собираются
/// автоматически по категориям товаров продавца.
class MockStoreRepository implements StoreRepository {
  MockStoreRepository(this._prefs);
  final SharedPreferences _prefs;
  final _db = MockDb.instance;
  static const _key = 'mock_store_me';

  Store? _load() {
    final s = _prefs.getString(_key);
    return s == null
        ? null
        : Store.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
  }

  Store _save(Store s) {
    _prefs.setString(_key, jsonEncode(s.toJson()));
    return s;
  }

  Store _mine() => _load() ?? _db.notFound();

  @override
  Future<Store?> myStore() async {
    await _db.delay(200, 400);
    return _load();
  }

  @override
  Future<Store> create({required String name, String description = ''}) async {
    await _db.delay(400, 700);
    return _save(Store(
      id: _db.nextId('store'),
      ownerId: MockDb.meId,
      name: name,
      description: description,
    ));
  }

  @override
  Future<Store> update(
      {String? name, String? description, bool? pickup, bool? delivery}) async {
    await _db.delay(200, 400);
    return _save(_mine().copyWith(
        name: name,
        description: description,
        pickup: pickup,
        delivery: delivery));
  }

  @override
  Future<Store?> storeOf(String userId) async {
    await _db.delay(250, 500);
    if (userId == MockDb.meId) return _load();
    final mine = _db.products.where(
        (p) => p.seller.id == userId && p.status == ProductStatus.active);
    if (mine.isEmpty) return null;
    final byRoot = <String, List<String>>{};
    for (final p in mine) {
      byRoot.putIfAbsent(_db.rootCategoryOf(p.categoryId), () => []).add(p.id);
    }
    final owner = _db.users[userId];
    return Store(
      id: 'store-$userId',
      ownerId: userId,
      name: owner?.fullName ?? '',
      description: '',
      delivery: userId.hashCode.isEven,
      sections: [
        for (final e in byRoot.entries)
          StoreSection(
            id: 'sec-${e.key}',
            name: _db.categoryById(e.key)?.name ?? '',
            icon: _db.categoryById(e.key)?.icon ?? 'tag',
            productIds: e.value,
          ),
      ],
      featuredIds: mine.take(1).map((p) => p.id).toList(),
    );
  }

  @override
  Future<StoreSection> addSection(String name, String icon) async {
    await _db.delay(150, 300);
    final s = StoreSection(id: _db.nextId('sec'), name: name, icon: icon);
    final st = _mine();
    _save(st.copyWith(sections: [...st.sections, s]));
    return s;
  }

  @override
  Future<StoreSection> updateSection(String id,
      {String? name, String? icon}) async {
    await _db.delay(150, 300);
    final st = _mine();
    final list = [
      for (final s in st.sections)
        s.id == id ? s.copyWith(name: name, icon: icon) : s
    ];
    _save(st.copyWith(sections: list));
    return list.firstWhere((s) => s.id == id);
  }

  @override
  Future<void> deleteSection(String id) async {
    await _db.delay(150, 300);
    final st = _mine();
    _save(st.copyWith(sections: st.sections.where((s) => s.id != id).toList()));
  }

  @override
  Future<void> reorderSections(List<String> ids) async {
    await _db.delay(100, 200);
    final st = _mine();
    final byId = {for (final s in st.sections) s.id: s};
    _save(st.copyWith(sections: [
      for (final id in ids)
        if (byId[id] != null) byId[id]!
    ]));
  }

  @override
  Future<void> setSectionProducts(
      String sectionId, List<String> productIds) async {
    await _db.delay(100, 250);
    final st = _mine();
    // Товар живёт только в одном отделе — из остальных убираем.
    _save(st.copyWith(sections: [
      for (final s in st.sections)
        s.id == sectionId
            ? s.copyWith(productIds: productIds)
            : s.copyWith(
                productIds: s.productIds
                    .where((id) => !productIds.contains(id))
                    .toList())
    ]));
  }

  @override
  Future<void> setFeatured(List<String> productIds) async {
    await _db.delay(100, 200);
    _save(_mine().copyWith(featuredIds: productIds));
  }

  @override
  Future<List<Product>> products(String userId) async {
    await _db.delay(300, 600);
    return _db.products
        .where((p) => p.seller.id == userId && p.status == ProductStatus.active)
        .map(_db.withFav)
        .toList();
  }
}

// ------------------------------------------------------------ providers

/// Свой магазин + все правки с мгновенным обновлением экрана.
final myStoreProvider =
    AsyncNotifierProvider<MyStoreController, Store?>(MyStoreController.new);

/// Витрина магазина пользователя.
final storeOfProvider = FutureProvider.autoDispose.family<Store?, String>(
    (ref, userId) => ref.watch(storeRepositoryProvider).storeOf(userId));

/// Активные товары продавца.
final storeProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, String>(
        (ref, userId) => ref.watch(storeRepositoryProvider).products(userId));

class MyStoreController extends AsyncNotifier<Store?> {
  StoreRepository get _repo => ref.read(storeRepositoryProvider);

  @override
  Future<Store?> build() => _repo.myStore();

  Store get _s => state.requireValue!;

  /// Сразу показать новое состояние, при ошибке — вернуть старое.
  Future<void> _optimistic(Store next, Future<void> Function() call) async {
    final prev = state;
    state = AsyncData(next);
    try {
      await call();
    } catch (_) {
      state = prev;
      rethrow;
    }
  }

  Future<void> create(String name, String description) async {
    state = AsyncData(await _repo.create(name: name, description: description));
  }

  Future<void> updateInfo(
      {String? name, String? description, bool? pickup, bool? delivery}) {
    return _optimistic(
      _s.copyWith(
          name: name,
          description: description,
          pickup: pickup,
          delivery: delivery),
      () => _repo.update(
          name: name,
          description: description,
          pickup: pickup,
          delivery: delivery),
    );
  }

  Future<void> addSection(String name, String icon) async {
    final s = await _repo.addSection(name, icon);
    state = AsyncData(_s.copyWith(sections: [..._s.sections, s]));
  }

  Future<void> updateSection(String id, {String? name, String? icon}) =>
      _optimistic(
        _s.copyWith(sections: [
          for (final s in _s.sections)
            s.id == id ? s.copyWith(name: name, icon: icon) : s
        ]),
        () => _repo.updateSection(id, name: name, icon: icon),
      );

  Future<void> deleteSection(String id) => _optimistic(
        _s.copyWith(sections: _s.sections.where((s) => s.id != id).toList()),
        () => _repo.deleteSection(id),
      );

  Future<void> reorderSections(int oldIndex, int newIndex) {
    final list = [..._s.sections];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    return _optimistic(_s.copyWith(sections: list),
        () => _repo.reorderSections([for (final s in list) s.id]));
  }

  /// Новый состав и порядок отдела; товары уходят из других отделов.
  Future<void> setSectionProducts(String sectionId, List<String> ids) =>
      _optimistic(
        _s.copyWith(sections: [
          for (final s in _s.sections)
            s.id == sectionId
                ? s.copyWith(productIds: ids)
                : s.copyWith(
                    productIds:
                        s.productIds.where((id) => !ids.contains(id)).toList())
        ]),
        () => _repo.setSectionProducts(sectionId, ids),
      );

  /// Перенести товар в другой отдел (в конец).
  Future<void> moveProduct(String productId, String toSectionId) {
    final target = _s.sections.firstWhere((s) => s.id == toSectionId);
    return setSectionProducts(toSectionId,
        [...target.productIds.where((id) => id != productId), productId]);
  }

  Future<void> toggleFeatured(String productId) {
    final f = [..._s.featuredIds];
    f.contains(productId) ? f.remove(productId) : f.insert(0, productId);
    return _optimistic(_s.copyWith(featuredIds: f), () => _repo.setFeatured(f));
  }
}
