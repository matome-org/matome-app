import 'dart:async';

import 'package:dio/dio.dart';

import 'token_store.dart';

/// Outcome of an attempted token refresh.
typedef RefreshResult = Future<bool> Function();

/// Dio interceptor that transparently recovers from an expired access token.
///
/// On a `401` response to any *authenticated* request (i.e. one that carried a
/// Bearer token and is not itself an auth endpoint), it calls [onRefresh]
/// **once**, and — if that succeeds — replays the original request with the new
/// access token. If the refresh fails, [onSignOut] is invoked and the original
/// `401` is surfaced so the UI can fall back to the welcome screen.
///
/// This is the F4 (#777) follow-up: #764 shipped only a *manual* refresh, so
/// long-lived authed calls (recordings list, channel token, …) would hard-fail
/// on token expiry. This interceptor makes them survive it.
///
/// Re-entrancy: a single in-flight refresh is shared across concurrent 401s
/// via [_refreshing], so a burst of expired requests triggers exactly one
/// `/api/auth/refresh` round-trip. Each original request is retried at most
/// once (guarded by a per-request `_retriedFlag` extra) to prevent loops.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required Dio dio,
    required TokenStore tokenStore,
    required this.onRefresh,
    this.onSignOut,
    // ignore: prefer_initializing_formals
  })  : _dio = dio,
        // ignore: prefer_initializing_formals
        _tokenStore = tokenStore;

  final Dio _dio;
  final TokenStore _tokenStore;

  /// Performs the token refresh; returns `true` when new tokens were stored.
  final RefreshResult onRefresh;

  /// Called when a refresh attempt fails — the session is no longer valid.
  final FutureOr<void> Function()? onSignOut;

  static const _retriedFlag = 'auth_refresh_retried';

  /// Paths the interceptor must never try to refresh-and-retry (otherwise a
  /// failed login/refresh/logout would recurse).
  static const _authPaths = {
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/refresh',
    '/api/auth/logout',
  };

  /// Shared in-flight refresh so concurrent 401s coalesce into one round-trip.
  Future<bool>? _refreshing;

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_shouldAttempt(response.statusCode, response.requestOptions)) {
      return handler.next(response);
    }
    await _recover(response.requestOptions, handler, response: response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    if (!_shouldAttempt(status, err.requestOptions)) {
      return handler.next(err);
    }
    await _recover(err.requestOptions, handler, error: err);
  }

  bool _shouldAttempt(int? status, RequestOptions options) {
    if (status != 401) return false;
    if (options.extra[_retriedFlag] == true) return false;
    if (_authPaths.contains(options.path)) return false;
    // Only refresh requests that actually carried a Bearer token.
    final auth = options.headers['Authorization'];
    return auth is String && auth.startsWith('Bearer ');
  }

  Future<void> _recover(
    RequestOptions options,
    dynamic handler, {
    Response? response,
    DioException? error,
  }) async {
    bool refreshed;
    try {
      refreshed = await (_refreshing ??= _runRefresh());
    } finally {
      _refreshing = null;
    }

    if (!refreshed) {
      await onSignOut?.call();
      if (handler is ResponseInterceptorHandler && response != null) {
        return handler.next(response);
      }
      if (handler is ErrorInterceptorHandler && error != null) {
        return handler.next(error);
      }
      return;
    }

    // Replay the original request with the freshly stored access token.
    final token = await _tokenStore.readAccessToken();
    final retryOptions = Options(
      method: options.method,
      headers: Map<String, dynamic>.from(options.headers)
        ..['Authorization'] = 'Bearer $token',
      responseType: options.responseType,
      contentType: options.contentType,
      sendTimeout: options.sendTimeout,
      receiveTimeout: options.receiveTimeout,
      extra: Map<String, dynamic>.from(options.extra)..[_retriedFlag] = true,
    );

    try {
      final retried = await _dio.request<dynamic>(
        options.path,
        data: options.data,
        queryParameters: options.queryParameters,
        options: retryOptions,
        cancelToken: options.cancelToken,
      );
      if (handler is ResponseInterceptorHandler) {
        return handler.resolve(retried);
      }
      if (handler is ErrorInterceptorHandler) {
        return handler.resolve(retried);
      }
    } on DioException catch (e) {
      if (handler is ErrorInterceptorHandler) return handler.next(e);
      if (handler is ResponseInterceptorHandler && response != null) {
        return handler.next(response);
      }
    }
  }

  Future<bool> _runRefresh() async {
    try {
      return await onRefresh();
    } catch (_) {
      return false;
    }
  }
}
