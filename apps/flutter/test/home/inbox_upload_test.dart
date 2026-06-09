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
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';

void main() {
  test('mediaTypeForPath buckets audio / image / document', () {
    expect(mediaTypeForPath('/a/b.m4a'), 'audio');
    expect(mediaTypeForPath('/a/b.PNG'), 'image');
    expect(mediaTypeForPath('/a/b.pdf'), 'document');
  });

  test('upload creates a Core recording, inserts a local row, then resolves done',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A small temp file to upload.
    final tmp = File('${Directory.systemTemp.path}/inbox_upload_test.m4a');
    await tmp.writeAsBytes(List<int>.filled(16, 0));
    addTearDown(() => tmp.exists().then((e) => e ? tmp.delete() : null));

    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);

    // 1. create -> id 321 + presign to a stub URL.
    adapter.onPost(
      '/api/recordings',
      (server) => server.reply(201, {
        'recording': {
          'id': 321,
          'owner_id': 1,
          'title': 'Voice memo',
          'status': 'pending',
        },
        'upload': {
          'method': 'PUT',
          'url': 'http://127.0.0.1:9/upload',
          'storage_key': 'k',
          'expires_in': 900,
        },
      }),
      data: Matchers.any,
    );
    // 3. enqueue process -> 202.
    adapter.onPost(
      '/api/recordings/321/process',
      (server) => server.reply(202, {
        'recording': {
          'id': 321,
          'owner_id': 1,
          'title': 'Voice memo',
          'status': 'processing',
        },
        'processing': {'queued': true},
      }),
    );
    // 4. poll -> done.
    adapter.onGet(
      '/api/recordings/321',
      (server) => server.reply(200, {
        'recording': {
          'id': 321,
          'owner_id': 1,
          'title': 'Voice memo',
          'status': 'done',
          'summary': 'A short memo',
          'transcript': 'hello world',
        },
      }),
    );

    // The presigned PUT goes through a *separate* bare Dio in the repo. Point a
    // top-level handler at the stub host so the stream-upload "succeeds".
    final repo = _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final uploader = container.read(inboxUploaderProvider);

    final localId = await uploader.upload(PickedUpload(
      file: tmp,
      title: 'Voice memo',
      mediaType: 'audio',
    ));

    expect(localId, '321'); // Core int 321 -> local TEXT '321'

    // Pipeline drove create -> (local row) -> upload -> process -> done.
    final row = await db.recordingsDao.getRecordingById('321');
    expect(row, isNotNull);
    expect(row!.processingStatus, 'done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'A short memo');

    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.single.id, '321');
    expect(items.single.card.isProcessing, isFalse);
  });
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll flow without a real S3.
class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {}
}
