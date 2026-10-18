import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/pagination/paged.dart';
import '../domain/catalog_repositories.dart';
import '../domain/comment.dart';
import '../domain/product.dart';
import '../domain/reference.dart';

Product _p(dynamic j) => Product.fromJson(Map<String, dynamic>.from(j as Map));

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<Product>> getProducts(ProductFilter filter, int page) =>
      apiCall(() async {
        final r = await _dio.get('/products',
            queryParameters: filter.toQuery(page, AppConfig.pageSize));
        return PageResult.fromJson(r.data, Product.fromJson);
      });

  @override
  Future<Product> getProduct(String id) =>
      apiCall(() async => _p((await _dio.get('/products/$id')).data));

  @override
  Future<Product> create(ProductDraft draft) => apiCall(() async =>
      _p((await _dio.post('/products', data: draft.toJson())).data));

  @override
  Future<Product> update(String id, ProductDraft draft) => apiCall(() async =>
      _p((await _dio.patch('/products/$id', data: draft.toJson())).data));

  @override
  Future<void> delete(String id) => apiCall(() => _dio.delete('/products/$id'));

  @override
  Future<MediaItem> uploadMedia(String filePath, MediaType type) =>
      apiCall(() async {
        final form =
            FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
        final r = await _dio.post('/media/upload', data: form);
        final m = Map<String, dynamic>.from(r.data as Map);
        return MediaItem(
          id: (m['mediaId'] ?? m['id'] ?? m['url']).toString(),
          url: m['url'] as String,
          type: MediaType.fromApi(m['type'] as String?),
        );
      });

  @override
  Future<PageResult<Product>> myProducts(int page, {ProductStatus? status}) =>
      apiCall(() async {
        final r = await _dio.get('/products/me', queryParameters: {
          'page': page,
          'size': AppConfig.pageSize,
          if (status != null) 'status': status.api,
        });
        return PageResult.fromJson(r.data, Product.fromJson);
      });

  @override
  Future<Product> setStatus(String id, ProductStatus status) =>
      apiCall(() async {
        final r = await _dio
            .patch('/products/$id/status', data: {'status': status.api});
        return Product.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  @override
  Future<Product> bump(String id) => apiCall(() async {
        final r = await _dio.post('/products/$id/bump');
        return Product.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  @override
  Future<PageResult<Product>> userProducts(String userId, int page) =>
      apiCall(() async {
        final r = await _dio.get('/users/$userId/products',
            queryParameters: {'page': page, 'size': AppConfig.pageSize});
        return PageResult.fromJson(r.data, Product.fromJson);
      });
}

class ReferenceRepositoryImpl implements ReferenceRepository {
  ReferenceRepositoryImpl(this._dio);
  final Dio _dio;

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) f) =>
      (data as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();

  @override
  Future<List<ProductCategory>> categories() => apiCall(() async =>
      _list((await _dio.get('/categories')).data, ProductCategory.fromJson));

  @override
  Future<List<Region>> regions() => apiCall(
      () async => _list((await _dio.get('/regions')).data, Region.fromJson));

  @override
  Future<List<City>> cities(String regionId) => apiCall(() async =>
      _list((await _dio.get('/regions/$regionId/cities')).data, City.fromJson));
}

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<Comment>> getComments(String productId, int page) =>
      apiCall(() async {
        final r = await _dio.get('/products/$productId/comments',
            queryParameters: {'page': page, 'size': AppConfig.pageSize});
        final data = Map<String, dynamic>.from(r.data as Map)
          ..putIfAbsent('page', () => page)
          ..putIfAbsent('size', () => AppConfig.pageSize);
        return PageResult.fromJson(data, Comment.fromJson);
      });

  @override
  Future<Comment> add(String productId, String text,
          {String? parentCommentId}) =>
      apiCall(() async {
        final r = await _dio.post('/products/$productId/comments', data: {
          'text': text,
          if (parentCommentId != null) 'parentCommentId': parentCommentId
        });
        return Comment.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  @override
  Future<void> delete(String commentId) =>
      apiCall(() => _dio.delete('/comments/$commentId'));

  @override
  Future<int> like(String commentId) => apiCall(() async =>
      (await _dio.post('/comments/$commentId/like')).data['likesCount'] as int);

  @override
  Future<int> unlike(String commentId) => apiCall(() async =>
      (await _dio.delete('/comments/$commentId/like')).data['likesCount']
          as int);
}
