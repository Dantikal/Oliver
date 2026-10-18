import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _db = MockDb.instance;

  @override
  Future<String> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
    required String confirmPassword,
  }) async {
    await _db.delay(700, 1200);
    if (email.toLowerCase() == 'taken@oliver.kg') {
      throw const ApiException(
          status: 409, message: 'Пользователь с таким email уже существует');
    }
    return _db.nextId('u');
  }

  @override
  Future<String> login(
      {required String email, required String password}) async {
    await _db.delay(700, 1200);
    if (password == 'Wrong1234') {
      throw const ApiException(
          status: 401, message: 'Неверный email или пароль');
    }
    return 'sess_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<AuthSession> verify2fa(
      {required String sessionId, required String code}) async {
    await _db.delay(600, 1000);
    if (code != MockDb.otpCode) {
      throw const ApiException(
          status: 400, message: 'Неверный код подтверждения');
    }
    return AuthSession(
        accessToken: 'mock_access', refreshToken: 'mock_refresh', user: _db.me);
  }

  @override
  Future<void> resend2fa(String sessionId) => _db.delay();

  @override
  Future<void> forgotPassword(String email) => _db.delay(600, 1000);

  @override
  Future<void> resetPassword(
          {required String token, required String newPassword}) =>
      _db.delay();

  @override
  Future<void> logout(String refreshToken) => _db.delay(100, 200);
}
