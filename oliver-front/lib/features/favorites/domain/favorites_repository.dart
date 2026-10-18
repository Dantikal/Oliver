import '../../../core/pagination/paged.dart';
import '../../catalog/domain/product.dart';

abstract class FavoritesRepository {
  Future<PageResult<Product>> list(int page, {int size});
  Future<int> count();
  Future<void> add(String productId);
  Future<void> remove(String productId);
}
