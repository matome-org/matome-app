import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/features/documents/document_open_policy.dart';
import 'package:matome_flutter/features/documents/document_open_service.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore tokenStore;
  late RecordingsRepository repo;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    repo = RecordingsRepository(apiClient: client);
  });

  test(
    'fetchRecordings parses the item list and injects Bearer header',
    () async {
      await tokenStore.saveTokens(accessToken: 'access-123');

      adapter.onGet(
        '/api/items',
        (server) => server.reply(200, {
          'items': [
            {
              'id': 1,
              'owner_id': 1,
              'matome_id': 10,
              'item_type': 'file',
              'title': 'Standup notes',
              'processing_state': 'succeeded',
              'processing_run_id': 'run-1',
              'processing_attempt': 1,
              'processing_requested_outputs': ['summary'],
              'processing_outputs': {
                'summary': {'type': 'summary', 'markdown': 'Summary'},
              },
              'file': {
                'media_type': 'audio',
                'duration': 132,
                'upload_state': 'uploaded',
              },
            },
            {
              'id': 2,
              'owner_id': 1,
              'matome_id': 10,
              'item_type': 'file',
              'title': 'Idea dump',
              'processing_state': 'processing',
              'processing_run_id': 'run-2',
              'processing_attempt': 1,
              'processing_requested_outputs': ['transcript'],
              'processing_outputs': const <String, dynamic>{},
              'file': {'media_type': 'audio', 'upload_state': 'uploaded'},
            },
            {
              'id': 3,
              'owner_id': 1,
              'matome_id': 10,
              'item_type': 'text',
              'text': {'body': 'Not a file recording'},
            },
          ],
        }),
        headers: {'Authorization': 'Bearer access-123'},
      );

      final recordings = await repo.fetchRecordings();

      expect(recordings, hasLength(3));
      expect(recordings[0].title, 'Standup notes');
      expect(recordings[0].status, RecordingStatus.done);
      expect(recordings[1].status, RecordingStatus.processing);
      expect(recordings[2].itemType, 'text');
      expect(recordings[2].textBody, 'Not a file recording');
    },
  );

  test('401 maps to unauthorized ApiException', () async {
    await tokenStore.saveTokens(accessToken: 'expired');
    adapter.onGet(
      '/api/items',
      (server) => server.reply(401, {'error': 'unauthenticated'}),
      headers: {'Authorization': 'Bearer expired'},
    );

    expect(
      () => repo.fetchRecordings(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'isUnauthorized',
          true,
        ),
      ),
    );
  });

  test('empty recordings envelope yields empty list', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onGet(
      '/api/items',
      (server) => server.reply(200, {'items': []}),
      headers: {'Authorization': 'Bearer access-123'},
    );

    expect(await repo.fetchRecordings(), isEmpty);
  });

  test(
    'document descriptor parses policy, action, HTTPS URL, and expiry',
    () async {
      await tokenStore.saveTokens(accessToken: 'access-123');
      adapter.onGet(
        '/api/items/9/download-url',
        (server) => server.reply(200, {
          'download': {
            'method': 'GET',
            'url': 'https://storage.test/report.pdf?signature=secret',
            'expires_at': '2026-07-17T00:05:00Z',
            'open_policy': 'external',
            'action': 'open',
          },
        }),
        headers: {'Authorization': 'Bearer access-123'},
      );

      final descriptor = await repo.documentOpenDescriptor(9);

      expect(descriptor.url.scheme, 'https');
      expect(descriptor.openPolicy, DocumentOpenPolicy.external);
      expect(descriptor.action, DocumentOpenAction.open);
      expect(descriptor.expiresAt, DateTime.utc(2026, 7, 17, 0, 5));
    },
  );

  test('document descriptor requires an explicit GET method', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onGet(
      '/api/items/9/download-url',
      (server) => server.reply(200, {
        'download': {
          'method': 'POST',
          'url': 'https://storage.test/report.pdf?signature=secret',
          'expires_at': '2026-07-17T00:05:00Z',
          'open_policy': 'external',
          'action': 'open',
        },
      }),
      headers: {'Authorization': 'Bearer access-123'},
    );

    await expectLater(
      repo.documentOpenDescriptor(9),
      throwsA(isA<DocumentDescriptorUnavailableException>()),
    );
  });

  for (final failure in const [
    (status: 404, body: <String, dynamic>{'error': 'not_found'}),
    (status: 422, body: <String, dynamic>{'error': 'unsafe_file_type'}),
  ]) {
    test(
      'document descriptor maps permanent ${failure.status} response to unavailable',
      () async {
        adapter.onGet(
          '/api/items/9/download-url',
          (server) => server.reply(failure.status, failure.body),
        );

        await expectLater(
          repo.documentOpenDescriptor(9),
          throwsA(isA<DocumentDescriptorUnavailableException>()),
        );
      },
    );
  }

  test(
    'document descriptor keeps non-policy 422 responses retryable',
    () async {
      adapter.onGet(
        '/api/items/9/download-url',
        (server) => server.reply(422, {'error': 'file_not_uploaded'}),
      );

      await expectLater(
        repo.documentOpenDescriptor(9),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.code, 'code', 'file_not_uploaded'),
        ),
      );
    },
  );

  test('document descriptor keeps 5xx responses retryable', () async {
    adapter.onGet(
      '/api/items/9/download-url',
      (server) => server.reply(503, {'error': 'storage_unavailable'}),
    );

    await expectLater(
      repo.documentOpenDescriptor(9),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('create/process/download/delete use item endpoints', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');

    adapter.onPost(
      '/api/matomes/42/items',
      (server) => server.reply(201, {
        'item': {
          'id': 9,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'title': 'Upload',
          'processing_state': 'not_requested',
          'processing_run_id': null,
          'processing_attempt': 0,
          'processing_requested_outputs': const <String>[],
          'processing_outputs': const <String, dynamic>{},
          'file': {
            'id': 7,
            'media_type': 'audio',
            'byte_size': 12,
            'upload_state': 'pending',
          },
        },
        'upload': {
          'upload_id': 'item-9-upload-1',
          'upload_generation': 1,
          'mode': 'single',
          'state': 'pending',
          'expires_at': '2026-07-15T12:15:00Z',
          'request': {
            'method': 'PUT',
            'url': 'http://storage.test/upload',
            'headers': <String, String>{},
          },
        },
      }),
      data: {
        'client_id': 'rec_local_upload',
        'item_type': 'file',
        'title': 'Upload',
        'filename': 'source.wav',
        'media_type': 'audio',
        'content_type': 'audio/wav',
        'metadata': <String, dynamic>{},
      },
      headers: {'Authorization': 'Bearer access-123'},
    );
    adapter.onPost(
      '/api/items/9/process',
      (server) => server.reply(202, {
        'item': {
          'id': 9,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'title': 'Upload',
          'processing_state': 'queued',
          'processing_run_id': 'run-9',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': const <String, dynamic>{},
          'file': {'id': 7, 'media_type': 'audio', 'upload_state': 'uploaded'},
        },
      }),
      headers: {'Authorization': 'Bearer access-123'},
    );
    adapter.onGet(
      '/api/items/9/download-url',
      (server) => server.reply(200, {
        'download': {'method': 'GET', 'url': 'http://storage.test/download'},
      }),
      headers: {'Authorization': 'Bearer access-123'},
    );
    adapter.onDelete(
      '/api/items/9',
      (server) => server.reply(204, null),
      headers: {'Authorization': 'Bearer access-123'},
    );

    final created = await repo.createItemRecording(
      title: 'Upload',
      matomeId: 42,
      clientId: 'rec_local_upload',
      filename: 'source.wav',
      contentType: 'audio/wav',
    );
    expect(created.recording.id, 9);
    expect(created.upload.url, 'http://storage.test/upload');

    final processing = await repo.enqueueProcessing(9);
    expect(processing.id, 9);

    expect(await repo.downloadUrl(9), 'http://storage.test/download');
    await repo.deleteRecording(9);
  });

  test('text CRUD uses revisioned type-aware endpoints', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    Map<String, dynamic> item(String body, int revision) => {
      'id': 9,
      'owner_id': 'owner-1',
      'client_id': 'text-client',
      'item_type': 'text',
      'title': 'Note',
      'source_revision': revision,
      'processing_state': 'not_requested',
      'processing_attempt': 0,
      'processing_requested_outputs': const <String>[],
      'processing_outputs': const <String, dynamic>{},
      'text': {'body': body},
    };
    adapter.onPost(
      '/api/items/text',
      (server) => server.reply(201, {'item': item('Original', 1)}),
      data: {
        'client_id': 'text-client',
        'body': 'Original',
        'matome_id': 42,
        'title': 'Note',
        'metadata': {'origin': 'typed'},
      },
      headers: {'Authorization': 'Bearer access-123'},
    );
    adapter.onPatch(
      '/api/items/9/text',
      (server) => server.reply(200, {'item': item('Edited', 2)}),
      data: {'body': 'Edited', 'expected_source_revision': 1},
      headers: {'Authorization': 'Bearer access-123'},
    );
    adapter.onDelete(
      '/api/items/9/text',
      (server) => server.reply(404, {'error': 'not_found'}),
      data: {'expected_source_revision': 2},
      headers: {'Authorization': 'Bearer access-123'},
    );

    final created = await repo.createTextItem(
      clientId: 'text-client',
      body: 'Original',
      matomeId: 42,
      title: 'Note',
      metadata: {'origin': 'typed'},
    );
    expect(created.clientId, 'text-client');
    expect(created.sourceRevision, 1);
    final updated = await repo.updateTextItem(
      9,
      body: 'Edited',
      expectedSourceRevision: 1,
    );
    expect(updated.textBody, 'Edited');
    expect(updated.sourceRevision, 2);
    await repo.deleteTextItem(9, expectedSourceRevision: 2);
  });

  test('text update exposes Core current item on version conflict', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onPatch(
      '/api/items/9/text',
      (server) => server.reply(409, {
        'error': 'version_conflict',
        'item': {
          'id': 9,
          'owner_id': 'owner-1',
          'client_id': 'text-client',
          'item_type': 'text',
          'title': 'Remote',
          'source_revision': 3,
          'processing_state': 'not_requested',
          'text': {'body': 'Remote body'},
        },
      }),
      data: {'body': 'Local body', 'expected_source_revision': 2},
      headers: {'Authorization': 'Bearer access-123'},
    );

    await expectLater(
      repo.updateTextItem(9, body: 'Local body', expectedSourceRevision: 2),
      throwsA(
        isA<TextVersionConflict>()
            .having((error) => error.current?.sourceRevision, 'revision', 3)
            .having((error) => error.current?.textBody, 'body', 'Remote body'),
      ),
    );
  });

  test('text create exposes Core item on client_id conflict', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onPost(
      '/api/items/text',
      (server) => server.reply(409, {
        'error': 'client_id_conflict',
        'item': {
          'id': 9,
          'owner_id': 'owner-1',
          'client_id': 'text-client',
          'item_type': 'text',
          'title': 'Remote',
          'source_revision': 2,
          'processing_state': 'not_requested',
          'text': {'body': 'Remote body'},
        },
      }),
      data: {'client_id': 'text-client', 'body': 'Local body'},
      headers: {'Authorization': 'Bearer access-123'},
    );

    await expectLater(
      repo.createTextItem(clientId: 'text-client', body: 'Local body'),
      throwsA(
        isA<TextClientIdConflict>()
            .having((error) => error.current?.id, 'id', 9)
            .having((error) => error.current?.sourceRevision, 'revision', 2),
      ),
    );
  });

  test('text delete exposes Core current item on version conflict', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onDelete(
      '/api/items/9/text',
      (server) => server.reply(409, {
        'error': 'version_conflict',
        'item': {
          'id': 9,
          'owner_id': 'owner-1',
          'client_id': 'text-client',
          'item_type': 'text',
          'title': 'Remote',
          'source_revision': 4,
          'processing_state': 'not_requested',
          'text': {'body': 'Remote body'},
        },
      }),
      data: {'expected_source_revision': 3},
      headers: {'Authorization': 'Bearer access-123'},
    );

    await expectLater(
      repo.deleteTextItem(9, expectedSourceRevision: 3),
      throwsA(
        isA<TextVersionConflict>()
            .having((error) => error.current?.sourceRevision, 'revision', 4)
            .having((error) => error.current?.textBody, 'body', 'Remote body'),
      ),
    );
  });
}
