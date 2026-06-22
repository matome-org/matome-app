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
  tables: [
    Recordings,
    Workspaces,
    Matomes,
    MatomeContacts,
    Contacts,
    RecordingContacts,
  ],
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
  /// resolved by LEFT joins; per-file contacts are the UNION (#1472, DR-003) of
  /// the file's DIRECT contacts (`recording_contacts` — the source of truth, and
  /// the ONLY source for an Unfiled file) and its MATOME's tagged contacts
  /// (matome-mediated, #1461), de-duplicated by name so a contact linked both
  /// ways shows once. An Unfiled file with a direct link now shows that person.
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

    // (3) DIRECT per-file contacts (`recording_contacts`, #1472 — the source of
    // truth). One join over `recording_contacts` → `contacts` for the recording
    // ids on this page. Unlike the matome-mediated set, this also resolves
    // contacts for Unfiled files (no matome).
    final recordingIds =
        rows.map((r) => r.readTable(recordings).id).toList(growable: false);
    final contactsByRecording = <String, List<String>>{};
    if (recordingIds.isNotEmpty) {
      final directQuery = select(recordingContacts).join([
        innerJoin(contacts, contacts.id.equalsExp(recordingContacts.contactId)),
      ])
        // Recording ids are already owner-scoped (the page is owner B-free);
        // also filter the joined contact on owner so a stray cross-owner link
        // row can never surface another owner's contact name (defense-in-depth).
        ..where(recordingContacts.recordingId.isIn(recordingIds) &
            contacts.ownerId.equals(ownerId))
        ..orderBy([OrderingTerm.asc(contacts.displayName)]);
      for (final row in await directQuery.get()) {
        final rid = row.readTable(recordingContacts).recordingId;
        final name = row.readTable(contacts).displayName;
        (contactsByRecording[rid] ??= <String>[]).add(name);
      }
    }

    return rows.map((row) {
      final recording = row.readTable(recordings);
      final matome = row.readTableOrNull(matomes);
      final space = row.readTableOrNull(workspaces);
      // UNION direct + matome-mediated names, de-duplicated (direct first) so a
      // contact linked both ways is shown once. Order: direct names (display-name
      // asc), then any matome-only names not already present.
      final names = <String>[];
      final seen = <String>{};
      for (final n in contactsByRecording[recording.id] ?? const <String>[]) {
        if (seen.add(n)) names.add(n);
      }
      if (matome != null) {
        for (final n in contactsByMatome[matome.id] ?? const <String>[]) {
          if (seen.add(n)) names.add(n);
        }
      }
      return FileRow.fromRow(
        recording,
        matomeTitle: matome?.title,
        spaceName: space?.name,
        contacts: names,
      );
    }).toList(growable: false);
  }

  /// Backfill the owning user onto every NULL-owner local row (#1469).
  ///
  /// SECURITY (A01): pre-#1469 the sync path never wrote `owner_id`, so every
  /// synced row landed NULL-owner and is INVISIBLE to [filesForOwner] (fail-
  /// closed — a NULL owner never equals a concrete id). The Core reconcile now
  /// stamps the server `owner_id` on rows that round-trip, but a LOCAL-ONLY row
  /// (a `rec_local_<uuid>` upload whose Core create has not reconciled, or any
  /// legacy NULL-owner row that predates this fix) has no server owner_id to
  /// adopt. This one-time-per-sync pass stamps the AUTHENTICATED session owner
  /// onto those rows so the user's own files become visible after sign-in.
  ///
  /// SAFETY: it ONLY writes rows where `owner_id IS NULL` — it can never
  /// overwrite (and so never reassign) a row that already carries a real owner.
  /// [ownerId] MUST be the current session owner (non-empty); callers pass the
  /// stringified Core user id from the authenticated session, never a param.
  /// Returns the number of rows backfilled.
  Future<int> backfillNullOwner(String ownerId) {
    assert(ownerId.isNotEmpty, 'backfillNullOwner requires a non-empty owner');
    if (ownerId.isEmpty) return Future.value(0);
    return (update(recordings)..where((r) => r.ownerId.isNull()))
        .write(RecordingsCompanion(ownerId: Value(ownerId)));
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

  // ---------------------------------------------------------------------------
  // Files view — owner-scoped move-to-matome (#1473)
  // ---------------------------------------------------------------------------

  /// The DISTINCT matomes the [ownerId] user actually has recordings in —
  /// the filing TARGETS for the Files view's "Move to matome" picker (#1473).
  ///
  /// SECURITY (A01 — Broken Access Control): the `matomes` table carries NO
  /// `owner_id` column, so an owner-scoped picker CANNOT be derived from the
  /// matome row directly. It is derived from the OWNED recordings instead — a
  /// matome surfaces as a target ONLY when this owner already owns a recording
  /// filed into it (`recordings.owner_id == ownerId`). A matome that holds only
  /// another owner's rows is therefore never offered, so a move can never target
  /// a matome the owner has no relationship with. Archived matomes are excluded
  /// (a move into an archived matome would be invisible). Newest happening first,
  /// to match the rest of the matome listings.
  Future<List<MatomeRow>> matomeTargetsForOwner(String ownerId) async {
    final query = selectOnly(recordings, distinct: true)
      ..addColumns([recordings.matomeId])
      ..where(
        recordings.ownerId.equals(ownerId) & recordings.matomeId.isNotNull(),
      );
    final ids = (await query.get())
        .map((r) => r.read(recordings.matomeId))
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const [];

    return (select(matomes)
          ..where((m) => m.id.isIn(ids) & m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// The current `matome_id` of each of [ids] that the [ownerId] user owns —
  /// the prior state the Files view stashes BEFORE a move so Undo can restore it
  /// (#1473). Owner-scoped (`owner_id == ownerId`) so a caller can never read
  /// another owner's filing. A NULL value ⟺ the file was Unfiled. Rows not owned
  /// by [ownerId] are simply absent from the map.
  Future<Map<String, String?>> matomeIdsForOwnedRecordings(
    Set<String> ids,
    String ownerId,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await (select(recordings)
          ..where((r) => r.id.isIn(ids) & r.ownerId.equals(ownerId)))
        .get();
    return {for (final r in rows) r.id: r.matomeId};
  }

  /// Reassign the [ids] recordings to [matomeId] (or Unfiled when null),
  /// OWNER-SCOPED, in a single transaction (#1473). Returns the number of rows
  /// actually moved.
  ///
  /// SECURITY (A01 — Broken Access Control): every UPDATE carries the owner
  /// predicate (`owner_id == ownerId`) so a caller can ONLY move rows it owns —
  /// a forged id for another owner's file matches zero rows and is a no-op. The
  /// [matomeId] target is validated against [matomeTargetsForOwner] by the host
  /// picker (it only lists the owner's matomes), and a defensive guard here
  /// rejects a target the owner has no recording relationship with so the DAO is
  /// safe even if called directly. Both the source and destination matomes have
  /// their aggregated summary marked stale (ADR-0003 invalidation — each one's
  /// item set changed).
  Future<int> moveRecordingsToMatome(
    Set<String> ids,
    String? matomeId,
    String ownerId,
  ) async {
    if (ids.isEmpty) return 0;
    return transaction(() async {
      // Defense-in-depth owner-scope on the TARGET. The `matomes` table has no
      // `owner_id`, so a matome's ownership is inferred from the recordings it
      // holds. A target is rejected ONLY when it is ANOTHER owner's matome — it
      // contains at least one recording owned by someone else and NONE owned by
      // this owner. An empty matome (a freshly created destination) and a matome
      // this owner already has files in are both valid targets. The host picker
      // additionally only OFFERS the owner's own matomes (matomeTargetsForOwner).
      if (matomeId != null && await _isForeignMatome(matomeId, ownerId)) {
        return 0;
      }

      // Stash the source matomes BEFORE the write so we can invalidate them too.
      final prior = await matomeIdsForOwnedRecordings(ids, ownerId);

      final moved = await (update(recordings)
            ..where((r) => r.id.isIn(ids) & r.ownerId.equals(ownerId)))
          .write(RecordingsCompanion(matomeId: Value(matomeId)));

      // Mark every affected matome's summary stale (source + destination).
      final affected = <String>{
        ...prior.values.whereType<String>(),
        ?matomeId,
      };
      for (final mid in affected) {
        await _markMatomeSummaryStale(mid);
      }
      return moved;
    });
  }

  /// True when [matomeId] belongs to ANOTHER owner — it holds at least one
  /// recording owned by someone other than [ownerId] and NONE owned by
  /// [ownerId]. Used to reject a cross-owner move target while still allowing an
  /// empty (un-owned) destination matome and the owner's own matomes (#1473).
  Future<bool> _isForeignMatome(String matomeId, String ownerId) async {
    final rows = await (select(recordings)
          ..where((r) => r.matomeId.equals(matomeId)))
        .get();
    if (rows.isEmpty) return false; // empty matome — a valid destination.
    final ownedHere = rows.any((r) => r.ownerId == ownerId);
    return !ownedHere; // only other-owner rows → foreign.
  }

  /// Restore each recording in [priorByRecording] to the matome it held before a
  /// move — the Undo half of [moveRecordingsToMatome] (#1473). Owner-scoped and
  /// transactional; a NULL value restores the file to Unfiled. Each restore is a
  /// per-id scoped UPDATE so a forged id cannot rewrite another owner's row.
  Future<void> restoreRecordingMatomes(
    Map<String, String?> priorByRecording,
    String ownerId,
  ) async {
    if (priorByRecording.isEmpty) return;
    await transaction(() async {
      final affected = <String>{};
      for (final entry in priorByRecording.entries) {
        await (update(recordings)
              ..where(
                (r) => r.id.equals(entry.key) & r.ownerId.equals(ownerId),
              ))
            .write(RecordingsCompanion(matomeId: Value(entry.value)));
        if (entry.value != null) affected.add(entry.value!);
      }
      for (final mid in affected) {
        await _markMatomeSummaryStale(mid);
      }
    });
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
