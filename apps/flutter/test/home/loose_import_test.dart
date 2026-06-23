import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

/// Local-first-spaces #102 W2 — imports land LOOSE behind the flag, the
/// flag-off path is byte-for-byte unchanged, and the existing synced (upload)
/// path is NOT broken (ADR-0006 §1/§3, spec sync-gate-and-promotion).
///
/// `FeatureFlags.localFirstSpaces` is a compile-time `const bool.fromEnvironment`,
/// so this file is run TWICE by the `flutter-design-system-check` gate — once
/// forced OFF and once forced ON via `--dart-define=ff.localFirstSpaces=…`.
/// Each lane group self-skips under the wrong build so each invocation proves
/// exactly its reality.
const _flagOn = bool.fromEnvironment(
  'ff.localFirstSpaces',
  defaultValue: false,
);

/// A no-op terminal-result awaiter that drives the real queue pipeline via the
/// poll fallback (no live Phoenix socket).
Future<RecordingResult> _pollFallbackAwaiter({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
}) async {
  final events = StreamController<RecordingStatusEvent>();
  final waiter = RecordingResultWaiter(
    recordingId: recording.id,
    statusEvents: events.stream,
    poll: poll,
    pollInterval: const Duration(milliseconds: 20),
  );
  final result = await waiter.wait();
  await events.close();
  return result;
}

