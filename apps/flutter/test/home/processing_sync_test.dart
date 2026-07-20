import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/home/inbox_sync.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

import '../support/item_fixtures.dart';

Recording _remote({
  required String runId,
  required int attempt,
  required ProcessingState state,
  Map<String, dynamic> outputs = const {},
  String uploadState = 'uploaded',
  String? storageKey,
  String? filename,
  String? contentType,
  String? checksumSha256,
  DateTime? uploadedAt,
  DateTime? updatedAt,
}) {
  return Recording.fromItemJson(<String, dynamic>{
    'id': 5,
    'owner_id': 1,
    'client_id': '5',
    'item_type': 'file',
    'title': 'Audio',
    'notes': 'Remote note must not replace local notes',
    'processing_state': state.wireName,
    'processing_run_id': runId,
    'processing_attempt': attempt,
    'processing_requested_outputs': const ['transcript', 'summary'],
    'processing_outputs': outputs,
    'processing_error': state == ProcessingState.failed
        ? const {
            'code': 'processor_unavailable',
            'message': 'Unavailable.',
            'retryable': true,
          }
        : null,
    'updated_at': updatedAt?.toIso8601String(),
    'file': <String, dynamic>{
      'media_type': 'audio',
      'upload_state': uploadState,
      'storage_key': storageKey,
      'filename': filename,
      'original_extension': filename?.split('.').last.toLowerCase(),
      'content_type': contentType,
      'open_policy': contentType == 'application/pdf'
          ? 'external'
          : 'download_only',
      'checksum_sha256': checksumSha256,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'byte_size': 10,
    },
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'new retry run keeps prior output visible and preserves cloud/notes',
    () async {
      final existing = await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        notes: 'Exact local note bytes',
        transcript: 'Prior successful transcript',
        summary: 'Prior successful summary',
        processingState: ProcessingState.failed,
        processingRunId: 'run-old',
        processingAttempt: 1,
      );

      final companions = recordingToItemCompanions(
        _remote(runId: 'run-new', attempt: 2, state: ProcessingState.queued),
        existing: existing,
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );
      final queued = await db.itemsDao.getById('5', '1');

      expect(queued?.item.processingRunId, 'run-new');
      expect(queued?.item.processingAttempt, 2);
      expect(queued?.item.processingState, 'queued');
      expect(queued?.transcript, 'Prior successful transcript');
      expect(queued?.summary, 'Prior successful summary');
      expect(queued?.notes, 'Exact local note bytes');
      expect(queued?.item.syncState, 'synced');
      expect(queued?.file?.uploadState, 'uploaded');
    },
  );

  test(
    'stale prior-run response cannot replace current state or outputs',
    () async {
      final existing = await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        notes: 'User note',
        transcript: 'Current transcript',
        processingState: ProcessingState.processing,
        processingRunId: 'run-current',
        processingAttempt: 2,
      );

      final companions = recordingToItemCompanions(
        _remote(
          runId: 'run-stale',
          attempt: 1,
          state: ProcessingState.succeeded,
          outputs: const {
            'transcript': {'type': 'transcript', 'text': 'Stale transcript'},
          },
        ),
        existing: existing,
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );
      final row = await db.itemsDao.getById('5', '1');

      expect(row?.item.processingRunId, 'run-current');
      expect(row?.item.processingState, 'processing');
      expect(row?.transcript, 'Current transcript');
      expect(row?.notes, 'User note');
    },
  );

  test(
    'current terminal output replaces machine output but never notes',
    () async {
      final existing = await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        notes: 'User note',
        transcript: 'Prior transcript',
        processingState: ProcessingState.processing,
        processingRunId: 'run-current',
        processingAttempt: 2,
      );

      final companions = recordingToItemCompanions(
        _remote(
          runId: 'run-current',
          attempt: 2,
          state: ProcessingState.succeeded,
          outputs: const {
            'transcript': {'type': 'transcript', 'text': 'Fresh transcript'},
            'summary': {'type': 'summary', 'markdown': 'Fresh summary'},
          },
        ),
        existing: existing,
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );
      final row = await db.itemsDao.getById('5', '1');

      expect(row?.transcript, 'Fresh transcript');
      expect(row?.summary, 'Fresh summary');
      expect(row?.notes, 'User note');
      expect(row?.item.syncState, 'synced');
      expect(row?.file?.uploadState, 'uploaded');
    },
  );

  test(
    'failed current run leaves prior successful output and cloud state intact',
    () async {
      final existing = await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        notes: 'User note',
        transcript: 'Prior transcript',
        processingState: ProcessingState.processing,
        processingRunId: 'run-current',
        processingAttempt: 2,
      );

      final companions = recordingToItemCompanions(
        _remote(
          runId: 'run-current',
          attempt: 2,
          state: ProcessingState.failed,
        ),
        existing: existing,
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );
      final row = await db.itemsDao.getById('5', '1');

      expect(row?.item.processingState, 'failed');
      expect(row?.processingErrorCode, 'processor_unavailable');
      expect(row?.transcript, 'Prior transcript');
      expect(row?.notes, 'User note');
      expect(row?.item.syncState, 'synced');
      expect(row?.file?.uploadState, 'uploaded');
    },
  );

  test(
    'partial retry merges new output without hiding prior successful kinds',
    () async {
      final existing = await insertTestFileItem(
        db,
        id: '5',
        coreId: 5,
        notes: 'User note',
        transcript: 'Prior successful transcript',
        summary: 'Prior summary',
        processingState: ProcessingState.processing,
        processingRunId: 'run-new',
        processingAttempt: 2,
      );

      final companions = recordingToItemCompanions(
        _remote(
          runId: 'run-new',
          attempt: 2,
          state: ProcessingState.partial,
          outputs: const {
            'summary': {'type': 'summary', 'markdown': 'Fresh partial summary'},
          },
        ),
        existing: existing,
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );
      final row = await db.itemsDao.getById('5', '1');

      expect(row?.item.processingState, 'partial');
      expect(row?.summary, 'Fresh partial summary');
      expect(row?.transcript, 'Prior successful transcript');
      expect(row?.notes, 'User note');
    },
  );

  test('upload facts come only from explicit Core upload fields', () async {
    final companions = recordingToItemCompanions(
      _remote(
        runId: 'run-failed',
        attempt: 1,
        state: ProcessingState.failed,
        uploadState: 'uploading',
        storageKey: 'allocated-before-upload-completes',
        updatedAt: DateTime.utc(2026, 7, 16, 20),
      ),
    );
    await db.itemsDao.upsertFileItem(
      item: companions.item,
      file: companions.file,
    );

    final row = await db.itemsDao.getById('5', '1');
    expect(row?.file?.storageKey, 'allocated-before-upload-completes');
    expect(row?.file?.uploadState, 'uploading');
    expect(row?.file?.uploadedAt, isNull);
    expect(row?.item.processingState, 'failed');
  });

  test(
    'fresh sync preserves file identity separately from the display title',
    () async {
      final companions = recordingToItemCompanions(
        _remote(
          runId: 'run-document',
          attempt: 1,
          state: ProcessingState.succeeded,
          filename: 'quarterly-report.pdf',
          contentType: 'application/pdf',
          checksumSha256: 'a' * 64,
        ),
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );

      final row = await db.itemsDao.getById('5', '1');
      expect(row?.title, 'Audio');
      expect(row?.file?.filename, 'quarterly-report.pdf');
      expect(row?.file?.contentType, 'application/pdf');
      expect(row?.file?.checksumSha256, 'a' * 64);
      expect(row?.originalExtension, 'pdf');
    },
  );

  test(
    'normalizes untrusted server file metadata before persistence',
    () async {
      final companions = recordingToItemCompanions(
        const Recording(
          id: 5,
          ownerId: '1',
          title: 'Remote file',
          filename: '../unsafe/Report.PDF\r\n',
          originalExtension: '../../EXE',
          contentType: 'APPLICATION/PDF; charset=binary',
          openPolicy: 'made_up_policy',
          byteSize: -50,
        ),
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );

      final row = await db.itemsDao.getById('5', '1');
      expect(row?.file?.filename, 'Report.PDF__');
      expect(row?.file?.originalExtension, 'pdf__');
      expect(row?.file?.contentType, 'application/pdf');
      expect(row?.file?.openPolicy, 'download_only');
      expect(row?.file?.byteSize, 0);
    },
  );
}
