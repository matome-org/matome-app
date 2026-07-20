import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/work_queue_dao.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/telemetry/device_queue_reporter.dart';

import '../../support/item_fixtures.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late InMemorySettingsStore settings;
  late List<RequestOptions> requests;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:7001'));
    adapter = DioAdapter(dio: dio);
    settings = InMemorySettingsStore({
      DeviceQueueReporter.sequenceSettingKey: '4',
    });
    requests = [];
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
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Authorization'] = 'Bearer access-123';
          handler.next(options);
        },
      ),
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await db.close();
  });

  test('reports only bounded queue facts and reconciled Core ids', () async {
    await _seedCloudWork(db);
    await _seedLocalSpaceWork(db);
    adapter.onPost(
      '/api/device/queue-snapshot',
      (server) => server.reply(204, null),
      data: Matchers.any,
    );

    final reporter = DeviceQueueReporter(
      database: db,
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
      settingsStore: settings,
      appliedConfigRevision: () => 7,
      reportingInterval: () => const Duration(minutes: 15),
      clock: () => DateTime.fromMillisecondsSinceEpoch(61 * 1000),
    );

    expect(await reporter.report(), DeviceQueueReportResult.reported);
    expect(requests, hasLength(1));

    final body = Map<String, dynamic>.from(requests.single.data as Map);
    expect(body['contract_version'], '1');
    expect(body['sequence'], 5);
    expect(body['applied_config_revision'], 7);

    final snapshot = Map<String, dynamic>.from(body['snapshot'] as Map);
    expect(snapshot['counts'], {'retry': 1});
    expect(snapshot['stages'], {'upload': 1});
    expect(snapshot['errors'], {'transport': 1});
    expect(snapshot['oldest_age_seconds'], 60);
    expect(snapshot['progress'], {'average': 0.5, 'minimum': 0.5});
    expect(snapshot['items'], [
      {
        'core_item_id': 42,
        'state': 'retry',
        'stage': 'upload',
        'media_type': 'audio',
        'age_seconds': 60,
        'progress': 0.5,
        'error_code': 'transport',
      },
    ]);
    expect(snapshot, isNot(contains('local_spaces')));

    final encoded = jsonEncode(body);
    for (final forbidden in [
      'local-cloud-item',
      'local-private-item',
      'ws_private',
      '/home/user/private.wav',
      'Private title',
      'private.wav',
      'lease-owner-secret',
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
  });

  test(
    'local-only Space contributes aggregate metrics only after opt-in',
    () async {
      await _seedLocalSpaceWork(db);
      await settings.write('matome.product_events_opt_in', 'true');
      adapter.onPost(
        '/api/device/queue-snapshot',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );

      final reporter = DeviceQueueReporter(
        database: db,
        apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
        settingsStore: settings,
        appliedConfigRevision: () => 3,
        reportingInterval: () => const Duration(minutes: 15),
        clock: () => DateTime.fromMillisecondsSinceEpoch(61 * 1000),
      );

      await reporter.report();

      final body = Map<String, dynamic>.from(requests.single.data as Map);
      final snapshot = Map<String, dynamic>.from(body['snapshot'] as Map);
      expect(snapshot['counts'], isEmpty);
      expect(snapshot['items'], isEmpty);
      expect(snapshot['local_spaces'], {
        'work_count': 1,
        'oldest_age_seconds': 60,
      });
      expect(jsonEncode(snapshot), isNot(contains('ws_private')));
      expect(jsonEncode(snapshot), isNot(contains('local-private-item')));
    },
  );

  test(
    'throttles best-effort reports without losing monotonic sequence',
    () async {
      await _seedCloudWork(db);
      adapter.onPost(
        '/api/device/queue-snapshot',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );
      final reporter = DeviceQueueReporter(
        database: db,
        apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
        settingsStore: settings,
        appliedConfigRevision: () => 1,
        reportingInterval: () => const Duration(minutes: 15),
        clock: () => DateTime.fromMillisecondsSinceEpoch(61 * 1000),
      );

      expect(await reporter.report(), DeviceQueueReportResult.reported);
      expect(await reporter.report(), DeviceQueueReportResult.throttled);
      expect(requests, hasLength(1));
      expect(await settings.read(DeviceQueueReporter.sequenceSettingKey), '5');
    },
  );
}

Future<void> _seedCloudWork(AppDatabase db) async {
  await insertTestFileItem(
    db,
    id: 'local-cloud-item',
    ownerId: 'owner-1',
    coreId: 42,
    title: 'Private title',
    filename: 'private.wav',
    createdAt: 1000,
  );
  await db.workQueueDao.enqueue(
    ownerId: 'owner-1',
    work: fileUploadWork(
      itemId: 'local-cloud-item',
      blobId: 'blob-local-cloud-item',
      blobRevision: 1,
      sourceRevision: 1,
      now: 1000,
      stage: kWorkStageUpload,
    ),
  );
  await (db.update(
    db.workQueue,
  )..where((row) => row.itemId.equals('local-cloud-item'))).write(
    const WorkQueueCompanion(
      state: Value(kWorkStateRetry),
      progress: Value(0.5),
      errorCode: Value(kWorkErrorTransport),
      leaseOwner: Value('lease-owner-secret'),
    ),
  );
}

Future<void> _seedLocalSpaceWork(AppDatabase db) async {
  await db
      .into(db.workspaces)
      .insert(
        WorkspacesCompanion.insert(
          id: 'ws_private',
          name: 'Private Space',
          createdAt: 1000,
          isLocal: const Value(1),
        ),
      );
  await insertTestFileItem(
    db,
    id: 'local-private-item',
    ownerId: 'owner-1',
    workspaceId: 'ws_private',
    title: 'Local private title',
    filename: 'local-private.wav',
    createdAt: 1000,
  );
  await db.workQueueDao.enqueue(
    ownerId: 'owner-1',
    work: fileUploadWork(
      itemId: 'local-private-item',
      blobId: 'blob-local-private-item',
      blobRevision: 1,
      sourceRevision: 1,
      now: 1000,
      stage: kWorkStageReconcileParent,
    ),
  );
}
