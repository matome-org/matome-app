import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/work_queue_dao.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/vault/media_inputs.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_vault/matome_vault.dart';

const _liveCoreUrl = String.fromEnvironment('LIVE_CORE_URL');
const _password = 'correct horse battery staple';

void main() {
  test(
    'Vault audio uploads plaintext to Core and reaches AI terminal',
    () async {
      final temp = await Directory.systemTemp.createTemp('vault_audio_live_');
      addTearDown(() => temp.delete(recursive: true));
      final source = File('${temp.path}/capture.m4a');
      final generated = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=2:sample_rate=48000',
        '-ac',
        '1',
        '-c:a',
        'aac',
        '-b:a',
        '96k',
        '-f',
        'ipod',
        '-y',
        source.path,
      ]);
      expect(generated.exitCode, 0, reason: generated.stderr as String?);
      final logicalBytes = await source.readAsBytes();

      final tokenStore = InMemoryTokenStore();
      final dio = Dio(BaseOptions(baseUrl: _liveCoreUrl));
      addTearDown(() => dio.close(force: true));
      final apiClient = ApiClient(tokenStore: tokenStore, dio: dio);
      final email =
          'vault-live-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final registration = await apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {'email': email, 'password': _password},
      );
      expect(registration.statusCode, 201);
      final session = AuthSession.fromJson(registration.data!);
      await tokenStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      final createdMatome = await apiClient.dio.post<Map<String, dynamic>>(
        '/api/matomes',
        data: {'title': 'Vault live audio'},
      );
      expect(createdMatome.statusCode, 201);
      final coreMatome = createdMatome.data!['matome'] as Map<String, dynamic>;

      final accountId = VaultAccountId('live-${session.user.id}');
      final keys = _TestKeys(accountId, Uint8List.fromList(List.filled(32, 7)));
      final store = await NativeMediaBlobStore.open(
        applicationSupportRoot: temp.path,
        accountId: accountId,
        keyMaterial: keys,
      );
      addTearDown(store.close);
      final stat = await store.ingest(
        mediaInputFromFile(
          source,
          filename: 'capture.m4a',
          contentType: 'audio/mp4',
        ),
      );
      await source.delete();
      expect(stat.plaintextLength, logicalBytes.length);
      expect(await source.exists(), isFalse);
      final object = (await temp.list(recursive: true).toList())
          .whereType<File>()
          .singleWhere((file) => file.path.endsWith('.mec1'));
      final ciphertext = await object.readAsBytes();
      expect(ciphertext.take(4), mec1Magic);
      expect(ciphertext, isNot(logicalBytes));

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      const itemId = 'live-vault-audio-item';
      const matomeId = 'live-vault-audio-matome';
      const fileId = 'file-live-vault-audio-item';
      final ownerId = session.user.id.toString();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.matomesDao.create(
        MatomesCompanion.insert(
          id: matomeId,
          coreId: Value(coreMatome['id'] as int),
          title: 'Vault live audio',
          happenedAt: now,
          createdAt: now,
        ),
      );
      await db.itemsDao.createFileItem(
        item: ItemsCompanion.insert(
          id: itemId,
          ownerId: ownerId,
          clientId: itemId,
          matomeId: const Value(matomeId),
          itemType: MatomeItemType.file.wireName,
          title: const Value('Vault live audio'),
          processingState: const Value('not_requested'),
          syncState: const Value(kProcessingStatusPendingUpload),
          fileBlobId: const Value(fileId),
          createdAt: now,
          updatedAt: now,
        ),
        file: FileBlobsCompanion.insert(
          id: fileId,
          filename: const Value('capture.m4a'),
          contentType: const Value('audio/mp4'),
          byteSize: Value(stat.plaintextLength!),
          checksumSha256: Value(stat.plaintextSha256),
          mediaType: 'audio',
          duration: const Value(2),
          blobId: Value(stat.id.value),
          blobState: Value(stat.state.name),
          cipherFormat: Value(stat.cipherFormat.name),
          cipherVersion: Value(stat.cipherVersion),
          createdAt: now,
          updatedAt: now,
        ),
        initialWork: fileUploadWork(
          itemId: itemId,
          blobId: stat.id.value,
          blobRevision: 1,
          sourceRevision: 1,
          now: now,
          configRevision: 0,
        ),
      );

      final repository = _FailOnceDeleteRepository(apiClient: apiClient);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaBlobStoreProvider.overrideWithValue(store),
          currentOwnerIdProvider.overrideWithValue(ownerId),
          tokenStoreProvider.overrideWithValue(tokenStore),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          apiClientProvider.overrideWithValue(apiClient),
          recordingsRepositoryProvider.overrideWithValue(repository),
          uploadQueueProvider.overrideWith(
            (ref) => UploadQueue(
              ref,
              configRevision: () => 0,
              jitter: () => 0,
              baseRetryDelay: Duration.zero,
              maxRetryDelay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(uploadQueueProvider).drainRow(itemId);
      final accepted = await db.itemsDao.getById(itemId, ownerId);
      expect(accepted?.file?.uploadState, 'uploaded');
      expect(accepted?.processingState.isInFlight, isTrue);

      final waiter = RecordingResultWaiter(
        recordingId: accepted!.coreId!,
        runId: accepted.item.processingRunId!,
        poll: () => repository.fetchRecording(accepted.coreId!),
        initialPollInterval: const Duration(milliseconds: 100),
        maxPollInterval: const Duration(seconds: 1),
        observationTimeout: const Duration(seconds: 30),
      );
      addTearDown(waiter.cancel);
      final terminal = (await waiter.wait()).recording;
      expect(terminal?.processing.state, ProcessingState.succeeded);
      expect(await source.exists(), isFalse);
      expect((await store.stat(stat.id)).state, VaultBlobState.ready);

      final remoteUrl = await repository.downloadUrl(accepted.coreId!);
      expect(remoteUrl, isNotNull);
      final storageClient = Dio(
        BaseOptions(
          validateStatus: (_) => true,
          responseType: ResponseType.bytes,
        ),
      );
      addTearDown(() => storageClient.close(force: true));
      final remoteBeforeDelete = await storageClient.get<List<int>>(remoteUrl!);
      expect(remoteBeforeDelete.statusCode, 200);
      expect(remoteBeforeDelete.data, logicalBytes);

      await container.read(itemDeletionServiceProvider).delete(itemId, ownerId);
      final retry = await db.workQueueDao.getForItem(
        itemId,
        kWorkKindFileDelete,
      );
      expect(retry?.state, kWorkStateRetry);
      expect(retry?.stage, kWorkStageDeleteRemote);
      expect(
        (await db.itemsDao.getById(itemId, ownerId))?.item.isDeleted,
        isTrue,
      );
      expect((await store.stat(stat.id)).state, VaultBlobState.ready);
      expect(await repository.fetchRecording(accepted.coreId!), isNotNull);

      await container.read(uploadQueueProvider).resumeNow();
      expect(await repository.fetchRecording(accepted.coreId!), isNull);
      expect((await storageClient.get<List<int>>(remoteUrl)).statusCode, 404);
      expect((await store.stat(stat.id)).state, VaultBlobState.missing);
      expect(await db.itemsDao.getById(itemId, ownerId), isNull);
      expect(await db.workQueueDao.listAll(), isEmpty);
      await repository.deleteRecording(accepted.coreId!);
    },
    skip: _liveCoreUrl.isEmpty,
    tags: 'live',
  );
}

final class _FailOnceDeleteRepository extends RecordingsRepository {
  _FailOnceDeleteRepository({required super.apiClient});

  bool _failDelete = true;

  @override
  Future<void> deleteRecording(int id) {
    if (_failDelete) {
      _failDelete = false;
      throw const ApiException(
        'simulated delete transport failure',
        statusCode: 503,
        code: 'server_unavailable',
      );
    }
    return super.deleteRecording(id);
  }
}

final class _TestKeys implements VaultKeyMaterial {
  _TestKeys(this.accountId, this._bytes);
  @override
  final VaultAccountId accountId;
  final Uint8List _bytes;

  @override
  Future<T> use<T>(
    FutureOr<T> Function(Uint8List accountDek) operation,
  ) async => operation(_bytes);

  @override
  Future<void> dispose() async => _bytes.fillRange(0, _bytes.length, 0);
}
