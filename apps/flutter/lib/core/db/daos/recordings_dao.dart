import 'package:drift/drift.dart';

import '../../../features/matome/matome_ids.dart';
import '../../../features/recordings/recording_ids.dart'
    show kProcessingStatusPendingUpload;
import '../app_database.dart';
import '../file_row.dart';
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
@DriftAccessor(
  tables: [Recordings, Workspaces, Matomes, MatomeContacts, Contacts],
)
class RecordingsDao extends DatabaseAccessor<AppDatabase>
    with _$RecordingsDaoMixin {
  RecordingsDao(super.db);

  // ---------------------------------------------------------------------------
  // Files view — owner-scoped, cross-matome + Unfiled (#1461)
  // ---------------------------------------------------------------------------

  /// Every file (audio|image|document Item) the [ownerId] user owns, ACROSS all
  /// matomes AND loose/Unfiled (`matome_id IS NULL`) rows, newest first — the
  /// data source for the Files view (DR-003 / #1461).
  ///
  /// SECURITY (A01 — Broken Access Control, the hard AC): the owner predicate is
  /// `recordings.owner_id == ownerId` applied DIRECTLY ON THE ROW — NOT via a
  /// JOIN to matome/workspace (which is NULL for an Unfiled / Inbox row and would
  /// either drop it or LEAK another owner's orphan). A NULL `owner_id` (legacy
  /// un-backfilled row) never equals a concrete [ownerId], so it is excluded —
  /// it can never surface for any owner. This mirrors Core's server-enforced
  /// `MatomeApi.Content.list_recordings` (`owner_id == ^owner_id`); the column is
  /// populated on Core reconcile from the recording JSON's `owner_id`.
  ///
  /// The matome title (Unfiled when null) and Space name (Inbox when null) are
  /// resolved by LEFT joins; per-file contacts are the file's MATOME's tagged
  /// contacts (matome-mediated — schema gap flagged at #1461: there is no
  /// per-file contact edge, so an Unfiled file has no contacts).
  Future<List<FileRow>> filesForOwner(String ownerId) async {
    // (1) The owner-scoped rows, with matome + space names via LEFT joins. The
    // owner predicate is on `recordings.owner_id` itself so Unfiled/Inbox rows
    // (NULL matome/workspace) stay scoped.
    final query = select(recordings).join([
      leftOuterJoin(matomes, matomes.id.equalsExp(recordings.matomeId)),
      leftOuterJoin(
        workspaces,
        workspaces.id.equalsExp(recordings.workspaceId),
      ),
    ])
      ..where(recordings.ownerId.equals(ownerId))
      ..orderBy([OrderingTerm.desc(recordings.createdAt)]);

    final rows = await query.get();
    if (rows.isEmpty) return const [];

    // (2) Contacts per matome (matome-mediated — schema gap). One join over
    // `matome_contacts` → `contacts` for the matome ids present on this page.
    final matomeIds = rows
        .map((r) => r.readTableOrNull(matomes)?.id)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final contactsByMatome = <String, List<String>>{};
    if (matomeIds.isNotEmpty) {
      final contactQuery = select(matomeContacts).join([
        innerJoin(contacts, contacts.id.equalsExp(matomeContacts.contactId)),
      ])
        ..where(matomeContacts.matomeId.isIn(matomeIds))
        ..orderBy([OrderingTerm.asc(contacts.displayName)]);
      for (final row in await contactQuery.get()) {
        final mid = row.readTable(matomeContacts).matomeId;
        final name = row.readTable(contacts).displayName;
        (contactsByMatome[mid] ??= <String>[]).add(name);
      }
    }

    return rows.map((row) {
      final recording = row.readTable(recordings);
      final matome = row.readTableOrNull(matomes);
      final space = row.readTableOrNull(workspaces);
      return FileRow.fromRow(
        recording,
        matomeTitle: matome?.title,
        spaceName: space?.name,
        contacts: matome == null
            ? const <String>[]
            : (contactsByMatome[matome.id] ?? const <String>[]),
      );
    }).toList(growable: false);
  }

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

  /// All recordings that are Items of [matomeId], newest first. The child set
  /// the space-scoped sync (task #1377) pushes once their parent Matome has a
  /// Core id (child-before-parent ordering).
  Future<List<RecordingRow>> recordingsForMatome(String matomeId) {
    return (select(recordings)
          ..where((r) => r.matomeId.equals(matomeId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
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
      // Caller already supplied a Matome — respect it verbatim. The owning
      // Matome's item set / a child summary changed, so its aggregated summary
      // is now stale (ADR-0003 invalidation): a new Item was added or an
      // existing one's summary was reconciled in.
      if (entry.matomeId.present && entry.matomeId.value != null) {
        await into(recordings).insertOnConflictUpdate(entry);
        await _markMatomeSummaryStale(entry.matomeId.value!);
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
        await _markMatomeSummaryStale(existing.matomeId!);
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

  /// Flags the owning Matome's aggregated summary as pending regeneration —
  /// its item set / a child summary changed (ADR-0003 invalidation). Mirrors
  /// [MatomesDao.markSummaryStale]; written inline so it joins the caller's
  /// transaction (the `Matomes` table is in this accessor).
  Future<void> _markMatomeSummaryStale(String matomeId) async {
    await (update(matomes)..where((m) => m.id.equals(matomeId)))
        .write(const MatomesCompanion(summaryStale: Value(true)));
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
