import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/auth_repository.dart';
import 'auth_repository_impl.dart';
import 'mock_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppConfig.useMock
      ? MockAuthRepository()
      : AuthRepositoryImpl(ref.watch(dioProvider)),
);
