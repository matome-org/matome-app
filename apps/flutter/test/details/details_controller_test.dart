import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/details/details_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart'
    show RecordingResultAwaiter, liveRecordingResultAwaiter;
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

import '../support/item_fixtures.dart';

RecordingResultAwaiter _awaiterReturning(RecordingResult result) =>
    ({required recording, required poll, required ref}) async => result;

Recording _processedItem(
  ProcessingState state, {
  Map<String, dynamic> outputs = const {},
  Map<String, dynamic>? error,
}) {
  return Recording.fromItemJson(<String, dynamic>{
    'id': 5,
    'owner_id': 1,
    'client_id': '5',
    'item_type': 'file',
    'title': 'File',
    'processing_state': state.wireName,
    'processing_run_id': '00000000-0000-4000-8000-000000000005',
    'processing_attempt': 1,
    'processing_requested_outputs': const ['transcript', 'summary'],
    'processing_outputs': outputs,
    'processing_error': error,
    'file': const <String, dynamic>{'media_type': 'audio'},
  });
}

ProviderContainer _container(
  AppDatabase db, {
  RecordingResultAwaiter? awaitResult,
  void Function(Map<String, dynamic>)? onPatch,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:7001'));
  if (onPatch != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PATCH' && options.path == '/api/items/5') {
            onPatch(options.data as Map<String, dynamic>);
          }
          handler.next(options);
        },
      ),
    );
  }
  DioAdapter(dio: dio)
    ..onPatch(
      '/api/items/5',
      (server) => server.reply(200, {
        'item': {
          'id': 5,
          'owner_id': 1,
          'metadata': <String, dynamic>{},
          'file': <String, dynamic>{},
        },
      }),
      data: Matchers.any,
    )
    ..onDelete('/api/items/5', (server) => server.reply(204, null))
    ..onGet(
      '/api/items/5/download-url',
      (server) => server.reply(404, {'error': 'not found'}),
    )
    ..onPost(
      '/api/items/5/process',
      (server) => server.reply(202, {
        'item': {
          'id': 5,
          'owner_id': 1,
          'item_type': 'file',
          'title': 'File',
          'processing_state': 'queued',
          'processing_run_id': '00000000-0000-4000-8000-000000000005',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': <String, dynamic>{},
          'processing_error': null,
          'file': <String, dynamic>{'media_type': 'audio'},
        },
        'processing': {'queued': true},
      }),
    );
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentOwnerIdProvider.overrideWithValue('1'),
      recordingsRepositoryProvider.overrideWithValue(
        RecordingsRepository(
          apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
        ),
      ),
      detailsControllerProvider.overrideWith(
        (ref, id) => DetailsController(
          ref,
          id,
          awaitResult: awaitResult ?? liveRecordingResultAwaiter,
        ),
      ),
    ],
  );
}

