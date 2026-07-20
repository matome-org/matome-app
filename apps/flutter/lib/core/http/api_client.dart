import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'auth_refresh_interceptor.dart';
import 'token_store.dart';

/// Thin wrapper around [Dio] configured for the Phoenix Core API.
///
/// Installs an interceptor that injects `Authorization: Bearer <access_token>`
/// (read from the [TokenStore]) on every request once the user is logged in.
class ApiClient {
  ApiClient({required TokenStore tokenStore, Dio? dio, String? baseUrl})
    : this._(tokenStore, dio, baseUrl);

  ApiClient._(this._tokenStore, Dio? dio, String? baseUrl)
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              contentType: 'application/json',
              // Don't throw on non-2xx so callers can map status codes to
              // domain errors (e.g. 401 -> invalid credentials).
              validateStatus: (status) => status != null && status < 500,
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStore _tokenStore;

  bool _refreshAttached = false;

  /// Installs the 401-retry interceptor (F4 #777 follow-up). Wired up after
  /// the [AuthRepository] exists, since the refresh callback depends on it.
  ///
  /// * [onRefresh] — runs `AuthRepository.refresh()`; returns `true` on success.
  /// * [onSignOut] — called when refresh fails so the app can drop the session.
  void attachRefreshInterceptor({
    required RefreshResult onRefresh,
    FutureOr<void> Function()? onSignOut,
  }) {
    if (_refreshAttached) return;
    _refreshAttached = true;
    dio.interceptors.add(
      AuthRefreshInterceptor(
        dio: dio,
        tokenStore: _tokenStore,
        onRefresh: onRefresh,
        onSignOut: onSignOut,
      ),
    );
  }
}
