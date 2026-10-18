import 'user.dart';

class AuthSession {
  const AuthSession(
      {required this.accessToken,
      required this.refreshToken,
      required this.user});
  final String accessToken;
  final String refreshToken;
  final User user;
}

abstract class AuthRepository {
  Future<String> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
    required String confirmPassword,
  });

  /// Возвращает sessionId для 2FA.
  Future<String> login({required String email, required String password});
  Future<AuthSession> verify2fa(
      {required String sessionId, required String code});
  Future<void> resend2fa(String sessionId);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(
      {required String token, required String newPassword});
  Future<void> logout(String refreshToken);
}
