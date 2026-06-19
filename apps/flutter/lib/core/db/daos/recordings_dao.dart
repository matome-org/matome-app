import 'package:drift/drift.dart';

import '../../../features/matome/matome_ids.dart';
import '../../../features/recordings/recording_ids.dart'
    show kProcessingStatusPendingUpload;
import '../app_database.dart';
import '../recording_card.dart';
import '../tables.dart';

part 'recordings_dao.g.dart';

/// One recording joined with its (optional) workspace name — the result shape
/// of [RecordingsDao.recordingsByDayWithWorkspace], mirroring the mobile
/// `RecordingWithWorkspaceName` / `getRecordingsByDayWithWorkspace`.
class RecordingWithWorkspace {
  const RecordingWithWorkspace(this.recording, this.workspaceName);

  final RecordingRow recording;
  final String? workspaceName;
}

const int _kMsPerDay = 24 * 60 * 60 * 1000;

/// CRUD + query DAO for `recordings`, porting recordingService.ts.
///
/// Pure-Dart surface: no HTTP. The sync layer (Wave 3) decides when to pull
/// from Core and writes through [upsertRecording].
@DriftAccessor(tables: [Recordings, Workspaces, Matomes])
class RecordingsDao extends DatabaseAccessor<AppDatabase>
    with _$RecordingsDaoMixin {
  RecordingsDao(super.db);

  /// All recordings, newest first.
  Future<List<RecordingRow>> getAllRecordings() {
    return (select(
      recordings,
    )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();
  }

  /// Inbox recordings — `workspaceId IS NULL`, newest first.
  Future<List<RecordingRow>> getInboxRecordings() {
    return (select(recordings)
          ..where((r) => r.workspaceId.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  /// All recordings in a workspace, newest first.
  Future<List<RecordingRow>> getRecordingsInWorkspace(String workspaceId) {
    return (select(recordings)
          ..where((r) => r.workspaceId.equals(workspaceId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  Future<RecordingRow?> getRecordingById(String id) {
    return (select(
      recordings,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Local row whose reconciled Core id is [coreId], or null if none has been
  /// reconciled yet. Used by the Wave 3 socket/poll reconcile path, which is
  /// keyed on the Core numeric id and must map it back to the local UUID PK
  /// (rows minted with `rec_local_<uuid>` keep `coreId` NULL until upload
  /// succeeds, so those are intentionally not matched here).
  Future<RecordingRow?> recordingByCoreId(int coreId) {
    return (select(
      recordings,
    )..where((r) => r.coreId.equals(coreId))).getSingleOrNull();
  }

  /// Rows still awaiting a confirmed Core upload — `processingStatus` is the
  /// local-only `pending_upload` state (plan #43, W4). These are exactly the
  /// rows the auto-retry queue drains: a local-first finish/upload persisted
  /// them but the Core create→upload→reconcile handoff has not yet completed
  /// (Core was unreachable, or the attempt is still in flight on a fresh boot).
  /// Newest first so a backlog drains most-recent-first.
  Future<List<RecordingRow>> getPendingUploadRecordings() {
    return (select(recordings)
          ..where(
            (r) => r.processingStatus.equals(kProcessingStatusPendingUpload),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  /// Insert a new recording. New recordings start in the Inbox
  /// (workspaceId NULL), matching `createRecording`.
  Future<void> insertRecording(RecordingsCompanion entry) {
    return into(recordings).insert(entry);
  }

  /// Insert-or-replace (upsert) by primary key — used by the Core reconcile
  /// path (mobile `upsertCachedRecording`).
  Future<void> upsertRecording(RecordingsCompanion entry) {
    return into(recordings).insertOnConflictUpdate(entry);
  }

  /// Local-first upsert that GUARANTEES the recording is an Item of a Matome
  /// (ADR-0003 invariant 1/4 — a recording is never persisted without a Matome,
  /// created in the SAME transaction so the FK never sees an orphan window).
  ///
  /// If [entry] already carries a `matome_id`, it is upserted unchanged (the
  /// caller owns the Matome). Otherwise — and when no row with this PK already
  /// has a Matome — a fresh local Matome (`mat_local_<uuid>`, `core_id` NULL) is
  /// minted FIRST, its `space_id` taken from the recording's `workspaceId` (so
  /// an Inbox upload → an Inbox Matome) and `happened_at`/`createdAt` from the
  /// recording's `createdAt`, then the recording is upserted pointing at it.
  ///
  /// Re-upserting an existing row (the W3 Core reconcile re-running over a
  /// local-first row) does NOT mint a second Matome: the existing row's
  /// `matome_id` is reused. Runs in a single transaction.
  Future<void> upsertRecordingWithMatome(RecordingsCompanion entry) {
    return transaction(() async {
      // Caller already supplied a Matome — respect it verbatim.
      if (entry.matomeId.present && entry.matomeId.value != null) {
        await into(recordings).insertOnConflictUpdate(entry);
        return;
      }

      // Reuse an existing row's Matome if this PK already has one (idempotent
      // re-upsert / reconcile), so a refresh never duplicates the Matome.
      final id = entry.id.value;
      final existing = await (select(
        recordings,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (existing?.matomeId != null) {
        await into(recordings).insertOnConflictUpdate(
          entry.copyWith(matomeId: Value(existing!.matomeId)),
        );
        return;
      }

      // Mint a fresh local Matome FIRST (FK target exists before the recording
      // references it), mirroring the m007 backfill: space_id = workspaceId,
      // happened_at/created_at = the recording's createdAt.
      final matomeId = mintLocalMatomeId();
      final happenedAt =
          entry.createdAt.present ? entry.createdAt.value : 0;
      final spaceId = entry.workspaceId.present
          ? entry.workspaceId.value
          : null;
      final title = entry.title.present ? entry.title.value : 'Untitled';
      await into(matomes).insert(
        MatomesCompanion.insert(
          id: matomeId,
          spaceId: Value(spaceId),
          title: title,
          happenedAt: happenedAt,
          createdAt: happenedAt,
        ),
      );
      await into(recordings).insertOnConflictUpdate(
        entry.copyWith(matomeId: Value(matomeId)),
      );
    });
  }

  /// Partial update. Only the provided companion fields are written, mirroring
  /// the field-by-field UPDATE in `updateRecording`.
  Future<int> updateRecording(String id, RecordingsCompanion patch) {
    return (update(recordings)..where((r) => r.id.equals(id))).write(patch);
  }

  Future<int> deleteRecording(String id) {
    return (delete(recordings)..where((r) => r.id.equals(id))).go();
  }

  /// Recordings whose `createdAt` falls in [startEpoch, endEpoch] inclusive,
  /// newest first. Ports `getRecordingsByDateRange`.
  Future<List<RecordingRow>> recordingsByDateRange(
    int startEpoch,
    int endEpoch,
  ) {
    return (select(recordings)
          ..where((r) => r.createdAt.isBetweenValues(startEpoch, endEpoch))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  /// Recordings for a single calendar day (start-of-day epoch → +24h-1ms),
  /// newest first. Ports `getRecordingsByDay`.
  Future<List<RecordingRow>> recordingsByDay(int dayEpoch) {
    return recordingsByDateRange(dayEpoch, dayEpoch + _kMsPerDay - 1);
  }

  /// Recordings for a single calendar day LEFT JOINed with workspaces so the
  /// workspace name is available for display. Ports
  /// `getRecordingsByDayWithWorkspace`.
  Future<List<RecordingWithWorkspace>> recordingsByDayWithWorkspace(
    int dayEpoch,
  ) async {
    final dayStart = dayEpoch;
    final dayEnd = dayEpoch + _kMsPerDay - 1;

    final query =
        select(recordings).join([
            leftOuterJoin(
              workspaces,
              workspaces.id.equalsExp(recordings.workspaceId),
            ),
          ])
          ..where(recordings.createdAt.isBetweenValues(dayStart, dayEnd))
          ..orderBy([OrderingTerm.desc(recordings.createdAt)]);

    final rows = await query.get();
    return rows
        .map(
          (row) => RecordingWithWorkspace(
            row.readTable(recordings),
            row.readTableOrNull(workspaces)?.name,
          ),
        )
        .toList(growable: false);
  }

  /// Convenience: load a day's recordings already mapped to UI cards.
  Future<List<RecordingItem>> cardsByDay(int dayEpoch) async {
    final rows = await recordingsByDayWithWorkspace(dayEpoch);
    return rows
        .map(
          (r) => RecordingItem.fromRow(
            r.recording,
            workspaceName: r.workspaceName,
          ),
        )
        .toList(growable: false);
  }
}
