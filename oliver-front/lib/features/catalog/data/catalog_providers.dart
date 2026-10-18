import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/catalog_repositories.dart';
import '../domain/reference.dart';
import 'catalog_repositories_impl.dart';
import 'mock_catalog_repositories.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => AppConfig.useMock
      ? MockProductRepository()
      : ProductRepositoryImpl(ref.watch(dioProvider)),
);

final referenceRepositoryProvider = Provider<ReferenceRepository>(
  (ref) => AppConfig.useMock
      ? MockReferenceRepository()
      : ReferenceRepositoryImpl(ref.watch(dioProvider)),
);

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => AppConfig.useMock
      ? MockCommentRepository()
      : CommentRepositoryImpl(ref.watch(dioProvider)),
);

final categoriesProvider = FutureProvider<List<ProductCategory>>(
  (ref) => ref.watch(referenceRepositoryProvider).categories(),
);

final regionsProvider = FutureProvider<List<Region>>(
  (ref) => ref.watch(referenceRepositoryProvider).regions(),
);

final citiesProvider = FutureProvider.family<List<City>, String>(
  (ref, regionId) => ref.watch(referenceRepositoryProvider).cities(regionId),
);
