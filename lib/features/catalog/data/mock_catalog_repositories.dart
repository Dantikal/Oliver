import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/paged.dart';
import '../domain/catalog_repositories.dart';
import '../domain/comment.dart';
import '../domain/product.dart';
import '../domain/reference.dart';

class MockProductRepository implements ProductRepository {
  final _db = MockDb.instance;

  @override
  Future<PageResult<Product>> getProducts(ProductFilter f, int page) async {
    await _db.delay(page == 0 ? 600 : 400, page == 0 ? 1100 : 800);
    // Больше данных для демонстрации бесконечной ленты.
    final base = _db.products;
    final all = <Product>[
      for (var round = 0; round < 3; round++)
        for (final p in base)
          round == 0
              ? p
              : Product(
                  id: '${p.id}~$round',
                  title: p.title,
                  description: p.description,
                  price: p.price == null
                      ? null
                      : (p.price! * (1 - round * 0.04)).roundToDouble(),
                  currency: p.currency,
                  categoryId: p.categoryId,
                  categoryName: p.categoryName,
                  regionId: p.regionId,
                  regionName: p.regionName,
                  cityId: p.cityId,
                  cityName: p.cityName,
                  phone: p.phone,
                  whatsappLink: p.whatsappLink,
                  telegramLink: p.telegramLink,
                  media: p.media,
                  seller: p.seller,
                  createdAt: p.createdAt.subtract(Duration(days: round * 3)),
                  viewsCount: p.viewsCount,
                  status: p.status,
                  options: p.options,
                ),
    ];
    final q = f.q.trim().toLowerCase();
    var list = all.where((p) {
      if (p.status != ProductStatus.active) return false;
      if (q.isNotEmpty &&
          !p.title.toLowerCase().contains(q) &&
          !p.description.toLowerCase().contains(q)) {
        return false;
      }
      if (f.categoryId != null &&
          p.categoryId != f.categoryId &&
          _db.rootCategoryOf(p.categoryId) != f.categoryId) {
        return false;
      }
      if (f.regionId != null && p.regionId != f.regionId) return false;
      if (f.cityId != null && p.cityId != f.cityId) return false;
      if (f.currency != null && p.currency != f.currency) return false;
      if (f.hasVideo && !p.hasVideo) return false;
      if (f.minPrice != null && (p.price ?? 0) < f.minPrice!) return false;
      if (f.maxPrice != null && (p.price ?? double.infinity) > f.maxPrice!) {
        return false;
      }
      return true;
    }).toList();
    switch (f.sort) {
      case ProductSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ProductSort.cheap:
        list.sort((a, b) =>
            (a.price ?? double.infinity).compareTo(b.price ?? double.infinity));
      case ProductSort.expensive:
        list.sort((a, b) => (b.price ?? -1).compareTo(a.price ?? -1));
    }
    return _db.page(list.map(_db.withFav).toList(), page, AppConfig.pageSize);
  }

  Product _find(String id) {
    final baseId = id.split('~').first;
    return _db.products
        .firstWhere((p) => p.id == baseId, orElse: () => _db.notFound());
  }

  @override
  Future<Product> getProduct(String id) async {
    await _db.delay();
    return _db.withFav(_find(id));
  }

  Product _fromDraft(String id, ProductDraft d, {DateTime? createdAt}) {
    final region = _db.regions.firstWhere((r) => r.id == d.regionId);
    return Product(
      id: id,
      title: d.title,
      description: d.description,
      price: d.price,
      currency: d.currency,
      categoryId: d.categoryId,
      categoryName: _db.categoryById(d.categoryId)?.name ?? '',
      regionId: d.regionId,
      regionName: region.name,
      cityId: d.cityId,
      cityName: _db.cityById(d.cityId)?.name ?? '',
      phone: d.phone,
      whatsappLink: d.whatsappLink,
      telegramLink: d.telegramLink,
      media: d.media,
      seller: _db.me,
      createdAt: createdAt ?? DateTime.now(),
      options: d.options,
    );
  }

  @override
  Future<Product> create(ProductDraft draft) async {
    await _db.delay(700, 1200);
    final p = _fromDraft(_db.nextId('p'), draft);
    _db.products.insert(0, p);
    return p;
  }

