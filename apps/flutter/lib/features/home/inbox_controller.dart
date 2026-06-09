import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
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
    state = await AsyncValue.guard(_loadItems);
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
    state = cached;

    try {
      final remote = await _repo.fetchRecordings();
      for (final recording in remote) {
        await _dao.upsertRecording(recordingToCompanion(recording));
      }
    } catch (_) {
      // Offline / auth error: keep the cached rows. The list already reflects
      // local state; surface the cache rather than an error screen.
    }

    state = await AsyncValue.guard(_loadItems);
  }

  /// Move a recording out of the Inbox into [workspaceId] (Drift-local). It then
  /// disappears from the Inbox list (workspaceId IS NULL filter).
  Future<void> moveToSpace(String recordingId, String workspaceId) async {
    await _dao.updateRecording(
      recordingId,
      RecordingsCompanion(workspaceId: Value(workspaceId)),
    );
    await reloadFromLocal();
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
  Future<void> applyUploadResult(
    String recordingId, {
    required bool failed,
    String? summary,
    String? notes,
  }) async {
    await _dao.updateRecording(
      recordingId,
      RecordingsCompanion(
        isProcessing: const Value(0),
        processingStatus: Value(failed ? 'failed' : 'done'),
        summary: failed ? const Value.absent() : Value(summary),
        notes: failed ? const Value.absent() : Value(notes),
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
