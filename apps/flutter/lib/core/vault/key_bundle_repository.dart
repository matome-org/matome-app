import 'package:dio/dio.dart';
import 'package:matome_vault/matome_vault.dart';

import '../http/api_client.dart';
import '../http/api_exception.dart';

final class AccountKeyBundle {
  const AccountKeyBundle({
    required this.accountId,
    required this.wrappedDekPw,
    required this.wrappedDekRecovery,
    required this.saltEnc,
    required this.saltRec,
    required this.saltAuth,
    required this.kdfParams,
  });

  final VaultAccountId accountId;
  final String wrappedDekPw;
  final String wrappedDekRecovery;
  final String saltEnc;
  final String saltRec;
  final String saltAuth;
  final Map<String, dynamic> kdfParams;

  factory AccountKeyBundle.fromJson(
    VaultAccountId accountId,
    Map<String, dynamic> json,
  ) {
    String requiredString(String field) {
      final value = json[field];
      if (value is! String || value.isEmpty) {
        throw KeyBundleFormatException(field);
      }
      return value;
    }

    final params = json['kdf_params'];
    if (params is! Map<String, dynamic>) {
      throw const KeyBundleFormatException('kdf_params');
    }
    return AccountKeyBundle(
      accountId: accountId,
      wrappedDekPw: requiredString('wrapped_dek_pw'),
      wrappedDekRecovery: requiredString('wrapped_dek_recovery'),
      saltEnc: requiredString('salt_enc'),
      saltRec: requiredString('salt_rec'),
      saltAuth: requiredString('salt_auth'),
      kdfParams: Map.unmodifiable(params),
    );
  }

  Map<String, dynamic> toJson() => {
    'wrapped_dek_pw': wrappedDekPw,
    'wrapped_dek_recovery': wrappedDekRecovery,
    'salt_enc': saltEnc,
    'salt_rec': saltRec,
    'salt_auth': saltAuth,
    'kdf_params': kdfParams,
  };

  AccountKeyBundle copyWith({
    VaultAccountId? accountId,
    String? wrappedDekPw,
    String? wrappedDekRecovery,
    String? saltEnc,
    String? saltRec,
    String? saltAuth,
    Map<String, dynamic>? kdfParams,
  }) => AccountKeyBundle(
    accountId: accountId ?? this.accountId,
    wrappedDekPw: wrappedDekPw ?? this.wrappedDekPw,
    wrappedDekRecovery: wrappedDekRecovery ?? this.wrappedDekRecovery,
    saltEnc: saltEnc ?? this.saltEnc,
    saltRec: saltRec ?? this.saltRec,
    saltAuth: saltAuth ?? this.saltAuth,
    kdfParams: kdfParams ?? this.kdfParams,
  );
}

final class KeyBundleFormatException implements Exception {
  const KeyBundleFormatException(this.field);
  final String field;

  @override
  String toString() => 'KeyBundleFormatException: malformed $field';
}

abstract interface class KeyBundleGateway {
  Future<AccountKeyBundle?> fetch(VaultAccountId accountId);
  Future<AccountKeyBundle> put(AccountKeyBundle bundle);
}

/// Authenticated, owner-scoped client for Core's opaque keybundle endpoint.
final class KeyBundleRepository implements KeyBundleGateway {
  KeyBundleRepository({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  @override
  Future<AccountKeyBundle?> fetch(VaultAccountId accountId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/keybundle');
      final status = response.statusCode ?? 0;
      if (status == 404) return null;
      final json = response.data?['key_bundle'];
      if (status != 200 || json is! Map<String, dynamic>) {
        throw ApiException(
          'Could not fetch the account key bundle.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return AccountKeyBundle.fromJson(accountId, json);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<AccountKeyBundle> put(AccountKeyBundle bundle) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/keybundle',
        data: bundle.toJson(),
      );
      final status = response.statusCode ?? 0;
      final json = response.data?['key_bundle'];
      if ((status != 200 && status != 201) || json is! Map<String, dynamic>) {
        throw ApiException(
          'Could not upload the account key bundle.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return AccountKeyBundle.fromJson(bundle.accountId, json);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
