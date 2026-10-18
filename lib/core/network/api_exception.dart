import 'package:dio/dio.dart';

/// Ошибка API в едином формате backend: { timestamp, status, error, message, path }.
class ApiException implements Exception {
  const ApiException(
      {this.status, required this.message, this.isNetwork = false, this.path});

  final int? status;
  final String message;
  final bool isNetwork;
  final String? path;

  bool get isUnauthorized => status == 401;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const ApiException(message: 'network', isNetwork: true);
      default:
        break;
    }
    final res = e.response;
    final data = res?.data;
    String message = 'generic';
    String? path;
    if (data is Map) {
      message = (data['message'] ?? data['error'] ?? message).toString();
      path = data['path']?.toString();
    }
    return ApiException(status: res?.statusCode, message: message, path: path);
  }

  @override
  String toString() => 'ApiException($status, $message)';
}

/// Оборачивает вызов Dio и приводит ошибки к [ApiException].
Future<T> apiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    if (e.error is ApiException) throw e.error as ApiException;
    throw ApiException.fromDio(e);
  }
}
