import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/telemetry/product_event_reporter.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';

void main() {
  test(
    'cloud add, remove, and archive report stable consent-gated keys',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://localhost:7001',
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final adapter = DioAdapter(dio: dio);
      final tokenStore = InMemoryTokenStore();
      await tokenStore.saveTokens(accessToken: 'access-123');
      final reported = <String>[];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/events') {
              reported.add((options.data as Map)['catalog_key'] as String);
            }
            handler.next(options);
          },
        ),
      );

      adapter
        ..onPost(
          '/api/matomes',
          (server) => server.reply(201, {
            'matome': {'id': 7, 'owner_id': 1, 'title': 'Cloud'},
          }),
          data: Matchers.any,
        )
        ..onPost(
          '/api/matomes/7/archive',
          (server) => server.reply(200, {
            'matome': {
              'id': 7,
              'owner_id': 1,
              'title': 'Cloud',
              'archived_at': '2026-07-15T10:00:00Z',
            },
          }),
        )
        ..onDelete('/api/matomes/7', (server) => server.reply(204, null))
        ..onPost(
          '/api/events',
          (server) => server.reply(201, {'status': 'recorded'}),
          data: Matchers.any,
        );

      final client = ApiClient(tokenStore: tokenStore, dio: dio);
      final repository = MatomesRepository(
        apiClient: client,
        productEvents: ProductEventReporter(
          apiClient: client,
          settingsStore: InMemorySettingsStore({
            ProductEventReporter.optInSettingKey: 'true',
          }),
        ),
      );

      await repository.createMatome(title: 'Cloud');
      await repository.archiveMatome(7);
      await repository.deleteMatome(7);

      expect(reported, [
        'product.matome_added.v1',
        'product.matome_archived.v1',
        'product.matome_removed.v1',
      ]);
    },
  );
}
