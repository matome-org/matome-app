import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_status_socket.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore tokenStore;
  late RecordingsRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: tokenStore, dio: dio),
    );
  });

  group('createRecording', () {
    test('parses recording + presign descriptor from 201', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onPost(
        '/api/recordings',
        (server) => server.reply(201, {
          'recording': {
            'id': 6,
            'owner_id': 1,
            'title': 'F4 test',
            'status': 'pending',
            'storage_key': 'owners/1/recordings/6/media',
          },
          'upload': {
            'method': 'PUT',
            'url': 'http://127.0.0.1:54321/storage/v1/s3/media/x?sig=1',
            'storage_key': 'owners/1/recordings/6/media',
            'expires_in': 900,
          },
        }),
        data: {
          'title': 'F4 test',
          'status': 'pending',
          'media_type': 'audio',
          'duration': 3,
          'badge': 'test',
        },
      );

      final result = await repo.createRecording(
        title: 'F4 test',
        durationSeconds: 3,
        badge: 'test',
      );

      expect(result.recording.id, 6);
      expect(result.recording.status, RecordingStatus.pending);
      expect(result.upload.method, 'PUT');
      expect(result.upload.isPost, isFalse);
      expect(result.upload.url, contains('storage/v1/s3'));
      expect(result.upload.expiresIn, 900);
    });
  });

  group('enqueueProcessing', () {
    test('accepts 202 and returns the echoed recording', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onPost(
        '/api/recordings/6/process',
        (server) => server.reply(202, {
          'recording': {
            'id': 6,
            'owner_id': 1,
            'title': 'F4 test',
            'status': 'pending',
          },
          'processing': {'queued': true},
        }),
      );

      final rec = await repo.enqueueProcessing(6);
      expect(rec.id, 6);
    });
  });

  group('fetchRecording (poll source)', () {
    test('returns the recording on 200', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onGet(
        '/api/recordings/6',
        (server) => server.reply(200, {
          'recording': {
            'id': 6,
            'owner_id': 1,
            'title': 'F4 test',
            'status': 'done',
            'summary': 'done',
          },
        }),
      );
      final rec = await repo.fetchRecording(6);
      expect(rec!.status, RecordingStatus.done);
    });

    test('returns null on 404 (transient miss)', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onGet(
        '/api/recordings/99',
        (server) => server.reply(404, {'error': 'not_found'}),
      );
      expect(await repo.fetchRecording(99), isNull);
    });
  });

  group('buildSocketEndpoint', () {
    test('http base -> ws /socket/websocket', () {
      final uri = buildSocketEndpoint('http://localhost:4000');
      expect(uri.scheme, 'ws');
      expect(uri.host, 'localhost');
      expect(uri.port, 4000);
      expect(uri.path, '/socket/websocket');
      expect(uri.query, isEmpty);
    });

    test('https base -> wss /socket/websocket', () {
      final uri = buildSocketEndpoint('https://api.matome.app');
      expect(uri.scheme, 'wss');
      expect(uri.host, 'api.matome.app');
      expect(uri.path, '/socket/websocket');
    });

    test('strips any existing query/path on the base', () {
      final uri = buildSocketEndpoint('http://10.0.2.2:4000/foo?x=1');
      expect(uri.scheme, 'ws');
      expect(uri.path, '/socket/websocket');
      expect(uri.query, isEmpty);
    });
  });
}
