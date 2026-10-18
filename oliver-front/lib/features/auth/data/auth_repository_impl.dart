import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

final _public = Options(extra: {'public': true});

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<String> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
    required String confirmPassword,
  }) =>
      apiCall(() async {
        final r = await _dio.post('/auth/register', options: _public, data: {
          'phone': phone,
          'email': email,
          'fullName': fullName,
          'password': password,
          'confirmPassword': confirmPassword,
        });
        return r.data['userId'].toString();
      });

  @override
  Future<String> login({required String email, required String password}) =>
      apiCall(() async {
        final r = await _dio.post('/auth/login',
            options: _public, data: {'email': email, 'password': password});
        return r.data['sessionId'].toString();
      });

  @override
  Future<AuthSession> verify2fa(
          {required String sessionId, required String code}) =>
      apiCall(() async {
        final r = await _dio.post('/auth/verify-2fa',
            options: _public, data: {'sessionId': sessionId, 'code': code});
        return AuthSession(
          accessToken: r.data['accessToken'] as String,
          refreshToken: r.data['refreshToken'] as String,
          user: User.fromJson(Map<String, dynamic>.from(r.data['user'] as Map)),
        );
      });

  @override
  Future<void> resend2fa(String sessionId) =>
      apiCall(() => _dio.post('/auth/resend-2fa',
          options: _public, data: {'sessionId': sessionId}));

  @override
  Future<void> forgotPassword(String email) => apiCall(() => _dio
      .post('/auth/forgot-password', options: _public, data: {'email': email}));

  @override
  Future<void> resetPassword(
          {required String token, required String newPassword}) =>
      apiCall(() => _dio.post('/auth/reset-password',
          options: _public,
          data: {'token': token, 'newPassword': newPassword}));

  @override
  Future<void> logout(String refreshToken) => apiCall(
      () => _dio.post('/auth/logout', data: {'refreshToken': refreshToken}));
}
