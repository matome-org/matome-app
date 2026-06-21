import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart'
    show PickedUpload;
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart'
    show kProcessingStatusPendingUpload;
import 'package:matome_flutter/features/recordings/upload_queue.dart';

/// #1457 — `addFile`/`addPhoto` must KICK the upload queue after the
/// local-first insert.
///
/// The #1451 / #1454 tests proved the queue CAN drain a document row, but they
/// called `UploadQueue.drainRow(id)` DIRECTLY on a mock, so the production
/// trigger was never exercised end-to-end: a doc/photo added via the matome
/// detail affordance inserted a `pending_upload` row and then nothing kicked the
/// queue (audio synced because the recorder path drains inline; addFile matched
/// no `UploadRetryService` trigger), leaving it "Saved on device · waiting to
/// upload" until app restart.
///
/// These tests drive the REAL `addFile` / `addPhoto` controller path (NOT a
/// direct `drainRow` call) against a fake [UploadQueue] that records which row
/// ids the queue was asked to drain, asserting the queue is kicked exactly once
/// for the new row — for BOTH a document and a photo — and that a THROWING drain
/// does not break the import nor revert the local-first insert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  /// A container whose [uploadQueueProvider] is the supplied recording fake, so
  /// the REAL `addFile` path kicks THIS queue. The durable copy is stubbed to
  /// identity to keep the test off-disk and deterministic.
  ProviderContainer containerWith(_RecordingUploadQueue queue) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        uploadQueueProvider.overrideWithValue(queue),
        matomeDetailControllerProvider.overrideWith(
          (ref, id) => MatomeDetailController(
            ref,
            id,
            durableCopy: (PickedUpload p) async => p,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(matomeDetailControllerProvider('ignored'), (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  Future<void> seedMatome(String id) => db.matomesDao.create(
        MatomesCompanion(
          id: Value(id),
          title: const Value('Standup'),
          happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
          createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        ),
      );

  File tempFile(String name, {int bytes = 8}) {
    final f = File(
      '${Directory.systemTemp.path}/addfilekick_'
      '${DateTime.now().microsecondsSinceEpoch}_$name',
    )..writeAsBytesSync(List<int>.filled(bytes, 0));
    addTearDown(() {
      if (f.existsSync()) f.deleteSync();
    });
    return f;
  }

  /// The local id of the single recording row the controller inserted for
  /// [matomeId] — the row the queue should have been kicked for.
  Future<String> insertedRowId(String matomeId) async {
    final matome = await db.matomesDao.getMatomeWithRecordings(matomeId);
    return matome!.recordings.single.id;
  }

  test('addFile (document) kicks the upload queue exactly once for the new row',
      () async {
    await seedMatome('m_doc');
    final queue = _RecordingUploadQueue();
    final c = containerWith(queue);
    final controller = c.read(matomeDetailControllerProvider('m_doc').notifier);
    await controller.load();

    // REAL addFile path — NOT a direct drainRow call.
    await controller.addFile(file: tempFile('report.pdf'), name: 'report.pdf');
    // The kick is fire-and-forget (unawaited); let the microtask/Future run.
    await queue.settle();

    final rowId = await insertedRowId('m_doc');
    expect(queue.drainedRows, [rowId],
        reason: 'the queue must be kicked exactly once, for the new doc row');
  });

  test('addPhoto (image) kicks the upload queue exactly once for the new row',
      () async {
    await seedMatome('m_photo');
    final queue = _RecordingUploadQueue();
    final c = containerWith(queue);
    final controller =
        c.read(matomeDetailControllerProvider('m_photo').notifier);
    await controller.load();

    // addPhoto delegates to addFile — drive the labelled entry point.
    await controller.addPhoto(file: tempFile('pic.jpg'), name: 'pic.jpg');
    await queue.settle();

    final rowId = await insertedRowId('m_photo');
    expect(queue.drainedRows, [rowId],
        reason: 'addPhoto must kick the queue once, for the new photo row');
  });

  test(
      'a THROWING drain does not escape addFile and the row persists as '
      'pending_upload (local-first insert is not reverted)', () async {
    await seedMatome('m_throws');
    final queue = _RecordingUploadQueue(throwOnDrain: true);
    final c = containerWith(queue);
    final controller =
        c.read(matomeDetailControllerProvider('m_throws').notifier);
    await controller.load();

    // addFile must COMPLETE normally even though the drain throws.
    await controller.addFile(file: tempFile('a.pdf'), name: 'a.pdf');
    await queue.settle();

    // The kick was still attempted for the row...
    expect(queue.drainAttempts, 1,
        reason: 'the queue is still kicked even when the drain will throw');

    // ...and the local-first insert survived: the row is present and stayed
    // pending_upload so a later trigger retries it.
    final matome = await db.matomesDao.getMatomeWithRecordings('m_throws');
    final item = matome!.recordings.single;
    final row = await db.recordingsDao.getRecordingById(item.id);
    expect(row!.processingStatus, kProcessingStatusPendingUpload,
        reason: 'a failed kick must not revert the insert; row stays pending');
    expect(row.coreId, isNull);
  });
}

/// A fake [UploadQueue] that RECORDS the row ids it was asked to drain (instead
/// of performing any Core/network work), so a test driving the real `addFile`
/// path can assert the production trigger fired. Optionally throws from
/// `drainRow` to exercise the best-effort/non-blocking contract.
class _RecordingUploadQueue extends UploadQueue {
  _RecordingUploadQueue({this.throwOnDrain = false})
      : super(_NullRef());

  final bool throwOnDrain;

  /// Row ids the queue was asked to drain, in order.
  final List<String> drainedRows = <String>[];

  /// Total drain attempts (incremented even when the call throws).
  int drainAttempts = 0;

  @override
  Future<void> drainRow(String localId) async {
    drainAttempts++;
    if (throwOnDrain) {
      throw StateError('simulated drain failure (offline / Core 401)');
    }
    drainedRows.add(localId);
  }

  /// Flush the fire-and-forget drain the controller schedules (it wraps the
  /// kick in a `Future(...)` then `unawaited`s it). A couple of event-loop
  /// turns let that Future and its `catchError` run before assertions.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}

/// A no-op [Ref] for the fake queue — the fake never reads any provider, so the
/// Ref is never exercised. Only the typed slot is needed to satisfy `super`.
class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'the fake UploadQueue must not touch its Ref',
      );
}
