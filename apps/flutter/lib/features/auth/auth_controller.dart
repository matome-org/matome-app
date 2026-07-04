import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/media_playback_resolver.dart'
    show defaultPlaybackScratchDir, evictAllPlaybackScratch;
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
  AuthController(
    this._ref, {
    Future<void> Function()? evictPlaybackCache,
  }) : _evictPlaybackCache =
           evictPlaybackCache ??
           (() =>
               evictAllPlaybackScratch(scratchDirSource: defaultPlaybackScratchDir)),
       super(const AsyncValue.loading()) {
    restoreSession();
  }

  final Ref _ref;

  /// Sweeps the ENTIRE decrypted-media playback scratch cache — every
  /// recording's scratch file, not just one — on every session-boundary exit
  /// (explicit [logout], and the forced [signedOutByInterceptor] path).
  /// okt-audit PASS-2 FINDING-1 named "logout/account-switch" as a required
  /// eviction point for the never-deleted playback scratch file; this app has
  /// no separate multi-account "switch" flow today (grepped, confirmed), so
  /// logout IS the account-boundary event. Injectable so this is testable
  /// without touching the real `path_provider` platform channel.
  final Future<void> Function() _evictPlaybackCache;

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
    AppLog.event(LogCat.auth, 'login start (${emailDomainForLog(email)})');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
    AppLog.event(LogCat.auth, 'login ${state.hasError ? 'fail' : 'ok'}');
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    AppLog.event(LogCat.auth, 'register start (${emailDomainForLog(email)})');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .register(email: email, password: password);
    });
    AppLog.event(LogCat.auth, 'register ${state.hasError ? 'fail' : 'ok'}');
  }

  Future<void> logout() async {
    AppLog.event(LogCat.auth, 'logout start');
    await _ref.read(authRepositoryProvider).logout();
    await _safeEvictPlaybackCache();
    state = const AsyncValue.data(null);
    AppLog.event(LogCat.auth, 'logout ok');
  }

  /// Invoked by the dio 401-retry interceptor when a token refresh fails: the
  /// session is unrecoverable, so clear tokens and drop to signed-out. The nav
  /// guard then redirects to welcome.
  void signedOutByInterceptor() {
    if (!mounted) return;
    AppLog.event(LogCat.auth, 'signedOutByInterceptor refresh-failed');
    _ref.read(tokenStoreProvider).clear();
    // Fire-and-forget: this is a forced sync teardown path, but the leftover
    // plaintext scratch cache is exactly as unacceptable here as on an
    // explicit logout (okt-audit PASS-2 FINDING-1).
    unawaited(_safeEvictPlaybackCache());
    state = const AsyncValue.data(null);
  }

  /// Runs [_evictPlaybackCache], never letting it block or crash the actual
  /// sign-out. The scratch-cache sweep is defense-in-depth cleanup, not the
  /// primary effect of logging out — a caller must never be stranded
  /// signed-in (or hang) just because this best-effort cleanup couldn't run
  /// or run promptly.
  ///
  /// Bounded with a timeout, not just a try/catch: an unmocked
  /// `path_provider` platform channel (e.g. a widget-test harness that
  /// doesn't stub `PathProviderPlatform.instance`, or a genuinely wedged
  /// plugin on a real device) doesn't necessarily THROW — its `MethodChannel`
  /// call can simply never resolve, which a bare `try/catch` does nothing to
  /// bound. A `catch` alone reproduced exactly this as a real regression: a
  /// `MethodChannel` awaiting a reply that never (currently) comes silently
  /// stalls `logout()` forever before it ever reaches
  /// `state = AsyncValue.data(null)`, stranding the UI on the signed-in
  /// screen instead of redirecting to Welcome.
  Future<void> _safeEvictPlaybackCache() async {
    try {
      await _evictPlaybackCache().timeout(const Duration(seconds: 3));
    } catch (e, st) {
      AppLog.error(
        LogCat.auth,
        'logout: playback scratch cache eviction failed or timed out '
        '(non-fatal)',
        e,
        st,
      );
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>(
      (ref) => AuthController(ref),
    );

/// Reduces an email to just its domain for non-sensitive auth breadcrumbs.
///
/// SECURITY: the local-part (the user identity) and any credential MUST NEVER
/// reach the log. Only the domain after the last `@` is returned; a string with
/// no usable domain collapses to `'unknown'`. Covered by
/// `test/features/auth/auth_log_redaction_test.dart`.
String emailDomainForLog(String email) {
  final at = email.lastIndexOf('@');
  return at >= 0 && at < email.length - 1 ? email.substring(at + 1) : 'unknown';
}
