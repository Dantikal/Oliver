import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Push-уведомления (FCM).
///
/// Пакеты firebase_core / firebase_messaging временно убраны из pubspec.yaml.
/// Чтобы включить: вернуть зависимости, добавить GoogleService-Info.plist /
/// google-services.json и раскомментировать код ниже, запуск с --dart-define=ENABLE_PUSH=true.
class PushService {
  PushService._();

  static Future<void> init() async {
    if (!AppConfig.enablePush) return;
    debugPrint('Push: Firebase не подключён');
    // await Firebase.initializeApp();
    // final fm = FirebaseMessaging.instance;
    // await fm.requestPermission(alert: true, badge: true, sound: true);
    // final token = await fm.getToken(); // → отправить на backend
    // FirebaseMessaging.onMessage.listen((m) => debugPrint('Push: ${m.notification?.title}'));
  }
}
