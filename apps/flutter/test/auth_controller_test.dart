import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/auth/auth_controller.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/auth/auth_repository.dart';

/// Fake repository that records calls and returns scripted results so the
/// controller's state transitions can be asserted without a network.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._tokenStore);

  final InMemoryTokenStore _tokenStore;

  AuthSession? loginResult;
  Object? loginError;
  AuthSession? registerResult;
  Object? registerError;
  AuthUser? meResult;
  Object? meError;
  AuthSession? refreshResult;
  Object? refreshError;
  int logoutCalls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    await _tokenStore.saveTokens(
      accessToken: loginResult!.accessToken,
      refreshToken: loginResult!.refreshToken,
    );
    return loginResult!;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    if (registerError != null) throw registerError!;
    await _tokenStore.saveTokens(
      accessToken: registerResult!.accessToken,
      refreshToken: registerResult!.refreshToken,
    );
    return registerResult!;
  }

  @override
  Future<AuthUser> me() async {
    if (meError != null) throw meError!;
    return meResult!;
  }

  @override
  Future<AuthSession> refresh() async {
    if (refreshError != null) throw refreshError!;
    return refreshResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await _tokenStore.clear();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}
}

ProviderContainer _container(
  InMemoryTokenStore store,
  _FakeAuthRepository repo,
) {
  return ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

const _session = AuthSession(
  user: AuthUser(id: 1, email: 'dev@matome.test'),
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
);

/// Fake path_provider so the default (non-injected) logout sweep —
/// `AuthController`'s default `evictPlaybackCache` → `defaultPlaybackScratchDir`
/// → `getTemporaryDirectory()` — resolves against a real temp dir instead of
/// hanging on the absent plugin channel in tests that don't inject a fake
/// `evictPlaybackCache` (mirrors `matome_add_photo_e2e_test.dart`'s
/// `_FakePathProvider`).
class _FakeTempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeTempPathProvider(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryTokenStore store;
  late _FakeAuthRepository repo;
  late Directory fakeTempRoot;

  setUp(() {
    store = InMemoryTokenStore();
    repo = _FakeAuthRepository(store);
    fakeTempRoot = Directory.systemTemp.createTempSync('auth_fake_temp_');
    PathProviderPlatform.instance = _FakeTempPathProvider(fakeTempRoot.path);
  });
  tearDown(() {
    if (fakeTempRoot.existsSync()) fakeTempRoot.deleteSync(recursive: true);
  });

  test('bootstrap with no tokens resolves to signed-out', () async {
    final c = _container(store, repo);
    addTearDown(c.dispose);

    final controller = c.read(authControllerProvider.notifier);
    await controller.restoreSession();

    final state = c.read(authControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.valueOrNull, isNull);
  });

  test(
    'bootstrap with valid tokens validates via me() -> authenticated',
    () async {
      await store.saveTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
      repo.meResult = const AuthUser(id: 1, email: 'dev@matome.test');

      final c = _container(store, repo);
      addTearDown(c.dispose);
      await c.read(authControllerProvider.notifier).restoreSession();

      final state = c.read(authControllerProvider);
      expect(state.valueOrNull?.user.id, 1);
    },
  );

  test(
    'bootstrap with stale tokens (me 401) clears tokens -> signed-out',
    () async {
      await store.saveTokens(accessToken: 'old', refreshToken: 'old-r');
      repo.meError = const ApiException('expired', statusCode: 401);

      final c = _container(store, repo);
      addTearDown(c.dispose);
      await c.read(authControllerProvider.notifier).restoreSession();

      expect(c.read(authControllerProvider).valueOrNull, isNull);
      expect(await store.readAccessToken(), isNull);
    },
  );

  test('login success transitions loading -> data(session)', () async {
    repo.loginResult = _session;

    final c = _container(store, repo);
    addTearDown(c.dispose);
    final controller = c.read(authControllerProvider.notifier);
    await controller.restoreSession();

    await controller.login(
      email: 'dev@matome.test',
      password: 'devpassword123',
    );

    final state = c.read(authControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull?.accessToken, 'access-1');
  });

  test('login failure transitions to error state', () async {
    repo.loginError = const ApiException(
      'bad',
      statusCode: 401,
      code: 'invalid_credentials',
    );

    final c = _container(store, repo);
    addTearDown(c.dispose);
    final controller = c.read(authControllerProvider.notifier);
    await controller.restoreSession();

    await controller.login(email: 'x', password: 'y');

    final state = c.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<ApiException>());
  });

  test('register success authenticates', () async {
    repo.registerResult = _session;

    final c = _container(store, repo);
    addTearDown(c.dispose);
    final controller = c.read(authControllerProvider.notifier);
    await controller.restoreSession();

    await controller.register(email: 'a@b.test', password: 'pw123456');

    expect(c.read(authControllerProvider).valueOrNull?.user.id, 1);
  });

  test('logout calls repo.logout and resets to signed-out', () async {
    repo.loginResult = _session;

    final c = _container(store, repo);
    addTearDown(c.dispose);
    final controller = c.read(authControllerProvider.notifier);
    await controller.restoreSession();
    await controller.login(email: 'a', password: 'b');
    expect(c.read(authControllerProvider).valueOrNull, isNotNull);

    await controller.logout();

    expect(repo.logoutCalls, 1);
    expect(c.read(authControllerProvider).valueOrNull, isNull);
  });

  test('okt-audit PASS-2 FINDING-1: logout() sweeps the playback scratch '
      'cache (the "logout/account-switch" eviction point named in the '
      'finding) AFTER repo.logout() succeeds', () async {
    repo.loginResult = _session;
    var evictCalls = 0;

    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          (ref) => AuthController(
            ref,
            evictPlaybackCache: () async {
              evictCalls++;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.restoreSession();
    await controller.login(email: 'a', password: 'b');

    await controller.logout();

    expect(evictCalls, 1);
    expect(repo.logoutCalls, 1);
  });

  test('okt-audit PASS-2 FINDING-1: logout() real (non-fake) sweep actually '
      'deletes the on-disk playback scratch cache directory', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'auth_controller_logout_evict_',
    );
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final scratchDir = Directory('${tmp.path}/matome_playback_cache')
      ..createSync(recursive: true);
    File('${scratchDir.path}/rec_a.playback').writeAsBytesSync([1, 2, 3]);

    repo.loginResult = _session;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          (ref) => AuthController(
            ref,
            evictPlaybackCache: () => scratchDir.delete(recursive: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.restoreSession();
    await controller.login(email: 'a', password: 'b');

    await controller.logout();

    expect(
      await scratchDir.exists(),
      isFalse,
      reason:
          'logout must wipe the whole playback scratch cache, not '
          'just log out of the API session',
    );
  });

  test(
    'okt-audit PASS-2 FINDING-1: signedOutByInterceptor() also sweeps the '
    'playback scratch cache (forced-signout is a session boundary too)',
    () async {
      final evicted = Completer<void>();

      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              evictPlaybackCache: () async {
                if (!evicted.isCompleted) evicted.complete();
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await controller.restoreSession();

      controller.signedOutByInterceptor();

      await evicted.future.timeout(const Duration(seconds: 2));
    },
  );
}
