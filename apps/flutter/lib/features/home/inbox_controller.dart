import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/feature_flags.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/items_dao.dart';
import '../../core/db/daos/work_queue_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../recordings/recording_ids.dart';
import '../recordings/processing_error.dart';
import '../recordings/recordings_repository.dart';
import '../recordings/upload_queue.dart';
import '../spaces/current_caller.dart';
import '../spaces/space_ref_mapping.dart';
import '../spaces/sync_policy.dart';
import 'inbox_item.dart';
import 'inbox_sync.dart';

class InboxController extends StateNotifier<AsyncValue<List<InboxItem>>> {
  InboxController(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  ItemsDao get _dao => _ref.read(itemsDaoProvider);
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);
  String? get _ownerId => _ref.read(currentOwnerIdProvider);

  Future<void> reloadFromLocal() async {
    final next = await AsyncValue.guard(_loadItems);
    if (mounted) state = next;
  }

  Future<List<InboxItem>> _loadItems() async {
    final ownerId = _ownerId;
    if (ownerId == null) return const [];
    final rows = await _dao.listInbox(ownerId);
    return rows.map(InboxItem.fromItem).toList(growable: false);
  }

  Future<void> refresh() async {
    final cached = await AsyncValue.guard(_loadItems);
    if (!mounted) return;
    state = cached;

    final ownerId = _ownerId;
    if (ownerId == null) return;
    try {
      final remote = await _repo.fetchRecordings();
      for (final recording in remote) {
        if (recording.ownerId != ownerId) continue;
        final existing =
            await _dao.getByCoreId(recording.id, ownerId) ??
            await _dao.getById(coreIdToLocalId(recording.id), ownerId);
        final companions = recordingToItemCompanions(
          recording,
          existing: existing,
        );
        await _dao.upsertFileItem(
          item: companions.item,
          file: companions.file,
          ensureMatome: !FeatureFlags.localFirstSpaces,
        );
      }
    } on ApiException catch (error, stack) {
      if (error.isUnauthorized || error.statusCode != null) {
        AppLog.error(LogCat.sync, 'inbox refresh failed', error, stack);
      }
    } catch (error, stack) {
      AppLog.error(LogCat.sync, 'inbox refresh write failed', error, stack);
    }

    final next = await AsyncValue.guard(_loadItems);
    if (mounted) state = next;
  }

  Future<void> moveToSpace(String itemId, String workspaceId) async {
    final ownerId = _requireOwner();
    await _dao.updateItem(
      itemId,
      ownerId,
      ItemsCompanion(
        workspaceId: Value(workspaceId),
        isDirty: const Value(true),
      ),
    );
    await reloadFromLocal();
    if (!await _maySyncMoveTarget(workspaceId)) return;

    final row = await _dao.getById(itemId, ownerId);
    final coreWorkspaceId = int.tryParse(workspaceId);
    if (row?.coreId != null && coreWorkspaceId != null) {
      try {
        await _repo.updateRecording(row!.coreId!, workspaceId: coreWorkspaceId);
      } on ApiException catch (error, stack) {
        AppLog.error(
          LogCat.sync,
          'moveToSpace Core PATCH failed',
          error,
          stack,
        );
      }
    }
  }

  Future<bool> _maySyncMoveTarget(String workspaceId) async {
    if (!FeatureFlags.localFirstSpaces) return true;
    final spaceRow = await _workspacesDao.getWorkspaceById(workspaceId);
    if (spaceRow == null) return false;
    return SyncPolicy.can(
      currentCaller(_ref),
      Operation.spaceSync,
      spaceRefFromRow(spaceRow),
    );
  }

  Future<bool> fileIntoSpace(
    String itemId,
    String? spaceId, {
    required String ownerId,
  }) async {
    if (_ownerId != ownerId) return false;
    final moved = await _dao.fileIntoSpace(itemId, spaceId, ownerId);
    await reloadFromLocal();
    if (moved == 0 || spaceId == null) return moved > 0;
    if (!await _maySyncMoveTarget(spaceId)) return true;

    final row = await _dao.getById(itemId, ownerId);
    final coreWorkspaceId = int.tryParse(spaceId);
    if (row?.coreId != null && coreWorkspaceId != null) {
      try {
        await _repo.updateRecording(row!.coreId!, workspaceId: coreWorkspaceId);
      } on ApiException catch (error, stack) {
        AppLog.error(
          LogCat.sync,
          'fileIntoSpace Core PATCH failed',
          error,
          stack,
        );
      }
    }
    return true;
  }

  Future<List<WorkspaceRow>> spaces() => _workspacesDao.getWorkspaces();

