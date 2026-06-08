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
    dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    final client = ApiClient(tokenStore: tokenStore, dio: dio);
    repo = RecordingsRepository(apiClient: client);
  });

  test('fetchRecordings parses the list and injects Bearer header', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');

    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(200, {
        'recordings': [
          {
            'id': 1,
            'owner_id': 1,
            'title': 'Standup notes',
            'status': 'done',
            'badge': 'work',
            'duration': 132,
          },
          {
            'id': 2,
            'owner_id': 1,
            'title': 'Idea dump',
            'status': 'processing',
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
  });

  test('401 maps to unauthorized ApiException', () async {
    await tokenStore.saveTokens(accessToken: 'expired');
    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(401, {'error': 'unauthenticated'}),
      headers: {'Authorization': 'Bearer expired'},
    );

    expect(
      () => repo.fetchRecordings(),
      throwsA(isA<ApiException>()
          .having((e) => e.isUnauthorized, 'isUnauthorized', true)),
    );
  });

  test('empty recordings envelope yields empty list', () async {
    await tokenStore.saveTokens(accessToken: 'access-123');
    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(200, {'recordings': []}),
      headers: {'Authorization': 'Bearer access-123'},
    );

    expect(await repo.fetchRecordings(), isEmpty);
  });
}
