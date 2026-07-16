import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/crypto/key_material.dart' show Dek;
import 'package:matome_flutter/core/crypto/media_cipher.dart'
    show encryptFileToFile;
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
  Future<Dek> Function()? mediaDekSource,
  Future<Directory> Function()? playbackScratchDirSource,
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
          mediaDekSource: mediaDekSource,
          playbackScratchDirSource:
              playbackScratchDirSource ?? () async => Directory.systemTemp,
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
    'loads canonical file Item and resolves its durable local path',
    () async {
      final dir = await Directory.systemTemp.createTemp('details_item_');
      addTearDown(() => dir.delete(recursive: true));
      final media = File('${dir.path}/capture.m4a')..writeAsBytesSync([1, 2]);
      await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        localPath: media.path,
        notes: 'Personal note',
        transcript: 'Machine transcript',
      );

      final controller = _controller(container, '5');
      await controller.load();

      expect(controller.state.notFound, isFalse);
      expect(controller.state.initialText, 'Personal note');
      expect(controller.state.row?.transcript, 'Machine transcript');
      expect(controller.state.audioSource.kind, AudioSourceKind.localFile);
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
            error: const {
              'code': 'processor_unavailable',
              'retryable': true,
            },
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
              'summary': {
                'type': 'summary',
                'markdown': 'Fresh summary',
              },
              'transcript': {
                'type': 'transcript',
                'text': 'Fresh transcript',
              },
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

  test('delete removes the payload row and durable media', () async {
    final dir = await Directory.systemTemp.createTemp('details_delete_');
    addTearDown(() => dir.delete(recursive: true));
    final media = File('${dir.path}/capture.m4a')..writeAsBytesSync([1]);
    await insertTestFileItem(db, id: '5', coreId: 5, localPath: media.path);
    final controller = _controller(container, '5');
    await controller.load();

    await controller.delete();

    expect(media.existsSync(), isFalse);
    expect(await db.itemsDao.getById('5', '1'), isNull);
  });

  test('a different owner cannot load the Item by id', () async {
    await insertTestFileItem(db, id: '5', ownerId: '2');
    final controller = _controller(container, '5');
    await controller.load();
    expect(controller.state.notFound, isTrue);
  });

  test('encrypted Item resolves plaintext and evicts it on dispose', () async {
    final dir = await Directory.systemTemp.createTemp('details_encrypted_');
    addTearDown(() => dir.delete(recursive: true));
    final dek = Dek.generate();
    final plaintext = Uint8List.fromList(List.generate(512, (i) => i & 0xff));
    final encrypted = File('${dir.path}/capture.enc');
    final encryptedResult = await encryptFileToFile(
      source: File('${dir.path}/capture.raw')..writeAsBytesSync(plaintext),
      destination: encrypted,
      dek: dek,
    );
    await insertTestFileItem(
      db,
      id: 'encrypted',
      localPath: encrypted.path,
      wrappedFek: encryptedResult.wrappedFek.toBase64(),
    );

    final scratch = Directory('${dir.path}/scratch');
    container.dispose();
    container = _container(
      db,
      mediaDekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
      playbackScratchDirSource: () async => scratch,
    );
    final subscription = container.listen(
      detailsControllerProvider('encrypted'),
      (_, _) {},
    );
    final controller = container.read(
      detailsControllerProvider('encrypted').notifier,
    );
    await controller.load();

    final resolved = File(controller.state.audioSource.value!);
    expect(resolved.path, isNot(encrypted.path));
    expect(resolved.readAsBytesSync(), plaintext);

    subscription.close();
    await Future<void>.delayed(Duration.zero);
    expect(resolved.existsSync(), isFalse);
  });

  test('encrypted Item decrypt failure settles with no scratch file', () async {
    final dir = await Directory.systemTemp.createTemp('details_bad_key_');
    addTearDown(() => dir.delete(recursive: true));
    final dek = Dek.generate();
    final encrypted = File('${dir.path}/capture.enc');
    final encryptedResult = await encryptFileToFile(
      source: File('${dir.path}/capture.raw')..writeAsBytesSync([1, 2, 3]),
      destination: encrypted,
      dek: dek,
    );
    await insertTestFileItem(
      db,
      id: 'bad-key',
      localPath: encrypted.path,
      wrappedFek: encryptedResult.wrappedFek.toBase64(),
    );

    final scratch = Directory('${dir.path}/scratch');
    final wrongDek = Dek.generate();
    container.dispose();
    container = _container(
      db,
      mediaDekSource: () async => Dek(Uint8List.fromList(wrongDek.bytes)),
      playbackScratchDirSource: () async => scratch,
    );
    final controller = _controller(container, 'bad-key');
    await controller.load();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.notFound, isFalse);
    expect(controller.state.audioSource.kind, AudioSourceKind.none);
    expect(File('${scratch.path}/bad-key.playback').existsSync(), isFalse);
  });

  test('delete evicts encrypted playback scratch and payload', () async {
    final dir = await Directory.systemTemp.createTemp('details_delete_enc_');
    addTearDown(() => dir.delete(recursive: true));
    final dek = Dek.generate();
    final encrypted = File('${dir.path}/capture.enc');
    final encryptedResult = await encryptFileToFile(
      source: File('${dir.path}/capture.raw')..writeAsBytesSync([1, 2, 3]),
      destination: encrypted,
      dek: dek,
    );
    await insertTestFileItem(
      db,
      id: 'delete-encrypted',
      localPath: encrypted.path,
      wrappedFek: encryptedResult.wrappedFek.toBase64(),
    );

    final scratch = Directory('${dir.path}/scratch');
    container.dispose();
    container = _container(
      db,
      mediaDekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
      playbackScratchDirSource: () async => scratch,
    );
    final controller = _controller(container, 'delete-encrypted');
    await controller.load();
    final resolved = File(controller.state.audioSource.value!);
    expect(resolved.existsSync(), isTrue);

    await controller.delete();

    expect(resolved.existsSync(), isFalse);
    expect(encrypted.existsSync(), isFalse);
    expect(await db.itemsDao.getById('delete-encrypted', '1'), isNull);
  });
}
