import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/paged.dart';
import '../../favorites/presentation/favorites_controller.dart';
import '../data/catalog_providers.dart';
import '../domain/comment.dart';
import '../domain/product.dart';

final productFilterProvider =
    StateProvider<ProductFilter>((_) => const ProductFilter());

final productsPagedProvider =
    StateNotifierProvider<PagedController<Product>, PagedState<Product>>((ref) {
  final filter = ref.watch(productFilterProvider);
  final repo = ref.watch(productRepositoryProvider);
  return PagedController((page) async {
    final r = await repo.getProducts(filter, page);
    ref.read(favoriteIdsProvider.notifier).seed(r.items);
    return r;
  });
});

final productDetailsProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  final p = await ref.watch(productRepositoryProvider).getProduct(id);
  ref.read(favoriteIdsProvider.notifier).seed([p]);
  return p;
});

final myProductsPagedProvider =
    StateNotifierProvider<PagedController<Product>, PagedState<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return PagedController(
      (page) => repo.myProducts(page, status: ProductStatus.active));
});

/// Мои объявления по статусу — вкладки кабинета продавца.
final myProductsByStatusProvider = StateNotifierProvider.autoDispose
    .family<PagedController<Product>, PagedState<Product>, ProductStatus>(
        (ref, status) {
  final repo = ref.watch(productRepositoryProvider);
  return PagedController((page) => repo.myProducts(page, status: status));
});

final userProductsPagedProvider = StateNotifierProvider.autoDispose
    .family<PagedController<Product>, PagedState<Product>, String>(
        (ref, userId) {
  final repo = ref.watch(productRepositoryProvider);
  return PagedController((page) => repo.userProducts(userId, page));
});

final commentsPagedProvider = StateNotifierProvider.autoDispose
    .family<PagedController<Comment>, PagedState<Comment>, String>(
        (ref, productId) {
  final repo = ref.watch(commentRepositoryProvider);
  return PagedController((page) => repo.getComments(productId, page));
});
