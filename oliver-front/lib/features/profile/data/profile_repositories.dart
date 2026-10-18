import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/domain/user.dart';
import '../domain/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => AppConfig.useMock
      ? MockProfileRepository()
      : ProfileRepositoryImpl(ref.watch(dioProvider)),
);

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<User> me() => apiCall(() async {
        final r = await _dio.get('/users/me');
        return User.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  @override
  Future<User> updateMe({String? fullName, String? avatarUrl}) =>
      apiCall(() async {
        final r = await _dio.patch('/users/me', data: {
          if (fullName != null) 'fullName': fullName,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        });
        return User.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  @override
  Future<String> uploadAvatar(String filePath) => apiCall(() async {
        final form =
            FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
        final r = await _dio.post('/users/me/avatar', data: form);
        return r.data['avatarUrl'] as String;
      });

  @override
  Future<User> user(String userId) => apiCall(() async {
        final r = await _dio.get('/users/$userId');
        return User.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
}

class MockProfileRepository implements ProfileRepository {
  final _db = MockDb.instance;

  @override
  Future<User> me() async {
    await _db.delay(200, 400);
    return _db.me;
  }

  @override
  Future<User> updateMe({String? fullName, String? avatarUrl}) async {
    await _db.delay();
    _db.me = _db.me.copyWith(fullName: fullName, avatarUrl: avatarUrl);
    _db.users[_db.me.id] = _db.me;
    return _db.me;
  }

  @override
  Future<String> uploadAvatar(String filePath) async {
    await _db.delay(800, 1400);
    return filePath; // локальный путь отображается через Image.file
  }

  @override
  Future<User> user(String userId) async {
    await _db.delay();
    return _db.users[userId] ?? _db.notFound();
  }
}
