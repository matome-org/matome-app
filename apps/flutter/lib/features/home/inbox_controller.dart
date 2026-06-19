import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/providers.dart';
import '../recordings/recording_ids.dart';
import '../recordings/recordings_repository.dart';
import '../recordings/upload_queue.dart';
import 'inbox_item.dart';
import 'inbox_sync.dart';

/// Drives the Inbox screen (S1, #780): offline-first list backed by Drift, with
/// a best-effort Core sync on load / pull-to-refresh.
///
/// Display source is ALWAYS Drift (`getInboxRecordings`, workspaceId IS NULL).
/// `refresh()` pulls from Core, upserts into Drift (reconciling int<->TEXT ids),
/// then re-reads from Drift. If the network fails, the cached Drift rows still
/// render (the error is swallowed so offline still shows data).
class InboxController extends StateNotifier<AsyncValue<List<InboxItem>>> {
  InboxController(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  RecordingsDao get _dao => _ref.read(recordingsDaoProvider);
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);

  /// Re-reads the Inbox from Drift and publishes it as the new state.
  Future<void> reloadFromLocal() async {
    final next = await AsyncValue.guard(_loadItems);
    if (mounted) state = next;
  }

  Future<List<InboxItem>> _loadItems() async {
    final rows = await _dao.getInboxRecordings();
    return rows.map(InboxItem.fromRow).toList(growable: false);
  }

  /// Pull from Core, upsert into Drift, then render from Drift. Network errors
  /// are swallowed so the offline cache still displays.
  Future<void> refresh() async {
    // Show whatever is already cached first (offline-first).
    final cached = await AsyncValue.guard(_loadItems);
    if (!mounted) return;
    state = cached;

    try {
      final remote = await _repo.fetchRecordings();
      for (final recording in remote) {
        // Match the existing local row by its reconciled `coreId` column FIRST
        // (plan #43, W3): a `rec_local_<uuid>` row that already uploaded keeps
        // its UUID PK, so keying off the stringified Core id alone would miss it
        // and the upsert would insert a duplicate. Fall back to the legacy
        // stringified-id PK for rows that predate the coreId column.
        final existing = await _dao.recordingByCoreId(recording.id) ??
            await _dao.getRecordingById(coreIdToLocalId(recording.id));
        // m007 (ADR-0003): a Core-originated recording must also become an Item
        // of a Matome. `upsertRecordingWithMatome` reuses the existing row's
        // Matome when there is one (the merge-guard already preserves it) and
        // otherwise mints a fresh Inbox/filed Matome in the same transaction —
        // so a first-time Core sync never persists a Matome-less recording.
        await _dao.upsertRecordingWithMatome(
          recordingToCompanion(recording, existing: existing),
        );
      }
    } on ApiException catch (error) {
      // Network/offline OR auth/server error. We keep the cached rows either
      // way (offline-first), but a 401 / non-network failure is NOT "offline" —
      // surface it so it isn't silently masked as a connectivity blip.
      if (error.isUnauthorized || error.statusCode != null) {
        developer.log(
          'Inbox sync failed (not offline)',
          name: 'inbox.sync',
          error: error,
        );
      }
      // else: transport-level (no statusCode) → genuine offline, stay quiet.
    } catch (error, stack) {
      // Drift-write or unexpected failure — never a silent "offline".
      developer.log(
        'Inbox sync write failed',
        name: 'inbox.sync',
        error: error,
        stackTrace: stack,
      );
    }

    final next = await AsyncValue.guard(_loadItems);
    if (mounted) state = next;
  }

  /// Move a recording out of the Inbox into [workspaceId]. Writes locally first
  /// (so the row leaves the Inbox immediately, offline-first) then persists the
  /// move to Core via `PATCH /api/recordings/:id` so a later list `refresh()`
  /// does not snap it back to the Inbox. If the Core PATCH fails (offline/401),
  /// the local move still holds and the merge-upsert in [refresh] preserves it
  /// until the next successful sync.
  Future<void> moveToSpace(String recordingId, String workspaceId) async {
    await _dao.updateRecording(
      recordingId,
      RecordingsCompanion(workspaceId: Value(workspaceId)),
    );
    await reloadFromLocal();

    // Persist to Core only when the recording is reconciled with Core (its
    // `coreId` column is set) AND the target space is Core-backed (numeric id).
    // A `rec_local_<uuid>` row that hasn't uploaded yet has `coreId` null — the
    // move can't reach Core, so it is left local-only (plan #43, W3): the
    // merge-upsert guard in [refresh] keeps the space durable, and once the row
    // reconciles its coreId a later move/sync round-trips it. Locally-created
    // spaces use `ws_<epoch>_<rand>` ids with no Core counterpart, also skipped.
    final row = await _dao.getRecordingById(recordingId);
    final coreId = row?.coreId;
    final coreWorkspaceId = int.tryParse(workspaceId);
    if (coreId != null && coreWorkspaceId != null) {
      try {
        await _repo.updateRecording(coreId, workspaceId: coreWorkspaceId);
      } on ApiException catch (error) {
        // Best-effort: the local move + merge-upsert guard keep the recording
        // in its space until Core catches up. Log non-offline failures.
        if (error.isUnauthorized || error.statusCode != null) {
          developer.log(
            'moveToSpace Core PATCH failed',
            name: 'inbox.move',
            error: error,
          );
        }
      }
    }
  }

