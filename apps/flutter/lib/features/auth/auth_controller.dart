import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_exception.dart';
import '../../core/providers.dart';
import 'auth_models.dart';

/// Session state machine exposing `AsyncValue<AuthSession?>`.
///
/// * `data(null)`    -> signed out.
/// * `data(session)` -> signed in.
/// * `loading`       -> a login/register/refresh/bootstrap is in flight.
/// * `error`         -> last auth attempt failed (login/signup screen surfaces it).
///
/// On construction it kicks off [restoreSession]: if persisted tokens exist it
/// validates them via `GET /api/auth/me` (the dio refresh interceptor retries
/// once on a 401), landing on an authenticated session or a clean signed-out
/// state. This replaces the lab seed auto-login.
class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._ref) : super(const AsyncValue.loading()) {
    restoreSession();
  }

  final Ref _ref;

  bool get isAuthenticated => state.valueOrNull != null;

  AuthUser? get user => state.valueOrNull?.user;

  /// Boot-time session check. Reads persisted tokens; when present, calls
  /// `me()` (which goes through the 401-retry/refresh interceptor) to confirm
  /// the session is still valid. Never throws — resolves to signed-in or
  /// signed-out so the nav guard always gets a concrete answer.
  Future<void> restoreSession() async {
    state = const AsyncValue.loading();
    final tokenStore = _ref.read(tokenStoreProvider);
    final access = await tokenStore.readAccessToken();
    if (access == null || access.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    final repo = _ref.read(authRepositoryProvider);
    try {
      final user = await repo.me();
      final refresh = await tokenStore.readRefreshToken();
      state = AsyncValue.data(
        AuthSession(user: user, accessToken: access, refreshToken: refresh),
      );
    } on ApiException {
      // Tokens are stale and the refresh interceptor could not recover them.
      await tokenStore.clear();
      state = const AsyncValue.data(null);
    } catch (_) {
      await tokenStore.clear();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .register(email: email, password: password);
    });
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  /// Invoked by the dio 401-retry interceptor when a token refresh fails: the
  /// session is unrecoverable, so clear tokens and drop to signed-out. The nav
  /// guard then redirects to welcome.
  void signedOutByInterceptor() {
    if (!mounted) return;
    _ref.read(tokenStoreProvider).clear();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>(
  (ref) => AuthController(ref),
);
