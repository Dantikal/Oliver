import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Добавляет `Authorization: Bearer <token>` к защищённым запросам,
/// при 401 пытается обновить токен через refresh, иначе — авто-логаут.
///
/// Публичные запросы помечаются `Options(extra: {'public': true})`.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.storage, required this.onSessionExpired});

  final TokenStorage storage;
  final void Function() onSessionExpired;
  final Dio _refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiUrl));

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['public'] != true) {
      final token = await storage.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || req.extra['public'] == true || req.extra['retried'] == true) {
      return handler.next(err);
    }

    final refresh = await storage.refreshToken;
    if (refresh == null) {
      await _expire();
      return handler.next(err);
    }

    try {
      final res = await _refreshDio
          .post('/auth/refresh', data: {'refreshToken': refresh});
      final access = res.data['accessToken'] as String;
      final newRefresh = res.data['refreshToken'] as String;
      await storage.save(access: access, refresh: newRefresh);

      req.headers['Authorization'] = 'Bearer $access';
      req.extra['retried'] = true;
      final retry = await _refreshDio.fetch(req..baseUrl = req.baseUrl);
      return handler.resolve(retry);
    } catch (_) {
      await _expire();
      return handler.next(err);
    }
  }

  Future<void> _expire() async {
    await storage.clear();
    onSessionExpired();
  }
}
