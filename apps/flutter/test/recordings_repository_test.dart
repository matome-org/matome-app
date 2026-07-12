import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
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
              'metadata': {'title': 'Standup notes', 'status': 'done'},
              'file': {
                'media_type': 'audio',
                'duration': 132,
                'summary': 'Summary',
              },
            },
            {
              'id': 2,
              'owner_id': 1,
              'matome_id': 10,
              'item_type': 'file',
              'metadata': {'title': 'Idea dump', 'status': 'processing'},
              'file': {'media_type': 'audio'},
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

      expect(recordings, hasLength(2));
      expect(recordings[0].title, 'Standup notes');
      expect(recordings[0].status, RecordingStatus.done);
      expect(recordings[1].status, RecordingStatus.processing);
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
          'metadata': {'title': 'Upload', 'status': 'pending'},
          'file': {'id': 7, 'media_type': 'audio', 'byte_size': 12},
        },
        'presign': {
          'method': 'PUT',
          'url': 'http://storage.test/upload',
          'expires_in': 900,
        },
      }),
      data: Matchers.any,
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
          'metadata': {'title': 'Upload', 'status': 'pending'},
          'file': {'id': 7, 'media_type': 'audio'},
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
    );
    expect(created.recording.id, 9);
    expect(created.upload.url, 'http://storage.test/upload');

    final processing = await repo.enqueueProcessing(9);
    expect(processing.id, 9);

    expect(await repo.downloadUrl(9), 'http://storage.test/download');
    await repo.deleteRecording(9);
  });
}
