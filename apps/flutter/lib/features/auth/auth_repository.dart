import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import '../../core/http/token_store.dart';
import 'auth_models.dart';

/// Talks to the Guardian auth endpoints and persists the resulting tokens.
class AuthRepository {
  AuthRepository({required ApiClient apiClient, required TokenStore tokenStore})
      : this._(apiClient, tokenStore);

  AuthRepository._(this._apiClient, this._tokenStore);

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  /// `POST /api/auth/login`. On success, stores the access/refresh tokens.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      return _handleAuthResponse(response);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/auth/refresh`. Optional; uses the stored refresh token.
  Future<AuthSession> refresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException('No refresh token available.', statusCode: 401);
    }
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return _handleAuthResponse(response);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> logout() => _tokenStore.clear();

  Future<AuthSession> _handleAuthResponse(
    Response<Map<String, dynamic>> response,
  ) async {
    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status == 200 || status == 201) {
      if (data == null) {
        throw const ApiException('Empty auth response.', statusCode: 200);
      }
      final session = AuthSession.fromJson(data);
      await _tokenStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return session;
    }
    final code = errorCodeFromBody(data);
    if (status == 401) {
      throw ApiException(
        'Invalid email or password.',
        statusCode: 401,
        code: code ?? 'invalid_credentials',
      );
    }
    if (status == 422) {
      throw ApiException(
        'Email and password are required.',
        statusCode: 422,
        code: code ?? 'email_and_password_required',
      );
    }
    throw ApiException('Login failed.', statusCode: status, code: code);
  }
}
