import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/config/endpoint_controller.dart';
import 'package:matome_flutter/core/config/system_policy.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';

Map<String, dynamic> config({int revision = 7}) => <String, dynamic>{
  'schema_version': 1,
  'revision': revision,
  'desired': <String, dynamic>{
    'queue': <String, dynamic>{
      'paused': false,
      'lease_seconds': 120,
      'max_concurrency': 2,
      'snapshot_interval_seconds': 900,
    },
    'retry': <String, dynamic>{
      'max_attempts': 5,
      'base_delay_seconds': 2,
      'max_delay_seconds': 300,
    },
    'uploads': <String, dynamic>{
      'single_max_bytes': 26214400,
      'multipart_part_bytes': 16777216,
      'max_bytes': 2147483648,
    },
    'ai': <String, dynamic>{
      'enabled_input_kinds': <String>['audio', 'image', 'document', 'text'],
      'job_timeout_seconds': 1800,
    },
    'clients': <String, dynamic>{
      'minimum_wire_version': '1',
      'poll_interval_seconds': 2,
    },
  },
  'applied': <String, dynamic>{
    'core_revision': revision,
    'core_applied_at': '2026-07-15T12:00:00Z',
  },
};

void main() {
  test('strict parser rejects unknown keys and unsafe cross-field bounds', () {
    final policy = SystemPolicy.parse(config());
    expect(policy.revision, 7);
    expect(policy.leaseDuration, const Duration(seconds: 120));
    expect(policy.enabledInputKinds, <String>{
      'audio',
      'image',
      'document',
      'text',
    });

    final unknown = config();
    (unknown['desired']['queue'] as Map<String, dynamic>)['endpoint'] =
        'https://secret.test';
    expect(
      () => SystemPolicy.parse(unknown),
      throwsA(
        isA<SystemPolicyValidationException>().having(
          (error) => error.rejectedKeys,
          'rejectedKeys',
          contains('desired.queue.endpoint'),
        ),
      ),
    );

    final invalid = config();
    (invalid['desired']['retry']
            as Map<String, dynamic>)['base_delay_seconds'] =
        301;
    expect(
      () => SystemPolicy.parse(invalid),
      throwsA(
        isA<SystemPolicyValidationException>().having(
          (error) => error.rejectedKeys,
          'rejectedKeys',
          contains('desired.retry.base_delay_seconds'),
        ),
      ),
    );
  });

  test(
    'online refresh persists and reports only a validated monotonic revision',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://localhost:7001',
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final adapter = DioAdapter(dio: dio);
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.next(options);
          },
        ),
      );
      final tokens = InMemoryTokenStore();
      await tokens.saveTokens(accessToken: 'access-123');
      final store = InMemorySettingsStore();
      final controller = SystemPolicyController(
        ApiClient(tokenStore: tokens, dio: dio),
        store,
      );

      adapter.onGet(
        '/api/system-config',
        (server) => server.reply(200, <String, dynamic>{
          'contract_version': '1',
          'config': config(),
        }),
      );
      adapter.onPost(
        '/api/system-config/application',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );

      expect(await controller.refresh(), isTrue);
      expect(controller.state.revision, 7);
      expect(
        jsonDecode((await store.read(systemPolicyCacheKey))!)['revision'],
        7,
      );
      expect(requests.last.data, <String, dynamic>{
        'contract_version': '1',
        'applied_revision': 7,
        'rejected_keys': <String>[],
      });
      expect(requests.last.headers['Authorization'], 'Bearer access-123');
    },
  );

  test(
    'invalid or offline refresh keeps the last accepted cached policy',
    () async {
      final cached = config(revision: 6);
      final store = InMemorySettingsStore(<String, String>{
        systemPolicyCacheKey: jsonEncode(cached),
      });
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://localhost:7001',
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final adapter = DioAdapter(dio: dio);
      final controller = SystemPolicyController(
        ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
        store,
      );

      await controller.hydrate();
      expect(controller.state.revision, 6);

      final invalid = config(revision: 7);
      (invalid['desired']['uploads'] as Map<String, dynamic>)['max_bytes'] = -1;
      adapter.onGet(
        '/api/system-config',
        (server) => server.reply(200, <String, dynamic>{
          'contract_version': '1',
          'config': invalid,
        }),
      );
      adapter.onPost(
        '/api/system-config/application',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );

      expect(await controller.refresh(), isFalse);
      expect(controller.state.revision, 6);
      expect(
        jsonDecode((await store.read(systemPolicyCacheKey))!)['revision'],
        6,
      );

      adapter.close(force: true);
      expect(await controller.refresh(), isFalse);
      expect(controller.state.revision, 6);
    },
  );

  test(
    'runtime endpoint changes preserve the accepted offline policy',
    () async {
      final settings = InMemorySettingsStore(<String, String>{
        systemPolicyCacheKey: jsonEncode(config(revision: 6)),
      });
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(settings),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      addTearDown(container.dispose);

      final before = container.read(systemPolicyProvider.notifier);
      await before.hydrate();
      expect(container.read(systemPolicyProvider).revision, 6);

      await container
          .read(endpointConfigProvider.notifier)
          .setBaseUrl('http://127.0.0.1:7999');

      expect(container.read(systemPolicyProvider.notifier), same(before));
      expect(container.read(systemPolicyProvider).revision, 6);
    },
  );
}