void main() {
  group('lane: ff.localFirstSpaces=true (ON / loose import)', () {
    test(
      'import lands LOOSE — matome NULL + workspace NULL → in the Inbox '
      '(effective space NULL via the resolver), no Matome minted',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final tmp = File('${Directory.systemTemp.path}/loose_import_on.m4a');
        await tmp.writeAsBytes(List<int>.filled(16, 0));
        addTearDown(() => tmp.exists().then((e) => e ? tmp.delete() : null));

        // Core unreachable → the row stays pending_upload + loose; the assertion
        // sees the locally-persisted membership (no Core reconcile reshapes it).
        final repo = _CoreDownRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
          ),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingsRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        final localId = await container.read(inboxUploaderProvider).upload(
              PickedUpload(file: tmp, title: 'Imported', mediaType: 'audio'),
            );

        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row, isNotNull);
        // LOOSE: no matome, no space. Its effective space is therefore NULL ⇒
        // Inbox (INBOX ⟺ effectiveSpace == NULL, spec R1.3).
        expect(row!.matomeId, isNull,
            reason: 'flag ON: import must NOT mint a matome (loose)');
        expect(row.workspaceId, isNull,
            reason: 'flag ON: import is loose, no space filed');

        // No Matome row was created at all (the m007 forced-mint is repealed).
        final matomes = await db.matomesDao.listMatomes();
        expect(matomes, isEmpty,
            reason: 'a loose import mints NO Matome');

        // Surfaces in the Inbox view (workspaceId IS NULL).
        final items = container.read(inboxControllerProvider).requireValue;
        expect(items.single.id, localId);
      },
      skip: _flagOn ? false : 'ON-only lane',
    );

    test(
      'regression: an existing recording already in a CLOUD space still '
      'uploads — the synced path is NOT broken by the loose-import change',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final tmp = File('${Directory.systemTemp.path}/cloud_synced_on.m4a');
        await tmp.writeAsBytes(List<int>.filled(16, 0));
        addTearDown(() => tmp.exists().then((e) => e ? tmp.delete() : null));

        final dio = Dio(BaseOptions(
          baseUrl: 'http://localhost:4000',
          validateStatus: (s) => s != null && s < 500,
        ));
        final adapter = DioAdapter(dio: dio);
        adapter.onPost(
          '/api/recordings',
          (server) => server.reply(201, {
            'recording': {
              'id': 555,
              'owner_id': 1,
              'title': 'Filed memo',
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
        adapter.onPost(
          '/api/recordings/555/process',
          (server) => server.reply(202, {
            'recording': {
              'id': 555,
              'owner_id': 1,
              'title': 'Filed memo',
              'status': 'processing',
            },
            'processing': {'queued': true},
          }),
        );
        adapter.onGet(
          '/api/recordings/555',
          (server) => server.reply(200, {
            'recording': {
              'id': 555,
              'owner_id': 1,
              'title': 'Filed memo',
              'status': 'done',
              'summary': 'Filed + synced',
            },
          }),
        );

        final repo = _StubUploadRepository(
          apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingsRepositoryProvider.overrideWithValue(repo),
          // The W4 gate's [Caller] reads this; override so the drain never
          // builds the real auth chain (secure-storage platform channels).
          currentOwnerIdProvider.overrideWithValue('owner-1'),
          uploadQueueProvider.overrideWith(
            (ref) => UploadQueue(
              ref,
              awaitResult: _pollFallbackAwaiter,
              cleanupAudio: (_) async {},
            ),
          ),
        ]);
        addTearDown(container.dispose);

        // The CLOUD space the recording is filed into (`is_local = 0`) — a real
        // `workspaces` row so the W4 data-egress gate can resolve it to a CLOUD
        // SpaceRef and ALLOW the drain. (The gate fails-closed on an unknown
        // space id, so the synced-path regression needs the space to exist.)
        await db.into(db.workspaces).insert(WorkspacesCompanion.insert(
              id: '7',
              name: 'Cloud space',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              isLocal: const Value(0),
            ));

        // A recording ALREADY filed into a cloud space (workspaceId set to a
        // numeric Core space id), pending_upload — the synced reality the W4
        // gate consults via the resolver. The upload queue drains it ONLY
        // because the effective space resolves to CLOUD; the loose-import change
        // must not stop the synced path.
        const localId = 'rec_local_cloud_filed';
        await db.recordingsDao.insertRecording(
          RecordingsCompanion(
            id: const Value(localId),
            coreId: const Value(null),
            title: const Value('Filed memo'),
            timestamp: const Value('12:00'),
            duration: const Value('5s'),
            isProcessing: const Value(1),
            audioFilePath: Value(tmp.path),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            workspaceId: const Value('7'), // a CLOUD space (numeric Core id)
            mediaType: const Value('audio'),
            processingStatus: const Value('pending_upload'),
          ),
        );

        await container.read(uploadQueueProvider).drainRow(localId);

        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row, isNotNull);
        // The synced path drove: create → reconcile coreId → upload → done.
        expect(row!.coreId, 555,
            reason: 'cloud-filed recording must still create on Core');
        expect(row.processingStatus, 'done',
            reason: 'synced path not broken by the loose-import change');
        // It stayed filed in its cloud space the whole time.
        expect(row.workspaceId, '7');
      },
      skip: _flagOn ? false : 'ON-only lane',
    );
  });

  group('lane: ff.localFirstSpaces=false (OFF / shipped reality)', () {
    test(
      'import is UNCHANGED — a fresh Matome is minted (m007/ADR-0003 forced '
      'invariant), the recording is an Item of it',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final tmp = File('${Directory.systemTemp.path}/loose_import_off.m4a');
        await tmp.writeAsBytes(List<int>.filled(16, 0));
        addTearDown(() => tmp.exists().then((e) => e ? tmp.delete() : null));

        final repo = _CoreDownRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
          ),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingsRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        final localId = await container.read(inboxUploaderProvider).upload(
              PickedUpload(file: tmp, title: 'Imported', mediaType: 'audio'),
            );

        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row, isNotNull);
        // OFF: the forced-mint invariant holds — a Matome was minted and the
        // recording points at it.
        expect(row!.matomeId, isNotNull,
            reason: 'flag OFF: import still mints a Matome (unchanged)');
        // Inbox upload → Inbox Matome: the minted matome has no space.
        expect(row.workspaceId, isNull);

        final matomes = await db.matomesDao.listMatomes();
        expect(matomes, hasLength(1),
            reason: 'flag OFF mints exactly one Matome per import');
        expect(matomes.single.id, row.matomeId);
      },
      skip: _flagOn ? 'OFF-only lane' : false,
    );
  });
}

/// Repo whose Core create throws — Core unreachable, so the local-first
/// persistence (membership) can be asserted independent of any Core reconcile.
class _CoreDownRepository extends RecordingsRepository {
  _CoreDownRepository({required super.apiClient});

  @override
  Future<RecordingCreateResult> createRecording({
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
  }) async {
    throw StateError('Core unreachable (test)');
  }
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll drain without a real S3.
class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    // No-op: the stub host is unreachable; the drain still drives create →
    // reconcile → process → poll → done.
  }
}
