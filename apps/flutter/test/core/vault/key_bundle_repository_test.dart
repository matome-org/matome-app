import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/vault/key_bundle_repository.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late KeyBundleRepository repository;
  final owner = VaultAccountId('opaque_owner');

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    repository = KeyBundleRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );
  });

  test('GET 404 means enrollment is required', () async {
    adapter.onGet(
      '/api/keybundle',
      (server) => server.reply(404, {'error': 'not_found'}),
    );

    expect(await repository.fetch(owner), isNull);
  });

  test(
    'missing envelope in a successful response is rejected at the boundary',
    () async {
      adapter.onGet(
        '/api/keybundle',
        (server) => server.reply(200, {
          'key_bundle': {
            'wrapped_dek_recovery': 'recovery',
            'salt_enc': 'enc',
            'salt_rec': 'rec',
            'salt_auth': 'auth',
            'kdf_params': <String, dynamic>{},
          },
        }),
      );

      await expectLater(
        repository.fetch(owner),
        throwsA(isA<KeyBundleFormatException>()),
      );
    },
  );

  test(
    'PUT sends only the Core keybundle contract and binds response to owner',
    () async {
      const json = {
        'wrapped_dek_pw': 'pw',
        'wrapped_dek_recovery': 'recovery',
        'salt_enc': 'enc',
        'salt_rec': 'rec',
        'salt_auth': 'auth',
        'kdf_params': <String, dynamic>{'profile': 'test'},
      };
      adapter.onPut(
        '/api/keybundle',
        (server) => server.reply(200, {'key_bundle': json}),
        data: json,
      );

      final result = await repository.put(
        AccountKeyBundle.fromJson(owner, json),
      );

      expect(result.accountId, owner);
      expect(result.toJson(), json);
    },
  );
}
