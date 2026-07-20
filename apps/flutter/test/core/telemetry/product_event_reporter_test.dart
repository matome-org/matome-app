import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/telemetry/product_event_reporter.dart';

class _ThrowingSettingsStore implements SettingsStore {
  @override
  Future<String?> read(String key) =>
      Future.error(StateError('storage unavailable'));

  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore tokenStore;
  late InMemorySettingsStore settings;
  late ProductEventReporter reporter;
  late List<RequestOptions> requests;

  setUp(() async {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    settings = InMemorySettingsStore();
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
    reporter = ProductEventReporter(
      apiClient: ApiClient(tokenStore: tokenStore, dio: dio),
      settingsStore: settings,
    );
    await tokenStore.saveTokens(accessToken: 'access-123');
  });

  test(
    'default opt-out sends no request even when the server catalog is enabled',
    () async {
      expect(
        await reporter.record(ProductEventKey.matomeAdded, localSpace: false),
        ProductEventResult.skippedConsent,
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'opted-in cataloged product event uses the authenticated endpoint',
    () async {
      await reporter.setOptedIn(true);
      adapter.onPost(
        '/api/events',
        (server) => server.reply(201, {'status': 'recorded'}),
        data: Matchers.any,
        headers: {'Authorization': 'Bearer access-123'},
      );

      expect(
        await reporter.record(
          ProductEventKey.matomeArchived,
          localSpace: false,
        ),
        ProductEventResult.recorded,
      );
      expect(requests.single.data, {
        'catalog_key': 'product.matome_archived.v1',
        'opted_in': true,
        'payload': <String, Object?>{},
      });
    },
  );

  test('local-only actions never egress individually', () async {
    await reporter.setOptedIn(true);

    expect(
      await reporter.record(ProductEventKey.matomeRemoved, localSpace: true),
      ProductEventResult.skippedLocalSpace,
    );
    expect(requests, isEmpty);
  });

  test(
    'local Space aggregate may egress only after opt-in with coarse payload',
    () async {
      await reporter.setOptedIn(true);
      adapter.onPost(
        '/api/events',
        (server) => server.reply(201, {'status': 'recorded'}),
        data: Matchers.any,
      );

      expect(
        await reporter.record(
          ProductEventKey.localSpaceAggregate,
          localSpace: true,
          payload: const {
            'period': 'day',
            'item_count_bucket': '1-10',
            'byte_size_bucket': 'small',
            'platform': 'linux',
          },
        ),
        ProductEventResult.recorded,
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'identifier or content-shaped payload is rejected before transport',
    () async {
      await reporter.setOptedIn(true);

      expect(
        await reporter.record(
          ProductEventKey.localSpaceAggregate,
          localSpace: true,
          payload: const {'local_space_id': 'private-space'},
        ),
        ProductEventResult.invalidPayload,
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'settings I/O failure is dropped without breaking product actions',
    () async {
      final unavailable = ProductEventReporter(
        apiClient: ApiClient(tokenStore: tokenStore, dio: dio),
        settingsStore: _ThrowingSettingsStore(),
      );

      expect(
        await unavailable.record(
          ProductEventKey.matomeAdded,
          localSpace: false,
        ),
        ProductEventResult.dropped,
      );
      expect(requests, isEmpty);
    },
  );
}
