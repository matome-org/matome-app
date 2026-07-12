import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/auth_refresh_interceptor.dart';
import 'package:matome_flutter/core/http/token_store.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore store;

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:7001',
      // Match ApiClient: don't throw on non-2xx so the interceptor sees a 401
      // as a Response (the path it handles in onResponse).
      validateStatus: (s) => s != null && s < 500,
    ));
    adapter = DioAdapter(dio: dio);
    store = InMemoryTokenStore();
  });

  test('401 on an authed call triggers one refresh + retry with new token',
      () async {
    await store.saveTokens(accessToken: 'expired', refreshToken: 'r-1');
    var refreshCalls = 0;

    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStore: store,
        onRefresh: () async {
          refreshCalls++;
          // Simulate AuthRepository.refresh() persisting a fresh access token.
          await store.saveTokens(accessToken: 'fresh', refreshToken: 'r-2');
          return true;
        },
      ),
    );

    // The call with the expired token 401s; the retry replays with the fresh
    // token (matched by the Authorization header) and 200s.
    adapter
      ..onGet(
        '/api/recordings',
        (server) => server.reply(401, {'error': 'token_expired'}),
        headers: {'Authorization': 'Bearer expired'},
      )
      ..onGet(
        '/api/recordings',
        (server) => server.reply(200, {'recordings': []}),
        headers: {'Authorization': 'Bearer fresh'},
      );

    final res = await dio.get<Map<String, dynamic>>(
      '/api/recordings',
      options: Options(headers: {'Authorization': 'Bearer expired'}),
    );

    expect(res.statusCode, 200);
    expect(refreshCalls, 1);
    expect(await store.readAccessToken(), 'fresh');
  });

  test('concurrent 401s coalesce into exactly one refresh (single-flight)',
      () async {
    await store.saveTokens(accessToken: 'expired', refreshToken: 'r-1');
    var refreshCalls = 0;

    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStore: store,
        onRefresh: () async {
          refreshCalls++;
          // A slow refresh widens the window for staggered 401s to race in and
          // (without single-flight) trigger their own redundant refresh.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await store.saveTokens(accessToken: 'fresh', refreshToken: 'r-2');
          return true;
        },
      ),
    );

    // Five distinct authed endpoints all 401 on the expired token and 200 on
    // the fresh one. Each retries with the new Bearer header.
    for (final path in ['/api/a', '/api/b', '/api/c', '/api/d', '/api/e']) {
      adapter
        ..onGet(
          path,
          (server) => server.reply(401, {'error': 'token_expired'}),
          headers: {'Authorization': 'Bearer expired'},
        )
        ..onGet(
          path,
          (server) => server.reply(200, {'ok': true}),
          headers: {'Authorization': 'Bearer fresh'},
        );
    }

    // Fire all five at once so their 401s land within the refresh window.
    final responses = await Future.wait([
      for (final path in ['/api/a', '/api/b', '/api/c', '/api/d', '/api/e'])
        dio.get<Map<String, dynamic>>(
          path,
          options: Options(headers: {'Authorization': 'Bearer expired'}),
        ),
    ]);

    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(refreshCalls, 1, reason: 'a burst of 401s must trigger one refresh');
    expect(await store.readAccessToken(), 'fresh');
  });

  test('failed refresh surfaces the 401 and signs out', () async {
    await store.saveTokens(accessToken: 'expired', refreshToken: 'r-1');
    var signedOut = false;

    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStore: store,
        onRefresh: () async => false,
        onSignOut: () async => signedOut = true,
      ),
    );

    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(401, {'error': 'token_expired'}),
    );

    final res = await dio.get<Map<String, dynamic>>(
      '/api/recordings',
      options: Options(headers: {'Authorization': 'Bearer expired'}),
    );

    expect(res.statusCode, 401);
    expect(signedOut, isTrue);
  });

  test('does not attempt refresh on auth endpoints', () async {
    await store.saveTokens(accessToken: 'tok', refreshToken: 'r-1');
    var refreshCalls = 0;

    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStore: store,
        onRefresh: () async {
          refreshCalls++;
          return true;
        },
      ),
    );

    adapter.onPost(
      '/api/auth/login',
      (server) => server.reply(401, {'error': 'invalid_credentials'}),
      data: {'email': 'a', 'password': 'b'},
    );

    final res = await dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': 'a', 'password': 'b'},
      options: Options(headers: {'Authorization': 'Bearer tok'}),
    );

    expect(res.statusCode, 401);
    expect(refreshCalls, 0);
  });

  test('does not attempt refresh on unauthenticated requests (no Bearer)',
      () async {
    var refreshCalls = 0;

    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStore: store,
        onRefresh: () async {
          refreshCalls++;
          return true;
        },
      ),
    );

    adapter.onGet(
      '/api/health',
      (server) => server.reply(401, {'error': 'unauthorized'}),
    );

    final res = await dio.get<Map<String, dynamic>>('/api/health');

    expect(res.statusCode, 401);
    expect(refreshCalls, 0);
  });
}
