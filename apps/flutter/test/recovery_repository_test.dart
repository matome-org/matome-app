// Tests for RecoveryRepository — task #1854, plan #131 W3. Written FIRST per
// TDD.
//
// Covers the client side of the pre-auth bootstrap this task resolves (the
// CF-1 gap): a user with no password cannot hit the normal authenticated
// `/api/keybundle` route, so recovery instead authenticates with the
// short-lived password-reset token (minted by `/api/auth/forgot-password`)
// against the new `/api/keybundle/recovery` GET/PUT routes. This repository
// deliberately does NOT share `ApiClient`'s Dio instance/interceptor: that
// interceptor injects the normal session access token on every request,
// which would silently clobber the reset-token header on a device that
// still has a (possibly stale) session cached — the two auth channels must
// stay fully independent.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/features/auth/recovery_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late RecoveryRepository repo;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    repo = RecoveryRepository(dio: dio);
  });

  test('fetchRecoveryBundle sends the reset token as Bearer auth, not any '
      'cached session token', () async {
    adapter.onGet(
      '/api/keybundle/recovery',
      (server) => server.reply(200, {
        'key_bundle': {
          'wrapped_dek_pw': 'pw-blob',
          'wrapped_dek_recovery': 'recovery-blob',
          'salt_enc': 'salt-enc',
          'salt_rec': 'salt-rec',
          'salt_auth': 'salt-auth',
          'kdf_params': {'profile': 'argon2id-v1-portable'},
          'updated_at': '2026-01-01T00:00:00Z',
        },
      }),
      headers: {'authorization': 'Bearer reset-tok-123'},
    );

    final bundle = await repo.fetchRecoveryBundle(resetToken: 'reset-tok-123');

    expect(bundle.saltRec, 'salt-rec');
    expect(bundle.wrappedDekRecovery, 'recovery-blob');
    expect(bundle.kdfParams['profile'], 'argon2id-v1-portable');
  });

  test(
    'fetchRecoveryBundle surfaces 404 as ApiException (no bundle enrolled)',
    () async {
      adapter.onGet(
        '/api/keybundle/recovery',
        (server) => server.reply(404, {'error': 'not_found'}),
        headers: {'authorization': 'Bearer reset-tok-404'},
      );

      expect(
        () => repo.fetchRecoveryBundle(resetToken: 'reset-tok-404'),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('fetchRecoveryBundle surfaces a malformed 200 key_bundle as an '
      'ApiException (okt-audit info follow-up #1866) — RecoveryKeyBundle.'
      'fromJson\'s RecoveryBundleFormatException must NOT leak past this '
      'method\'s established ApiException contract', () async {
    adapter.onGet(
      '/api/keybundle/recovery',
      (server) => server.reply(200, {
        'key_bundle': {
          // Missing every required field.
          'updated_at': '2026-01-01T00:00:00Z',
        },
      }),
      headers: {'authorization': 'Bearer reset-tok-malformed'},
    );

    await expectLater(
      () => repo.fetchRecoveryBundle(resetToken: 'reset-tok-malformed'),
      throwsA(isA<ApiException>()),
    );
  });

  test(
    'fetchRecoveryBundle surfaces 401 (invalid/expired reset token)',
    () async {
      adapter.onGet(
        '/api/keybundle/recovery',
        (server) => server.reply(401, {'error': 'unauthorized'}),
        headers: {'authorization': 'Bearer bad-token'},
      );

      expect(
        () => repo.fetchRecoveryBundle(resetToken: 'bad-token'),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('uploadRotatedBundle PUTs the new wrapped fields under the reset '
      'token', () async {
    adapter.onPut(
      '/api/keybundle/recovery',
      (server) => server.reply(200, {
        'key_bundle': {
          'wrapped_dek_pw': 'new-pw-blob',
          'wrapped_dek_recovery': 'new-recovery-blob',
          'salt_enc': 'new-salt-enc',
          'salt_rec': 'new-salt-rec',
          'salt_auth': 'new-salt-auth',
          'kdf_params': {'profile': 'argon2id-v1-portable'},
          'updated_at': '2026-01-01T00:00:00Z',
        },
      }),
      data: {
        'wrapped_dek_pw': 'new-pw-blob',
        'wrapped_dek_recovery': 'new-recovery-blob',
        'salt_enc': 'new-salt-enc',
        'salt_rec': 'new-salt-rec',
        'salt_auth': 'new-salt-auth',
        'kdf_params': {'profile': 'argon2id-v1-portable'},
      },
      headers: {'authorization': 'Bearer reset-tok-123'},
    );

    await repo.uploadRotatedBundle(
      resetToken: 'reset-tok-123',
      wrappedDekPw: 'new-pw-blob',
      wrappedDekRecovery: 'new-recovery-blob',
      saltEnc: 'new-salt-enc',
      saltRec: 'new-salt-rec',
      saltAuth: 'new-salt-auth',
      kdfParams: const {'profile': 'argon2id-v1-portable'},
    );
    // No throw == success; the adapter's `data:` matcher already asserts
    // the exact request body shape.
  });

  group('RecoveryKeyBundle.fromJson — boundary validation (okt-audit info '
      'follow-up #1866)', () {
    Map<String, dynamic> validJson() => {
      'wrapped_dek_pw': 'pw-blob',
      'wrapped_dek_recovery': 'recovery-blob',
      'salt_enc': 'salt-enc',
      'salt_rec': 'salt-rec',
      'salt_auth': 'salt-auth',
      'kdf_params': {'profile': 'argon2id-v1-portable'},
    };

    test('parses a well-formed bundle', () {
      final bundle = RecoveryKeyBundle.fromJson(validJson());
      expect(bundle.wrappedDekPw, 'pw-blob');
      expect(bundle.kdfParams['profile'], 'argon2id-v1-portable');
    });

    for (final field in [
      'wrapped_dek_pw',
      'wrapped_dek_recovery',
      'salt_enc',
      'salt_rec',
      'salt_auth',
    ]) {
      test('throws RecoveryBundleFormatException when "$field" is missing '
          '(never silently coerces to an empty string)', () {
        final json = validJson()..remove(field);
        expect(
          () => RecoveryKeyBundle.fromJson(json),
          throwsA(isA<RecoveryBundleFormatException>()),
        );
      });

      test('throws RecoveryBundleFormatException when "$field" is an empty '
          'string', () {
        final json = validJson()..[field] = '';
        expect(
          () => RecoveryKeyBundle.fromJson(json),
          throwsA(isA<RecoveryBundleFormatException>()),
        );
      });

      test('throws RecoveryBundleFormatException when "$field" is the wrong '
          'type', () {
        final json = validJson()..[field] = 12345;
        expect(
          () => RecoveryKeyBundle.fromJson(json),
          throwsA(isA<RecoveryBundleFormatException>()),
        );
      });
    }

    test(
      'throws RecoveryBundleFormatException when "kdf_params" is missing',
      () {
        final json = validJson()..remove('kdf_params');
        expect(
          () => RecoveryKeyBundle.fromJson(json),
          throwsA(isA<RecoveryBundleFormatException>()),
        );
      },
    );

    test('throws RecoveryBundleFormatException when "kdf_params" is not a '
        'Map', () {
      final json = validJson()..['kdf_params'] = 'not-a-map';
      expect(
        () => RecoveryKeyBundle.fromJson(json),
        throwsA(isA<RecoveryBundleFormatException>()),
      );
    });
  });
}
