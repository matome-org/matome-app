import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'token_store.dart';

/// Thin wrapper around [Dio] configured for the Phoenix Core API.
///
/// Installs an interceptor that injects `Authorization: Bearer <access_token>`
/// (read from the [TokenStore]) on every request once the user is logged in.
class ApiClient {
  ApiClient({required TokenStore tokenStore, Dio? dio, String? baseUrl})
      : this._(tokenStore, dio, baseUrl);

  ApiClient._(this._tokenStore, Dio? dio, String? baseUrl)
      : dio = dio ??
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
}