DetailsController _controller(ProviderContainer container, String id) {
  final subscription = container.listen(
    detailsControllerProvider(id),
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container.read(detailsControllerProvider(id).notifier);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = _container(db);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'loads canonical file Item through an opaque Vault playback source',
    () async {
      await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        notes: 'Personal note',
        transcript: 'Machine transcript',
      );

      final controller = _controller(container, '5');
      await controller.load();

      expect(controller.state.notFound, isFalse);
      expect(controller.state.initialText, 'Personal note');
      expect(controller.state.row?.transcript, 'Machine transcript');
      expect(controller.state.audioSource.kind, AudioSourceKind.vaultBlob);
      expect(controller.state.audioSource.value, 'fixture-blob');
    },
  );

  test('save changes notes without replacing machine outputs', () async {
    await insertTestFileItem(
      db,
      id: '5',
      coreId: 5,
      notes: 'Old note',
      transcript: 'Machine transcript',
    );
    Map<String, dynamic>? patchBody;
    container.dispose();
    container = _container(db, onPatch: (body) => patchBody = body);
    final controller = _controller(container, '5');
    await controller.load();

    await controller.save('Edited note');

    final row = await db.itemsDao.getById('5', '1');
    expect(row?.notes, 'Edited note');
    expect(row?.transcript, 'Machine transcript');
    expect(patchBody?['notes'], 'Edited note');
    expect(patchBody?.containsKey('transcript'), isFalse);
  });

  test('failed retry preserves prior successful machine outputs', () async {
    await insertTestFileItem(
      db,
      id: '5',
      coreId: 5,
      summary: 'Good summary',
      transcript: 'Good transcript',
      processingStatus: 'failed',
    );
    container.dispose();
    container = _container(
      db,
      awaitResult: _awaiterReturning(
        RecordingResult.terminal(
          _processedItem(
            ProcessingState.failed,
            error: const {'code': 'processor_unavailable', 'retryable': true},
          ),
        ),
      ),
    );
    final controller = _controller(container, '5');
    await controller.load();

    await controller.retry();

    final row = await db.itemsDao.getById('5', '1');
    expect(row?.summary, 'Good summary');
    expect(row?.transcript, 'Good transcript');
    expect(row?.processingStatus, 'failed');
    expect(row?.processingErrorCode, 'processor_unavailable');
  });

  test('retry applies non-empty terminal machine outputs', () async {
    await insertTestFileItem(
      db,
      id: '5',
      coreId: 5,
      notes: 'User note',
      summary: 'Old summary',
      transcript: 'Old transcript',
      processingStatus: 'failed',
    );
    container.dispose();
    container = _container(
      db,
      awaitResult: _awaiterReturning(
        RecordingResult.terminal(
          _processedItem(
            ProcessingState.succeeded,
            outputs: const {
              'summary': {'type': 'summary', 'markdown': 'Fresh summary'},
              'transcript': {'type': 'transcript', 'text': 'Fresh transcript'},
            },
          ),
        ),
      ),
    );
    final controller = _controller(container, '5');
    await controller.load();

    await controller.retry();

    final row = await db.itemsDao.getById('5', '1');
    expect(row?.summary, 'Fresh summary');
    expect(row?.transcript, 'Fresh transcript');
    expect(row?.notes, 'User note');
    expect(row?.processingStatus, 'succeeded');
  });

  test('observational timeout preserves queued Core state and notes', () async {
    await insertTestFileItem(
      db,
      id: '5',
      coreId: 5,
      notes: 'User note',
      processingStatus: 'failed',
    );
    container.dispose();
    container = _container(
      db,
      awaitResult: _awaiterReturning(
        const RecordingResult.observationTimedOut(),
      ),
    );
    final controller = _controller(container, '5');
    await controller.load();

    await controller.retry();

    final row = await db.itemsDao.getById('5', '1');
    expect(row?.notes, 'User note');
    expect(row?.processingStatus, 'queued');
    expect(row?.processingErrorCode, isNull);
  });

  test(
    'delete creates a hidden durable tombstone without touching external files',
    () async {
      final dir = await Directory.systemTemp.createTemp('details_delete_');
      addTearDown(() => dir.delete(recursive: true));
      final media = File('${dir.path}/capture.m4a')..writeAsBytesSync([1]);
      await insertTestFileItem(db, id: '5', coreId: 5);
      final controller = _controller(container, '5');
      await controller.load();

      await controller.delete();

      expect(media.existsSync(), isTrue);
      final tombstone = await db.itemsDao.getByIdIncludingDeleted('5', '1');
      expect(tombstone?.item.isDeleted, isTrue);
      expect(tombstone?.item.syncState, 'pending_delete');
      expect(
        (await db.workQueueDao.getForItem('5', 'file_delete'))?.state,
        anyOf('queued', 'retry', 'blocked'),
      );
    },
  );

  test('a different owner cannot load the Item by id', () async {
    await insertTestFileItem(db, id: '5', ownerId: '2');
    final controller = _controller(container, '5');
    await controller.load();
    expect(controller.state.notFound, isTrue);
  });
}
