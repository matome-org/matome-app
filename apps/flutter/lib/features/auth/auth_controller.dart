import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
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
    AppLog.event(LogCat.auth, 'restoreSession start');
    state = const AsyncValue.loading();
    final tokenStore = _ref.read(tokenStoreProvider);
    final access = await tokenStore.readAccessToken();
    if (access == null || access.isEmpty) {
      AppLog.event(LogCat.auth, 'restoreSession no-token signed-out');
      state = const AsyncValue.data(null);
      return;
    }
    final repo = _ref.read(authRepositoryProvider);
    try {
      final user = await repo.me();
      final refresh = await tokenStore.readRefreshToken();
      AppLog.event(LogCat.auth, 'restoreSession ok');
      state = AsyncValue.data(
        AuthSession(user: user, accessToken: access, refreshToken: refresh),
      );
    } on ApiException catch (e, st) {
      // Tokens are stale and the refresh interceptor could not recover them.
      AppLog.error(
        LogCat.auth,
        'restoreSession: me() failed, clearing stale tokens',
        e,
        st,
      );
      AppLog.event(LogCat.auth, 'restoreSession fail signed-out');
      await tokenStore.clear();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      AppLog.error(
        LogCat.auth,
        'restoreSession: unexpected failure, clearing tokens',
        e,
        st,
      );
      AppLog.event(LogCat.auth, 'restoreSession fail signed-out');
      await tokenStore.clear();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login({required String email, required String password}) async {
    AppLog.event(LogCat.auth, 'login start (${_emailDomain(email)})');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
    AppLog.event(
      LogCat.auth,
      'login ${state.hasError ? 'fail' : 'ok'}',
    );
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    AppLog.event(LogCat.auth, 'register start (${_emailDomain(email)})');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .register(email: email, password: password);
    });
    AppLog.event(
      LogCat.auth,
      'register ${state.hasError ? 'fail' : 'ok'}',
    );
  }

  Future<void> logout() async {
    AppLog.event(LogCat.auth, 'logout start');
    await _ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
    AppLog.event(LogCat.auth, 'logout ok');
  }

  /// Extracts the email domain for non-sensitive breadcrumbs. Never logs the
  /// local-part (the user identity) or any credential.
  static String _emailDomain(String email) {
    final at = email.lastIndexOf('@');
    return at >= 0 && at < email.length - 1
        ? email.substring(at + 1)
        : 'unknown';
  }

  /// Invoked by the dio 401-retry interceptor when a token refresh fails: the
  /// session is unrecoverable, so clear tokens and drop to signed-out. The nav
  /// guard then redirects to welcome.
  void signedOutByInterceptor() {
    if (!mounted) return;
    AppLog.event(LogCat.auth, 'signedOutByInterceptor refresh-failed');
    _ref.read(tokenStoreProvider).clear();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>(
  (ref) => AuthController(ref),
);
