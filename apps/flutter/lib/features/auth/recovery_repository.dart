import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/http/api_exception.dart';

/// The recovery-relevant fields of the caller's key bundle, as returned by
/// `GET /api/keybundle/recovery` — the SAME opaque JSON shape as the
/// authenticated `GET /api/keybundle` (`KeyBundleController.show`); this
/// route just accepts a reset token instead of a normal session token.
class RecoveryKeyBundle {
  const RecoveryKeyBundle({
    required this.wrappedDekPw,
    required this.wrappedDekRecovery,
    required this.saltEnc,
    required this.saltRec,
    required this.saltAuth,
    required this.kdfParams,
  });

  final String wrappedDekPw;
  final String wrappedDekRecovery;
  final String saltEnc;
  final String saltRec;
  final String saltAuth;
  final Map<String, dynamic> kdfParams;

  /// Parses the `key_bundle` object from `GET/PUT /api/keybundle/recovery`.
  ///
  /// Fails EXPLICITLY (throws [RecoveryBundleFormatException]) on any
  /// missing or malformed field (okt-audit info follow-up, #1866) — a
  /// partial/malformed server response must never silently coerce into a
  /// bundle carrying empty-string crypto material (`''`/`{}`), which would
  /// otherwise flow into `unwrapKey`/envelope logic downstream looking like
  /// valid-but-wrong key material instead of a loud, attributable parse
  /// failure at the boundary where the bad data actually entered.
  factory RecoveryKeyBundle.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw RecoveryBundleFormatException(key);
      }
      return value;
    }

    final kdfParams = json['kdf_params'];
    if (kdfParams is! Map<String, dynamic>) {
      throw const RecoveryBundleFormatException('kdf_params');
    }

    return RecoveryKeyBundle(
      wrappedDekPw: requireString('wrapped_dek_pw'),
      wrappedDekRecovery: requireString('wrapped_dek_recovery'),
      saltEnc: requireString('salt_enc'),
      saltRec: requireString('salt_rec'),
      saltAuth: requireString('salt_auth'),
      kdfParams: kdfParams,
    );
  }
}

/// Thrown by [RecoveryKeyBundle.fromJson] when the server's `key_bundle`
/// JSON is missing [field] or carries the wrong type for it — a boundary
/// failure, never silently coerced to an empty placeholder.
class RecoveryBundleFormatException implements Exception {
  const RecoveryBundleFormatException(this.field);

  final String field;

  @override
  String toString() =>
      'RecoveryBundleFormatException: missing or malformed "$field" field '
      'in the recovery key bundle response';
}

/// Talks to the pre-auth recovery bootstrap endpoints (task #1854; resolves
/// the CF-1 "pre-auth salt bootstrap" gap flagged in
/// .docs/internal/at-rest-key-flow.md §5): during a "forgot password" reset
/// the user has no session, so `GET/PUT /api/keybundle` (which require a
/// normal Bearer access token) are unreachable. Instead, this repository
/// authenticates with the short-lived `reset` token minted by
/// `POST /api/auth/forgot-password` — proof of email ownership standing in
/// for the normal session, scoped server-side to ONLY these two routes
/// (`MatomeApiWeb.Plugs.RequireResetToken`) and rate-limited the same way
/// `/keybundle` is (`:keybundle_recovery_rate_limit`, reusing task #1851's
/// `RateLimit` plug).
///
/// Deliberately does NOT reuse `ApiClient`'s shared `Dio` — that instance's
/// interceptor injects the cached session access token on every request,
/// which would silently overwrite the reset-token header here if the device
/// happened to still have one cached. The two auth channels must never mix.
class RecoveryRepository {
  RecoveryRepository({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              contentType: 'application/json',
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  final Dio _dio;

  /// `GET /api/keybundle/recovery`, authenticated with [resetToken].
  Future<RecoveryKeyBundle> fetchRecoveryBundle({
    required String resetToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/keybundle/recovery',
        options: Options(headers: {'Authorization': 'Bearer $resetToken'}),
      );
      final status = response.statusCode ?? 0;
      final data = response.data;
      if (status == 200 && data != null) {
        final bundleJson = data['key_bundle'];
        if (bundleJson is Map<String, dynamic>) {
          return RecoveryKeyBundle.fromJson(bundleJson);
        }
      }
      if (status == 404) {
        throw const ApiException(
          'No recovery code was enrolled for this account.',
          statusCode: 404,
          code: 'not_found',
        );
      }
      if (status == 401) {
        throw const ApiException(
          'That reset link is invalid or has expired.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      throw ApiException(
        'Could not fetch recovery data.',
        statusCode: status,
        code: errorCodeFromBody(data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on RecoveryBundleFormatException catch (error) {
      // Normalize to this method's ApiException contract (okt-audit info
      // follow-up, #1866): `RecoveryKeyBundle.fromJson` now throws EXPLICITLY
      // on a malformed 200 body instead of silently coercing to ''/{} — but
      // every OTHER failure branch here surfaces as [ApiException], so a
      // caller pattern-matching on that type (the convention this repo's API
      // layer follows) must see the same type here too. `error.toString()`
      // (which names the specific malformed field) is preserved in the
      // message for diagnosability.
      throw ApiException(
        'The recovery data returned by the server was malformed: $error',
        statusCode: 200,
        code: 'malformed_response',
      );
    }
  }

  /// `PUT /api/keybundle/recovery`, authenticated with [resetToken]. Uploads
  /// the rotated bundle after a successful reset: the new `wrapped_dek_pw`
  /// AND a brand-new `wrapped_dek_recovery`/`salt_rec` pair (the just-used
  /// recovery code is invalidated the moment this call succeeds — see
  /// `recovery_flow.dart`'s `resetPasswordWithRecoveryCode`).
  Future<void> uploadRotatedBundle({
    required String resetToken,
    required String wrappedDekPw,
    required String wrappedDekRecovery,
    required String saltEnc,
    required String saltRec,
    required String saltAuth,
    required Map<String, dynamic> kdfParams,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/keybundle/recovery',
        options: Options(headers: {'Authorization': 'Bearer $resetToken'}),
        data: {
          'wrapped_dek_pw': wrappedDekPw,
          'wrapped_dek_recovery': wrappedDekRecovery,
          'salt_enc': saltEnc,
          'salt_rec': saltRec,
          'salt_auth': saltAuth,
          'kdf_params': kdfParams,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 200 || status == 201) return;
      if (status == 401) {
        throw const ApiException(
          'That reset link is invalid or has expired.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      throw ApiException(
        'Could not upload the rotated recovery bundle.',
        statusCode: status,
        code: errorCodeFromBody(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