  @override
  Future<Product> update(String id, ProductDraft draft) async {
    await _db.delay(600, 1000);
    final old = _find(id);
    final d = _fromDraft(old.id, draft, createdAt: old.createdAt);
    // Статус, просмотры и лайки правкой не сбрасываются.
    final p = Product(
      id: d.id,
      title: d.title,
      description: d.description,
      price: d.price,
      currency: d.currency,
      categoryId: d.categoryId,
      categoryName: d.categoryName,
      regionId: d.regionId,
      regionName: d.regionName,
      cityId: d.cityId,
      cityName: d.cityName,
      phone: d.phone,
      whatsappLink: d.whatsappLink,
      telegramLink: d.telegramLink,
      media: d.media,
      seller: old.seller,
      createdAt: old.createdAt,
      commentsCount: old.commentsCount,
      viewsCount: old.viewsCount,
      likesCount: old.likesCount,
      status: old.status,
      options: d.options,
    );
    _db.products[_db.products.indexOf(old)] = p;
    return _db.withFav(p);
  }

  @override
  Future<void> delete(String id) async {
    await _db.delay();
    _db.products.removeWhere((p) => p.id == id);
    _db.favorites.remove(id);
  }

  @override
  Future<MediaItem> uploadMedia(String filePath, MediaType type) async {
    await _db.delay(400, 900);
    return MediaItem(id: _db.nextId('m'), url: filePath, type: type);
  }

  @override
  Future<PageResult<Product>> myProducts(int page,
      {ProductStatus? status}) async {
    await _db.delay();
    return _db.page(
        _db.products
            .where((p) =>
                p.seller.id == MockDb.meId &&
                (status == null || p.status == status))
            .map(_db.withFav)
            .toList(),
        page,
        AppConfig.pageSize);
  }

  @override
  Future<Product> setStatus(String id, ProductStatus status) async {
    await _db.delay(300, 600);
    final old = _find(id);
    final p = old.copyWith(status: status);
    _db.products[_db.products.indexOf(old)] = p;
    return _db.withFav(p);
  }

  @override
  Future<Product> bump(String id) async {
    await _db.delay(400, 700);
    final old = _find(id);
    final p = old.copyWith(createdAt: DateTime.now());
    _db.products
      ..remove(old)
      ..insert(0, p);
    return _db.withFav(p);
  }

  @override
  Future<PageResult<Product>> userProducts(String userId, int page) async {
    await _db.delay();
    return _db.page(
        _db.products
            .where((p) =>
                p.seller.id == userId && p.status == ProductStatus.active)
            .map(_db.withFav)
            .toList(),
        page,
        AppConfig.pageSize);
  }
}

class MockReferenceRepository implements ReferenceRepository {
  final _db = MockDb.instance;

  @override
  Future<List<ProductCategory>> categories() async {
    await _db.delay(200, 400);
    return _db.categories;
  }

  @override
  Future<List<Region>> regions() async {
    await _db.delay(200, 400);
    return _db.regions;
  }

  @override
  Future<List<City>> cities(String regionId) async {
    await _db.delay(200, 400);
    return _db.cities[regionId] ?? const [];
  }
}

class MockCommentRepository implements CommentRepository {
  final _db = MockDb.instance;

  List<Comment> _list(String productId) =>
      _db.comments.putIfAbsent(productId.split('~').first, () => []);

  @override
  Future<PageResult<Comment>> getComments(String productId, int page) async {
    await _db.delay();
    return _db.page(_list(productId), page, 8);
  }

  @override
  Future<Comment> add(String productId, String text,
      {String? parentCommentId}) async {
    await _db.delay(300, 600);
    if (text.trim().isEmpty) {
      throw const ApiException(status: 400, message: 'Пустой комментарий');
    }
    final c = Comment(
      id: _db.nextId('cm'),
      userId: _db.me.id,
      fullName: _db.me.fullName,
      avatarUrl: _db.me.avatarUrl,
      text: text.trim(),
      parentCommentId: parentCommentId,
      createdAt: DateTime.now(),
    );
    final list = _list(productId);
    if (parentCommentId == null) {
      list.insert(0, c);
    } else {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].mapTree(
            parentCommentId, (p) => p.copyWith(replies: [...p.replies, c]));
      }
    }
    return c;
  }

  @override
  Future<void> delete(String commentId) async {
    await _db.delay(200, 400);
    for (final entry in _db.comments.entries) {
      entry.value.replaceRange(
          0,
          entry.value.length,
          entry.value
              .map((c) => c.removeFromTree(commentId))
              .whereType<Comment>()
              .toList());
    }
  }

  Future<int> _setLike(String id, bool liked) async {
    await _db.delay(150, 300);
    var count = 0;
    for (final list in _db.comments.values) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].mapTree(id, (c) {
          count = c.likesCount + (liked == c.isLiked ? 0 : (liked ? 1 : -1));
          return c.copyWith(isLiked: liked, likesCount: count);
        });
      }
    }
    return count;
  }

  @override
  Future<int> like(String commentId) => _setLike(commentId, true);

  @override
  Future<int> unlike(String commentId) => _setLike(commentId, false);
}
