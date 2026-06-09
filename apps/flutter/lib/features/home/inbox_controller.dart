import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/providers.dart';
import '../recordings/recordings_repository.dart';
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
        // Per-field merge: read the local row first so an unsynced local edit
        // (move-to-space, notes) is not clobbered by a stale Core list-row.
        final existing =
            await _dao.getRecordingById(coreIdToLocalId(recording.id));
        await _dao.upsertRecording(
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

    // Persist to Core only when BOTH ids are Core-backed (numeric). Locally
    // created spaces use `ws_<epoch>_<rand>` ids that have no Core counterpart;
    // for those the merge-upsert in [refresh] is what keeps the move durable.
    final coreId = int.tryParse(recordingId);
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
  Future<void> insertLocalUpload(RecordingsCompanion entry) async {
    await _dao.upsertRecording(entry);
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
        summary: failed ? const Value.absent() : Value(summary),
        notes: failed ? Value(errorReason) : Value(notes),
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
}

final inboxControllerProvider = StateNotifierProvider<InboxController,
    AsyncValue<List<InboxItem>>>(
  (ref) => InboxController(ref),
);