  Future<void> insertLocalUpload({
    required ItemsCompanion item,
    required FileBlobsCompanion file,
    WorkQueueCompanion? initialWork,
  }) async {
    if (item.ownerId.value != _requireOwner()) {
      throw StateError(
        'Local Item owner does not match the authenticated user',
      );
    }
    if (FeatureFlags.localFirstSpaces) {
      await _dao.createFileItem(
        item: item,
        file: file,
        initialWork: initialWork,
      );
    } else {
      await _dao.upsertFileItem(
        item: item,
        file: file,
        ensureMatome: true,
        initialWork: initialWork,
      );
    }
    await reloadFromLocal();
  }

  Future<void> reconcileCoreId(String localId, int coreId) async {
    final ownerId = _requireOwner();
    await _dao.updateItem(
      localId,
      ownerId,
      ItemsCompanion(
        coreId: Value(coreId),
        processingState: const Value('processing'),
        syncState: const Value('processing'),
        isDirty: const Value(false),
      ),
    );
    await _dao.updateFile(
      localId,
      ownerId,
      const FileBlobsCompanion(
        uploadState: Value('uploading'),
        uploadedAt: Value(null),
        isDirty: Value(true),
      ),
    );
    await reloadFromLocal();
  }

  Future<void> markFileUploaded(String itemId) async {
    await _dao.updateFile(
      itemId,
      _requireOwner(),
      FileBlobsCompanion(
        uploadState: const Value('uploaded'),
        uploadedAt: Value(DateTime.now().millisecondsSinceEpoch),
        multipartContext: const Value(null),
        isDirty: const Value(false),
      ),
    );
  }

  Future<void> markFileUploading(String itemId) async {
    await _dao.updateFile(
      itemId,
      _requireOwner(),
      const FileBlobsCompanion(
        uploadState: Value('uploading'),
        uploadedAt: Value(null),
        isDirty: Value(true),
      ),
    );
  }

  Future<void> markCoreCreated(String itemId, int coreId) async {
    await _dao.updateItem(
      itemId,
      _requireOwner(),
      ItemsCompanion(
        coreId: Value(coreId),
        syncState: const Value(kProcessingStatusPendingUpload),
        processingState: const Value('not_requested'),
        processingErrorCode: const Value(null),
        isDirty: const Value(false),
      ),
    );
    await reloadFromLocal();
  }

  Future<void> markFileUploadFailed(String itemId) async {
    await _dao.updateFile(
      itemId,
      _requireOwner(),
      const FileBlobsCompanion(
        uploadState: Value('failed'),
        uploadedAt: Value(null),
        isDirty: Value(true),
      ),
    );
  }

  Future<void> applyUploadResult(
    String itemId, {
    required bool failed,
    String? summary,
    String? transcript,
    String? errorCode,
  }) async {
    final ownerId = _requireOwner();
    final current = await _dao.getById(itemId, ownerId);
    if (current == null) return;
    await _dao.updateItem(
      itemId,
      ownerId,
      ItemsCompanion(
        processingState: Value(failed ? 'failed' : 'succeeded'),
        processingOutputs: failed
            ? const Value.absent()
            : Value(
                mergeProcessingOutputs(
                  current.item.processingOutputs,
                  summary: summary,
                  transcript: transcript,
                ),
              ),
        processingErrorCode: Value(
          failed ? normalizeProcessingErrorCode(errorCode) : null,
        ),
        syncState: const Value('synced'),
        isDirty: const Value(false),
      ),
    );
    await reloadFromLocal();
  }

  Future<void> markProcessing(String itemId) async {
    await _dao.updateItem(
      itemId,
      _requireOwner(),
      const ItemsCompanion(
        processingState: Value('processing'),
        processingErrorCode: Value(null),
      ),
    );
    await reloadFromLocal();
  }

  Future<void> retryUpload(String itemId) async {
    await _dao.updateItem(
      itemId,
      _requireOwner(),
      const ItemsCompanion(
        syncState: Value(kProcessingStatusPendingUpload),
        processingErrorCode: Value(null),
        isDirty: Value(true),
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final workDao = _ref.read(workQueueDaoProvider);
    final existing = await workDao.getForItem(itemId, kWorkKindFileUpload);
    if (existing == null) {
      final item = await _dao.getById(itemId, _requireOwner());
      if (item != null) {
        await workDao.enqueueOrIgnore(
          fileUploadWork(
            itemId: itemId,
            sourceRevision: item.item.sourceRevision,
            now: now,
            configRevision: _ref.read(systemPolicyProvider).revision,
          ),
        );
      }
    } else {
      await workDao.resetForManualRetry(itemId, now);
    }
    await reloadFromLocal();
    await _ref.read(uploadQueueProvider).drainRow(itemId);
  }

  String _requireOwner() {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('An authenticated owner is required');
    }
    return ownerId;
  }
}

final inboxControllerProvider =
    StateNotifierProvider<InboxController, AsyncValue<List<InboxItem>>>(
      (ref) => InboxController(ref),
    );
