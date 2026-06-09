import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

ProviderContainer _container(InMemoryTokenStore store, _FakeAuthRepository repo) {
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

void main() {
  late InMemoryTokenStore store;
  late _FakeAuthRepository repo;

  setUp(() {
    store = InMemoryTokenStore();
    repo = _FakeAuthRepository(store);
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

  test('bootstrap with valid tokens validates via me() -> authenticated',
      () async {
    await store.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
    repo.meResult = const AuthUser(id: 1, email: 'dev@matome.test');

    final c = _container(store, repo);
    addTearDown(c.dispose);
    await c.read(authControllerProvider.notifier).restoreSession();

    final state = c.read(authControllerProvider);
    expect(state.valueOrNull?.user.id, 1);
  });

  test('bootstrap with stale tokens (me 401) clears tokens -> signed-out',
      () async {
    await store.saveTokens(accessToken: 'old', refreshToken: 'old-r');
    repo.meError = const ApiException('expired', statusCode: 401);

    final c = _container(store, repo);
    addTearDown(c.dispose);
    await c.read(authControllerProvider.notifier).restoreSession();

    expect(c.read(authControllerProvider).valueOrNull, isNull);
    expect(await store.readAccessToken(), isNull);
  });

  test('login success transitions loading -> data(session)', () async {
    repo.loginResult = _session;

    final c = _container(store, repo);
    addTearDown(c.dispose);
    final controller = c.read(authControllerProvider.notifier);
    await controller.restoreSession();

    await controller.login(email: 'dev@matome.test', password: 'devpassword123');

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
}
