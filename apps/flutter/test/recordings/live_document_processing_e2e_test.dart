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
const _extracted =
    '[FIXTURE] Deterministic stub document text; no extraction was performed.';
const _summary =
    '[FIXTURE] Deterministic document summary; no inference was performed.';

const _fixtures =
    <({String id, String filename, String contentType, String body})>[
      (
        id: 'live-document-pdf',
        filename: 'quarterly-report.pdf',
        contentType: 'application/pdf',
        body: '%PDF-1.7 fixture document bytes',
      ),
      (
        id: 'live-document-text',
        filename: 'meeting-notes.txt',
        contentType: 'text/plain',
        body: 'Fixture plain-text document bytes',
      ),
    ];

void main() {
  testWidgets(
    'live documents: PDF and text fixtures reach typed terminal output and render',
    (tester) async {
      ProviderContainer? container;

      await HttpOverrides.runWithHttpOverrides(
        () => tester.runAsync(() async {
          final temp = await Directory.systemTemp.createTemp(
            'matome_document_live_',
          );
          addTearDown(() => temp.delete(recursive: true));

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
              'document-live-${DateTime.now().microsecondsSinceEpoch}@example.com';
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
            data: {'title': 'Live document processing'},
          );
          expect(createdMatome.statusCode, 201);
          final coreMatome =
              createdMatome.data!['matome'] as Map<String, dynamic>;
          final coreMatomeId = coreMatome['id'] as int;
          final ownerId = session.user.id.toString();

          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          const localMatomeId = 'live-document-matome';
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.matomesDao.create(
            MatomesCompanion.insert(
              id: localMatomeId,
              coreId: Value(coreMatomeId),
              title: 'Live document processing',
              happenedAt: now,
              createdAt: now,
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

          for (final fixture in _fixtures) {
            final file = File('${temp.path}/${fixture.filename}');
            await file.writeAsBytes(utf8.encode(fixture.body));
            expect(contentTypeForPath(file.path), fixture.contentType);
            final fileId = 'file-${fixture.id}';

            await db.itemsDao.createFileItem(
              item: ItemsCompanion.insert(
                id: fixture.id,
                ownerId: ownerId,
                clientId: fixture.id,
                matomeId: const Value(localMatomeId),
                itemType: MatomeItemType.file.wireName,
                title: Value(fixture.filename),
                notes: const Value('User note stays independent.'),
                processingState: const Value('not_requested'),
                syncState: const Value(kProcessingStatusPendingUpload),
                fileBlobId: Value(fileId),
                createdAt: now,
                updatedAt: now,
              ),
              file: FileBlobsCompanion.insert(
                id: fileId,
                filename: Value(fixture.filename),
                contentType: Value(fixture.contentType),
                byteSize: Value(await file.length()),
                mediaType: 'document',
                localPath: Value(file.path),
                createdAt: now,
                updatedAt: now,
              ),
              initialWork: fileUploadWork(
                itemId: fixture.id,
                sourceRevision: 1,
                now: now,
                configRevision: 0,
              ),
            );

            await createdContainer
                .read(uploadQueueProvider)
                .drainRow(fixture.id);
            final accepted = await db.itemsDao.getById(fixture.id, ownerId);
            expect(accepted, isNotNull);
            expect(accepted!.file?.uploadState, 'uploaded');
            expect(accepted.file?.contentType, fixture.contentType);
            expect(accepted.processingState.isInFlight, isTrue);
            expect(
              (jsonDecode(accepted.item.processingRequestedOutputs) as List),
              ['extracted_text', 'summary'],
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
            final Recording? terminal;
            try {
              terminal = (await waiter.wait()).recording;
            } finally {
              waiter.cancel();
            }
            expect(terminal, isNotNull);
            expect(terminal!.processing.state, ProcessingState.succeeded);

            await db.itemsDao.updateItem(
              fixture.id,
              ownerId,
              itemProcessingUpdate(terminal, existing: accepted),
            );
            final ready = await db.itemsDao.getById(fixture.id, ownerId);
            expect(ready!.extractedText, _extracted);
            expect(ready.summary, _summary);
            expect(ready.notes, 'User note stays independent.');
          }
        }),
        _LiveHttpOverrides(),
      );

      final liveContainer = container;
      if (liveContainer == null) return;

      for (final fixture in _fixtures) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: liveContainer,
            child: TranslationProvider(
              child: MaterialApp(
                theme: buildLightTheme(),
                home: FileDetailScreen.documentById(id: fixture.id),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('file-view-contents-ready')),
          findsOneWidget,
        );
        expect(find.textContaining(_extracted), findsOneWidget);
        expect(find.textContaining(_summary), findsOneWidget);
        expect(find.text('User note stays independent.'), findsOneWidget);
      }
    },
    skip: _liveCoreUrl.isEmpty,
  );
}

class _LiveHttpOverrides extends HttpOverrides {}
