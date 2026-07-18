import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/work_queue_dao.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/home/inbox_sync.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

const _liveCoreUrl = String.fromEnvironment('LIVE_CORE_URL');
const _password = 'correct horse battery staple';
const _description =
    '[FIXTURE] Deterministic stub image description; no inference was performed.';
const _ocr =
    '[FIXTURE] Deterministic stub OCR text; no extraction was performed.';
const _summary =
    '[FIXTURE] Deterministic image summary; no inference was performed.';

void main() {
  testWidgets(
    'live image: Drift queue uploads to Core and MinIO, ai-stub callback persists '
    'typed outputs, and routed Flutter detail renders them',
    (tester) async {
      const localItemId = 'live-image-item';
      ProviderContainer? container;

      await HttpOverrides.runWithHttpOverrides(
        () => tester.runAsync(() async {
          final temp = await Directory.systemTemp.createTemp(
            'matome_image_live_',
          );
          addTearDown(() => temp.delete(recursive: true));
          final image = File('${temp.path}/launch-board.png');
          await image.writeAsBytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          );

          final tokenStore = InMemoryTokenStore();
          final dio = Dio(
            BaseOptions(
              baseUrl: _liveCoreUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          addTearDown(() => dio.close(force: true));
          final apiClient = ApiClient(tokenStore: tokenStore, dio: dio);

          final email =
              'image-live-${DateTime.now().microsecondsSinceEpoch}@example.com';
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
            data: {'title': 'Live image processing'},
          );
          expect(createdMatome.statusCode, 201);
          final coreMatome =
              createdMatome.data!['matome'] as Map<String, dynamic>;
          final coreMatomeId = coreMatome['id'] as int;
          final ownerId = session.user.id.toString();

          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          const localMatomeId = 'live-image-matome';
          const fileId = 'file-live-image-item';
          final now = DateTime.now().millisecondsSinceEpoch;

          await db.matomesDao.create(
            MatomesCompanion.insert(
              id: localMatomeId,
              coreId: Value(coreMatomeId),
              title: 'Live image processing',
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
              title: const Value('Launch board'),
              notes: const Value('User note stays independent.'),
              processingState: const Value('not_requested'),
              syncState: const Value(kProcessingStatusPendingUpload),
              fileBlobId: const Value(fileId),
              createdAt: now,
              updatedAt: now,
            ),
            file: FileBlobsCompanion.insert(
              id: fileId,
              filename: const Value('launch-board.png'),
              contentType: Value(contentTypeForPath(image.path)),
              byteSize: Value(await image.length()),
              mediaType: 'image',
              localPath: Value(image.path),
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
          final createdContainer = ProviderContainer(
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
          container = createdContainer;
          addTearDown(createdContainer.dispose);

          await createdContainer
              .read(uploadQueueProvider)
              .drainRow(localItemId);
          final accepted = await db.itemsDao.getById(localItemId, ownerId);
          expect(accepted, isNotNull);
          expect(accepted!.file?.uploadState, 'uploaded');
          expect(accepted.file?.contentType, 'image/png');
          expect(accepted.processingState.isInFlight, isTrue);
          expect(
            (jsonDecode(accepted.item.processingRequestedOutputs) as List)
                .toSet(),
            containsAll(<String>{'ocr_text', 'description', 'summary'}),
          );

          final coreId = accepted.coreId!;
          final runId = accepted.item.processingRunId!;
          final waiter = RecordingResultWaiter(
            recordingId: coreId,
            runId: runId,
            poll: () => repository.fetchRecording(coreId),
            initialPollInterval: const Duration(milliseconds: 100),
            maxPollInterval: const Duration(milliseconds: 500),
            observationTimeout: const Duration(seconds: 20),
          );
          addTearDown(waiter.cancel);
          final terminal = (await waiter.wait()).recording;
          expect(terminal, isNotNull);
          expect(terminal!.processing.state, ProcessingState.succeeded);

          await db.itemsDao.updateItem(
            localItemId,
            ownerId,
            itemProcessingUpdate(terminal, existing: accepted),
          );
          final ready = await db.itemsDao.getById(localItemId, ownerId);
          expect(ready!.description, _description);
          expect(ready.ocrText, _ocr);
          expect(ready.summary, _summary);
          expect(ready.notes, 'User note stays independent.');
        }),
        _LiveHttpOverrides(),
      );

      final liveContainer = container;
      if (liveContainer == null) return;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: liveContainer,
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildLightTheme(),
              home: const FileDetailScreen.imageById(id: localItemId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('file-view-contents-ready')),
        findsOneWidget,
      );
      expect(find.textContaining(_description), findsOneWidget);
      expect(find.textContaining(_ocr), findsOneWidget);
      expect(find.textContaining(_summary), findsOneWidget);
      expect(find.text('User note stays independent.'), findsOneWidget);
      final preview = find.byKey(const ValueKey('file-detail-image-header'));
      expect(preview, findsOneWidget);

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('file-detail-fullscreen-viewer')),
        findsOneWidget,
      );
    },
    skip: _liveCoreUrl.isEmpty,
  );
}

class _LiveHttpOverrides extends HttpOverrides {}
