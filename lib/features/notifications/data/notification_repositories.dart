import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/pagination/paged.dart';
import '../domain/notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => AppConfig.useMock
      ? MockNotificationRepository()
      : NotificationRepositoryImpl(ref.watch(dioProvider)),
);

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<PageResult<AppNotification>> list(int page) => apiCall(() async {
        final r = await _dio.get('/notifications',
            queryParameters: {'page': page, 'size': AppConfig.pageSize});
        final data = Map<String, dynamic>.from(r.data as Map)
          ..putIfAbsent('page', () => page)
          ..putIfAbsent('size', () => AppConfig.pageSize);
        return PageResult.fromJson(data, AppNotification.fromJson);
      });

  @override
  Future<Counters> counters() =>
      apiCall(() async => Counters.fromJson(Map<String, dynamic>.from(
          (await _dio.get('/notifications/counters')).data as Map)));

  @override
  Future<void> markRead(List<String> ids) =>
      apiCall(() => _dio.post('/notifications/read', data: {'ids': ids}));
}

class MockNotificationRepository implements NotificationRepository {
  final _db = MockDb.instance;

  @override
  Future<PageResult<AppNotification>> list(int page) async {
    await _db.delay();
    return _db.page(_db.notifications, page, AppConfig.pageSize);
  }

  @override
  Future<Counters> counters() async {
    await _db.delay(100, 250);
    return Counters(
      unreadMessages: _db.chats.fold(0, (s, c) => s + c.unreadCount),
      newLikes: _db.newLikes,
      unreadNotifications: _db.notifications.where((n) => !n.isRead).length,
    );
  }

  @override
  Future<void> markRead(List<String> ids) async {
    await _db.delay(100, 200);
    for (var i = 0; i < _db.notifications.length; i++) {
      if (ids.contains(_db.notifications[i].id)) {
        _db.notifications[i] = _db.notifications[i].markRead();
      }
    }
    _db.newLikes = 0;
  }
}
