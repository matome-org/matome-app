import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/features/auth/auth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore tokenStore;
  late AuthRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    repo = AuthRepository(apiClient: client, tokenStore: tokenStore);
  });

  test('login success returns session and persists tokens', () async {
    adapter.onPost(
      '/api/auth/login',
      (server) => server.reply(200, {
        'user': {'id': 1, 'email': 'dev@matome.test'},
        'access_token': 'access-123',
        'refresh_token': 'refresh-456',
        'token_type': 'Bearer',
      }),
      data: {'email': 'dev@matome.test', 'password': 'devpassword123'},
    );

    final session = await repo.login(
      email: 'dev@matome.test',
      password: 'devpassword123',
    );

    expect(session.user.id, 1);
    expect(session.user.email, 'dev@matome.test');
    expect(session.accessToken, 'access-123');
    expect(session.refreshToken, 'refresh-456');
    expect(await tokenStore.readAccessToken(), 'access-123');
    expect(await tokenStore.readRefreshToken(), 'refresh-456');
  });

  test('login 401 throws invalid_credentials ApiException', () async {
    adapter.onPost(
      '/api/auth/login',
      (server) => server.reply(401, {'error': 'invalid_credentials'}),
      data: {'email': 'dev@matome.test', 'password': 'wrong'},
    );

    expect(
      () => repo.login(email: 'dev@matome.test', password: 'wrong'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', 'invalid_credentials')),
    );
    expect(await tokenStore.readAccessToken(), isNull);
  });

  test('login 422 throws email_and_password_required', () async {
    adapter.onPost(
      '/api/auth/login',
      (server) => server.reply(422, {'error': 'email_and_password_required'}),
      data: {'email': '', 'password': ''},
    );

    expect(
      () => repo.login(email: '', password: ''),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', 'email_and_password_required')),
    );
  });

  test('network error maps to friendly ApiException', () async {
    adapter.onPost(
      '/api/auth/login',
      (server) => server.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          reason: 'down',
        ),
      ),
      data: {'email': 'a', 'password': 'b'},
    );

    expect(
      () => repo.login(email: 'a', password: 'b'),
      throwsA(isA<ApiException>()),
    );
  });

  test('register success returns session and persists tokens', () async {
    adapter.onPost(
      '/api/auth/register',
      (server) => server.reply(201, {
        'user': {'id': 7, 'email': 'new@matome.test'},
        'access_token': 'reg-access',
        'refresh_token': 'reg-refresh',
        'token_type': 'Bearer',
      }),
      data: {'email': 'new@matome.test', 'password': 'pw123456'},
    );

    final session = await repo.register(
      email: 'new@matome.test',
      password: 'pw123456',
    );

    expect(session.user.id, 7);
    expect(session.accessToken, 'reg-access');
    expect(await tokenStore.readAccessToken(), 'reg-access');
    expect(await tokenStore.readRefreshToken(), 'reg-refresh');
  });

  test('register 409 throws email_taken ApiException', () async {
    adapter.onPost(
      '/api/auth/register',
      (server) => server.reply(409, {'error': 'email_taken'}),
      data: {'email': 'taken@matome.test', 'password': 'pw123456'},
    );

    expect(
      () => repo.register(email: 'taken@matome.test', password: 'pw123456'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'email_taken')),
    );
  });

  test('register 422 changeset (email taken) maps to email_taken', () async {
    adapter.onPost(
      '/api/auth/register',
      (server) => server.reply(422, {
        'errors': {
          'email': ['has already been taken'],
        },
      }),
      data: {'email': 'dev@matome.test', 'password': 'pw123456'},
    );

    expect(
      () => repo.register(email: 'dev@matome.test', password: 'pw123456'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'email_taken')),
    );
  });

  test('me returns the authenticated user', () async {
    adapter.onGet(
      '/api/auth/me',
      (server) => server.reply(200, {
        'user': {'id': 1, 'email': 'dev@matome.test'},
      }),
    );

    final user = await repo.me();
    expect(user.id, 1);
    expect(user.email, 'dev@matome.test');
  });

  test('me throws ApiException(401) on unauthorized', () async {
    adapter.onGet(
      '/api/auth/me',
      (server) => server.reply(401, {'error': 'unauthorized'}),
    );

    expect(
      () => repo.me(),
      throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('logout posts refresh token then clears local tokens', () async {
    await tokenStore.saveTokens(accessToken: 'a', refreshToken: 'refresh-456');
    adapter.onPost(
      '/api/auth/logout',
      (server) => server.reply(204, null),
      data: {'refresh_token': 'refresh-456'},
    );

    await repo.logout();

    expect(await tokenStore.readAccessToken(), isNull);
    expect(await tokenStore.readRefreshToken(), isNull);
  });

  test('refresh uses stored refresh token and updates session', () async {
    await tokenStore.saveTokens(
      accessToken: 'old',
      refreshToken: 'refresh-456',
    );
    adapter.onPost(
      '/api/auth/refresh',
      (server) => server.reply(200, {
        'user': {'id': 1, 'email': 'dev@matome.test'},
        'access_token': 'access-new',
        'refresh_token': 'refresh-new',
        'token_type': 'Bearer',
      }),
      data: {'refresh_token': 'refresh-456'},
    );

    final session = await repo.refresh();

    expect(session.accessToken, 'access-new');
    expect(await tokenStore.readAccessToken(), 'access-new');
  });
}
