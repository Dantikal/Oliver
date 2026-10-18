/// Глобальная конфигурация приложения.
///
/// Переключение на реальный backend:
///   flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://192.168.1.10:8080
class AppConfig {
  AppConfig._();

  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://localhost:8080');
  static const bool enablePush =
      bool.fromEnvironment('ENABLE_PUSH', defaultValue: false);

  static String get apiUrl => '$baseUrl/api/v1';
  static String get wsUrl => '${baseUrl.replaceFirst('http', 'ws')}/ws';
  static const String shareBaseUrl = 'https://oliver.kg/p';

  static const int pageSize = 20;
  static const int maxPhotos = 10;
  static const int maxVideos = 3;
  static const int maxPhotoMb = 10;
  static const int maxVideoMb = 100;
  static const int titleMax = 80;
  static const int descriptionMax = 3000;
  static const int resendSeconds = 60;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  static const photoExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic'];
  static const videoExtensions = ['mp4', 'mov', 'm4v'];
}
