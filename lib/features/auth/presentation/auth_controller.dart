import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../../profile/data/profile_repositories.dart';
import '../data/auth_providers.dart';
import '../domain/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final User? user;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider =
    Provider<User?>((ref) => ref.watch(authControllerProvider).user);

class AuthController extends Notifier<AuthState> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _bootstrap() async {
    // Минимальное время показа splash-анимации.
    final minSplash = Future.delayed(const Duration(milliseconds: 2300));
    final token = await _storage.accessToken;
    User? user;
    if (token != null) {
      try {
        user = await ref.read(profileRepositoryProvider).me();
      } catch (_) {
        user = null;
      }
    }
    await minSplash;
    state = user != null
        ? AuthState(AuthStatus.authenticated, user)
        : const AuthState(AuthStatus.unauthenticated);
  }

  Future<String> login(String email, String password) => ref
      .read(authRepositoryProvider)
      .login(email: email.trim(), password: password);

  Future<void> verify2fa(String sessionId, String code) async {
    final session = await ref
        .read(authRepositoryProvider)
        .verify2fa(sessionId: sessionId, code: code);
    await _storage.save(
        access: session.accessToken, refresh: session.refreshToken);
    state = AuthState(AuthStatus.authenticated, session.user);
  }

  Future<void> resend2fa(String sessionId) =>
      ref.read(authRepositoryProvider).resend2fa(sessionId);

  Future<void> register({
    required String phone,
    required String email,
    required String fullName,
    required String password,
    required String confirmPassword,
  }) =>
      ref.read(authRepositoryProvider).register(
            phone: phone,
            email: email.trim(),
            fullName: fullName.trim(),
            password: password,
            confirmPassword: confirmPassword,
          );

  Future<void> forgotPassword(String email) =>
      ref.read(authRepositoryProvider).forgotPassword(email.trim());

  void updateUser(User user) => state = AuthState(state.status, user);

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    if (refresh != null) {
      try {
        await ref.read(authRepositoryProvider).logout(refresh);
      } catch (_) {}
    }
    await _storage.clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  /// Вызывается интерцептором при 401 без возможности обновить токен.
  void onSessionExpired() {
    if (state.status == AuthStatus.authenticated) {
      state = const AuthState(AuthStatus.unauthenticated);
    }
  }
}