  /// All workspaces available as move-to-space targets.
  Future<List<WorkspaceRow>> spaces() => _workspacesDao.getWorkspaces();

  /// Insert a locally-created (just-uploaded) recording row so it shows in the
  /// Inbox immediately as "processing", before Core confirms. Mirrors
  /// apps/mobile uploadRecordingService createRecording-then-render.
  ///
  /// m007 (ADR-0003): a recording is never persisted without a Matome. This
  /// goes through [RecordingsDao.upsertRecordingWithMatome], which mints the
  /// Matome in the SAME transaction (Inbox upload → Inbox Matome) so the
  /// recording.matomeId FK never sees an orphan window.
  Future<void> insertLocalUpload(RecordingsCompanion entry) async {
    await _dao.upsertRecordingWithMatome(entry);
    await reloadFromLocal();
  }

  /// Reconcile a local-first row with its Core identity once `POST
  /// /api/recordings` succeeds (plan #43, W2). The row keeps its local
  /// `rec_local_<uuid>` PK — this fills the separate nullable `coreId` column
  /// (never a PK remap) and flips the local-only `pending_upload` status to the
  /// backend `processing` state so the card reflects that Core has accepted it.
  ///
  /// W3 keys the socket/poll reconcile on `coreId`; W4's retry queue calls this
  /// the moment a queued create succeeds.
  Future<void> reconcileCoreId(String localId, int coreId) async {
    await _dao.updateRecording(
      localId,
      RecordingsCompanion(
        coreId: Value(coreId),
        isProcessing: const Value(1),
        processingStatus: const Value('processing'),
      ),
    );
    await reloadFromLocal();
  }

  /// Apply a terminal upload outcome to the local row (done/failed), then
  /// re-render. Used by the upload flow once the F4 pipeline resolves.
  ///
  /// On failure, [errorReason] (the underlying error message) is persisted to
  /// `notes` so the failed card carries a real, inspectable reason instead of a
  /// bare "failed" status. The Drift schema has no dedicated error column, so
  /// `notes` is reused as the failure detail surface (it is unused for a
  /// recording that never transcribed).
  ///
  /// On success, [summary]/[notes] are merge-written (B3): a sparse socket
  /// `done` event can carry nulls even after good data exists, so [mergeText]
  /// keeps the column untouched rather than null-wiping a previously-good value.
  Future<void> applyUploadResult(
    String recordingId, {
    required bool failed,
    String? summary,
    String? notes,
    String? errorReason,
  }) async {
    await _dao.updateRecording(
      recordingId,
      RecordingsCompanion(
        isProcessing: const Value(0),
        processingStatus: Value(failed ? 'failed' : 'done'),
        summary: failed ? const Value.absent() : mergeText(summary),
        notes: failed ? Value(errorReason) : mergeText(notes),
      ),
    );
    await reloadFromLocal();
  }

  /// Mark a local row as processing again (retry path).
  Future<void> markProcessing(String recordingId) async {
    await _dao.updateRecording(
      recordingId,
      const RecordingsCompanion(
        isProcessing: Value(1),
        processingStatus: Value('processing'),
      ),
    );
    await reloadFromLocal();
  }

  /// MANUAL retry from the Inbox card (plan #43, W5), alongside the auto-retry
  /// queue. Re-enqueues a `failed`/`pending_upload` row through the SAME upload
  /// queue ([UploadQueue.drainRow]) rather than duplicating the upload pipeline.
  ///
  /// A `failed` row has already left `pending_upload`, so the queue's
  /// status-gate ([UploadQueue.drainRow] only drains `pending_upload`) would
  /// no-op on it. We first flip the row back to `pending_upload` (clearing the
  /// failure reason persisted in `notes`), re-render so the card immediately
  /// reads as safe-and-pending, then hand off to the queue. The audio file was
  /// kept on every non-confirmed outcome, so the re-upload has a file to send.
  Future<void> retryUpload(String recordingId) async {
    await _dao.updateRecording(
      recordingId,
      const RecordingsCompanion(
        isProcessing: Value(0),
        processingStatus: Value(kProcessingStatusPendingUpload),
        notes: Value(null),
      ),
    );
    await reloadFromLocal();
    // Single-flight + idempotent: the queue guards concurrent drains and skips
    // rows that have already moved on, so this is safe to call from a tap.
    await _ref.read(uploadQueueProvider).drainRow(recordingId);
  }
}

final inboxControllerProvider = StateNotifierProvider<InboxController,
    AsyncValue<List<InboxItem>>>(
  (ref) => InboxController(ref),
);
