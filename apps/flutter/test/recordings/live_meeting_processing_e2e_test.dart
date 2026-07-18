import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/work_queue_dao.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:meeting_capture_linux/meeting_capture_linux.dart';

const _liveCoreUrl = String.fromEnvironment('LIVE_CORE_URL');
const _password = 'correct horse battery staple';

void main() {
  test(
    'live meeting: long M4A takes multipart path, reaches terminal processing, '
    'and remains locally decodable',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final temp = await Directory.systemTemp.createTemp('meeting_live_');
        addTearDown(() => temp.delete(recursive: true));
        final audio = File('${temp.path}/long-meeting.m4a');
        final generated = await runBoundedCommand('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'anoisesrc=color=pink:duration=1200:sample_rate=48000',
          '-ac',
          '1',
          '-ar',
          '48000',
          '-c:a',
          'aac',
          '-profile:a',
          'aac_low',
          '-b:a',
          '96k',
          '-f',
          'ipod',
          '-y',
          audio.path,
        ], timeout: const Duration(seconds: 60));
        expect(generated.exitCode, 0, reason: generated.stderr);
        expect(await audio.length(), greaterThan(10 * 1024 * 1024));
        final inspector = const LinuxMeetingArtifactInspector();
        final beforeUpload = await inspector.call(audio.path);
        expect(beforeUpload.decodable, isTrue);

        final tokenStore = InMemoryTokenStore();
        final dio = Dio(
          BaseOptions(
            baseUrl: _liveCoreUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        addTearDown(() => dio.close(force: true));
        final apiClient = ApiClient(tokenStore: tokenStore, dio: dio);
        final email =
            'meeting-live-${DateTime.now().microsecondsSinceEpoch}@example.com';
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
          data: {'title': 'Live meeting processing'},
        );
        expect(createdMatome.statusCode, 201);
        final coreMatome =
            createdMatome.data!['matome'] as Map<String, dynamic>;

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        const localItemId = 'live-meeting-item';
        const localMatomeId = 'live-meeting-matome';
        const fileId = 'file-live-meeting-item';
        final ownerId = session.user.id.toString();
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.matomesDao.create(
          MatomesCompanion.insert(
            id: localMatomeId,
            coreId: Value(coreMatome['id'] as int),
            title: 'Live meeting processing',
            happenedAt: now,
            createdAt: now,
          ),
        );
        await db.itemsDao.createFileItem(
          item: ItemsCompanion.insert(
            id: localItemId,
            ownerId: ownerId,
            clientId: localItemId,
            matomeId: const Value(localMatomeId),
            itemType: MatomeItemType.file.wireName,
            title: const Value('Long meeting'),
            processingState: const Value('not_requested'),
            syncState: const Value(kProcessingStatusPendingUpload),
            fileBlobId: const Value(fileId),
            createdAt: now,
            updatedAt: now,
          ),
          file: FileBlobsCompanion.insert(
            id: fileId,
            filename: const Value('long-meeting.m4a'),
            contentType: const Value('audio/mp4'),
            byteSize: Value(await audio.length()),
            mediaType: 'audio',
            localPath: Value(audio.path),
            duration: Value(beforeUpload.duration.inSeconds),
            createdAt: now,
            updatedAt: now,
          ),
          initialWork: fileUploadWork(
            itemId: localItemId,
            sourceRevision: 1,
            now: now,
            configRevision: 0,
          ),
        );

        final repository = RecordingsRepository(apiClient: apiClient);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentOwnerIdProvider.overrideWithValue(ownerId),
            tokenStoreProvider.overrideWithValue(tokenStore),
            settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
            apiClientProvider.overrideWithValue(apiClient),
            recordingsRepositoryProvider.overrideWithValue(repository),
            uploadQueueProvider.overrideWith(UploadQueue.new),
          ],
        );
        addTearDown(container.dispose);
        await container.read(uploadQueueProvider).drainRow(localItemId);
        final accepted = await db.itemsDao.getById(localItemId, ownerId);
        expect(accepted?.file?.uploadState, 'uploaded');
        expect(accepted?.processingState.isInFlight, isTrue);

        final waiter = RecordingResultWaiter(
          recordingId: accepted!.coreId!,
          runId: accepted.item.processingRunId!,
          poll: () => repository.fetchRecording(accepted.coreId!),
          initialPollInterval: const Duration(milliseconds: 100),
          maxPollInterval: const Duration(milliseconds: 500),
          observationTimeout: const Duration(seconds: 30),
        );
        addTearDown(waiter.cancel);
        final terminal = (await waiter.wait()).recording;
        expect(terminal?.processing.state, ProcessingState.succeeded);
        expect(await audio.exists(), isTrue);
        final afterUpload = await inspector.call(audio.path);
        expect(afterUpload.decodable, isTrue);
        expect(afterUpload.byteSize, beforeUpload.byteSize);
      }, _LiveHttpOverrides());
    },
    skip: _liveCoreUrl.isEmpty,
    tags: 'live',
  );
}

class _LiveHttpOverrides extends HttpOverrides {}
