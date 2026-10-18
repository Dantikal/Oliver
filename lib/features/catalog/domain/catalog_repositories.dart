import '../../../core/pagination/paged.dart';
import 'comment.dart';
import 'product.dart';
import 'reference.dart';

abstract class ProductRepository {
  Future<PageResult<Product>> getProducts(ProductFilter filter, int page);
  Future<Product> getProduct(String id);
  Future<Product> create(ProductDraft draft);
  Future<Product> update(String id, ProductDraft draft);
  Future<void> delete(String id);
  Future<MediaItem> uploadMedia(String filePath, MediaType type);
  Future<PageResult<Product>> myProducts(int page, {ProductStatus? status});

  /// Продано / в архив / снова в продажу.
  Future<Product> setStatus(String id, ProductStatus status);

  /// Поднять объявление наверх ленты.
  Future<Product> bump(String id);
  Future<PageResult<Product>> userProducts(String userId, int page);
}

abstract class ReferenceRepository {
  Future<List<ProductCategory>> categories();
  Future<List<Region>> regions();
  Future<List<City>> cities(String regionId);
}

abstract class CommentRepository {
  Future<PageResult<Comment>> getComments(String productId, int page);
  Future<Comment> add(String productId, String text, {String? parentCommentId});
  Future<void> delete(String commentId);
  Future<int> like(String commentId);
  Future<int> unlike(String commentId);
}
