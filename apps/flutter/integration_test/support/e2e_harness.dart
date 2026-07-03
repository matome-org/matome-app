import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:matome_flutter/app/router.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/i18n/locale_controller.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/core/theme/theme_controller.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/auth/auth_repository.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Shared E2E harness: boots the REAL app root (the production [routerProvider]
/// with its real auth-driven redirect) under a [ProviderScope] whose IO-bound
/// providers are overridden with in-memory fakes. Lets the integration tests
/// drive the same router/guard/screens the shipping app uses, headlessly.
///
/// Mirrors `lib/main.dart`'s `MatomeApp` but is dependency-injected through the
/// override list so no provider touches the network, secure storage, or the
/// platform mic.

/// The default seeded test user used by [FakeE2EAuthRepository].
const kE2EUser = AuthUser(id: 1, email: 'dev@matome.test');

/// The session a successful [FakeE2EAuthRepository.login] / restore produces.
const kE2ESession = AuthSession(
  user: kE2EUser,
  accessToken: 'e2e-access',
  refreshToken: 'e2e-refresh',
);

/// In-memory auth repo for the E2E harness. `me()` validates a restored
/// session, `login()` succeeds for the seed credentials (and writes tokens so a
/// subsequent restore would also pass), `logout()` clears tokens. Only the
/// surface the [AuthController] drives is implemented.
class FakeE2EAuthRepository implements AuthRepository {
  FakeE2EAuthRepository(this._store, {this.loginShouldFail = false});

  final InMemoryTokenStore _store;

  /// When true, `login()` throws — used to exercise the error path.
  final bool loginShouldFail;

  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthUser> me() async => kE2EUser;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (loginShouldFail) {
      throw StateError('login failed');
    }
    await _store.saveTokens(
      accessToken: kE2ESession.accessToken,
      refreshToken: kE2ESession.refreshToken!,
    );
    return kE2ESession;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    return login(email: email, password: password);
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await _store.clear();
  }

  @override
  Future<AuthSession> refresh() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}
}

/// Builds the app root for an E2E test. Pass the IO provider [overrides]
/// (token store, db, auth repo, settings store, plus any recording fakes).
Widget buildE2EApp({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: TranslationProvider(child: const _E2EApp()),
  );
}

/// The real `MatomeApp` body, rebuilt here so the harness can inject overrides
/// at the [ProviderScope] above it. Kept byte-faithful to `lib/main.dart`.
class _E2EApp extends ConsumerWidget {
  const _E2EApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'Matome',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
