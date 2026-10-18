import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/paged.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/product.dart';
import '../data/favorites_repositories.dart';

/// Глобальное множество id избранных товаров — единый источник состояния «сердечка».
final favoriteIdsProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

final favoritesCountProvider =
    Provider<int>((ref) => ref.watch(favoriteIdsProvider).length);

final favoritesPagedProvider =
    StateNotifierProvider<PagedController<Product>, PagedState<Product>>((ref) {
  ref.watch(authControllerProvider.select((s) => s.status));
  final repo = ref.watch(favoritesRepositoryProvider);
  return PagedController((page) => repo.list(page));
});

class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final status = ref.watch(authControllerProvider.select((s) => s.status));
    if (status == AuthStatus.authenticated) Future.microtask(_load);
    return {};
  }

  static String _base(String id) => id.split('~').first;

  bool isFav(String id) => state.contains(_base(id));

  Future<void> _load() async {
    try {
      final r = await ref.read(favoritesRepositoryProvider).list(0, size: 500);
      state = {...state, ...r.items.map((p) => _base(p.id))};
    } catch (_) {}
  }

  /// Подмешивает признак isFavorite из ответа API.
  void seed(Iterable<Product> products) {
    final add = products.where((p) => p.isFavorite).map((p) => _base(p.id));
    if (add.any((id) => !state.contains(id))) state = {...state, ...add};
  }

  /// Оптимистичный toggle с откатом при ошибке.
  Future<void> toggle(String productId) async {
    final id = _base(productId);
    final was = state.contains(id);
    HapticFeedback.lightImpact();
    state = was ? ({...state}..remove(id)) : {...state, id};
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      if (was) {
        await repo.remove(id);
        ref.read(favoritesPagedProvider.notifier).mutate(
              (items) => items.where((p) => _base(p.id) != id).toList(),
              totalDelta: -1,
            );
      } else {
        await repo.add(id);
        ref.read(favoritesPagedProvider.notifier).refresh();
      }
    } catch (e) {
      state = was ? {...state, id} : ({...state}..remove(id));
      rethrow;
    }
  }
}
