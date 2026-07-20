import 'package:dio/dio.dart';

import '../../core/device/device_identity.dart';
import '../../core/device/device_model_resolver.dart';
import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import '../../core/http/token_store.dart';
import 'auth_models.dart';

/// Talks to the Guardian auth endpoints and persists the resulting tokens.
class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
    DeviceIdentity? deviceIdentity,
  }) : this._(
         apiClient,
         tokenStore,
         deviceIdentity ??
             SecureDeviceIdentity(modelResolver: resolveDeviceModel),
       );

  AuthRepository._(this._apiClient, this._tokenStore, this._deviceIdentity);

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  final DeviceIdentity _deviceIdentity;

  /// `POST /api/auth/login`. On success, stores the access/refresh tokens.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: await _authBody(email: email, password: password),
      );
      return _handleAuthResponse(response);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/auth/register`. On success, stores the access/refresh tokens.
  ///
  /// Mirrors the RN signup flow (`processes/auth.ts`): the backend
  /// (`AuthCredentials`) only accepts email + password; the display name is
  /// collected client-side for UX but not part of the register payload.
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: await _authBody(email: email, password: password),
      );
      return _handleAuthResponse(response, context: _AuthContext.register);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> _authBody({
    required String email,
    required String password,
  }) async {
    final device = await _deviceIdentity.current();
    return {'email': email, 'password': password, 'device': device.toJson()};
  }

  /// `POST /api/auth/forgot-password`. Starts the reset flow. The backend always
  /// responds 200 (no account enumeration); only transport errors surface here.
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/auth/reset-password`. Sets a new password from the emailed reset
  /// code. Throws [ApiException] (`invalid_reset_token` or a validation code) on
  /// failure. Does not sign the user in — they return to the login screen.
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/reset-password',
        data: {'token': token, 'password': password},
      );
      final status = response.statusCode ?? 0;
      if (status == 200 || status == 201) return;
      final code =
          errorCodeFromBody(response.data) ?? changesetErrorCode(response.data);
      throw ApiException(
        code == 'invalid_reset_token'
            ? 'That reset code is invalid or has expired.'
            : 'Could not reset your password.',
        statusCode: status,
        code: code ?? 'reset_failed',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `GET /api/auth/me`. Used on startup to validate the persisted session.
  /// Returns the authenticated [AuthUser]; throws [ApiException] (401) when the
  /// access token is missing/expired so the caller can attempt a refresh.
  Future<AuthUser> me() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/auth/me',
      );
      final status = response.statusCode ?? 0;
      final data = response.data;
      if (status == 200 && data != null) {
        final userJson = data['user'];
        return AuthUser.fromJson(
          userJson is Map<String, dynamic> ? userJson : const {},
        );
      }
      throw ApiException(
        'Session expired.',
        statusCode: status == 0 ? 401 : status,
        code: errorCodeFromBody(data),
      );
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

  /// `POST /api/auth/logout` with the stored refresh token, then clears tokens.
  /// Mirrors `authStore.signOut`: the network call is best-effort — token
  /// clearing always happens even if the server call fails.
  Future<void> logout() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient.dio.post<void>(
          '/api/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } on DioException {
        // Best-effort: ignore network/server errors on logout.
      }
    }
    await _tokenStore.clear();
  }

  Future<AuthSession> _handleAuthResponse(
    Response<Map<String, dynamic>> response, {
    _AuthContext context = _AuthContext.login,
  }) async {
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
    // Guardian returns either an `{"error": "slug"}` body or a Phoenix
    // changeset `{"errors": {...}}` body; normalize both into a code.
    final code = errorCodeFromBody(data) ?? changesetErrorCode(data);
    if (status == 401) {
      throw ApiException(
        'Invalid email or password.',
        statusCode: 401,
        code: code ?? 'invalid_credentials',
      );
    }
    if (status == 409 || code == 'email_taken') {
      throw ApiException(
        'That email is already registered.',
        statusCode: status,
        code: 'email_taken',
      );
    }
    if (status == 422) {
      throw ApiException(
        'Email and password are required.',
        statusCode: 422,
        code: code ?? 'email_and_password_required',
      );
    }
    final fallback = context == _AuthContext.register
        ? 'Registration failed.'
        : 'Login failed.';
    throw ApiException(fallback, statusCode: status, code: code);
  }
}

/// Distinguishes login vs register so error fallbacks read correctly.
enum _AuthContext { login, register }
