import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/endpoint_controller.dart';
import '../../core/config/feature_flags.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/items_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/work_queue_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../home/inbox_controller.dart';
import '../home/inbox_upload.dart' show RecordingResultAwaiter;
import '../matome/matome_sync_service.dart';
import '../spaces/current_caller.dart';
import '../spaces/effective_space.dart';
import '../spaces/space_ref_mapping.dart';
import '../spaces/sync_policy.dart';
import 'recording_ids.dart';
import 'recordings_repository.dart';
import 'upload_descriptor.dart';

typedef AudioCleanup = Future<void> Function(String audioFilePath);

Future<void> deleteAudioFile(String audioFilePath) async {
  if (audioFilePath.isEmpty) return;
  try {
    final file = File(audioFilePath);
    if (await file.exists()) await file.delete();
  } catch (error, stack) {
    AppLog.error(
      LogCat.upload,
      'deleteAudioFile: best-effort delete failed',
      error,
      stack,
    );
  }
}

/// Single-flight device executor backed by Drift's one durable [WorkQueue]
/// table. The current file-upload operation persists every restart boundary and
/// finishes as soon as Core accepts processing; Core/Oban own AI execution and
/// result lifecycle from that point onward.
class UploadQueue {
  UploadQueue(
    this._ref, {
    DateTime Function()? clock,
    double Function()? jitter,
    int Function()? configRevision,
    this.baseRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(minutes: 5),
    this.leaseDuration = const Duration(minutes: 6),
    this.maxAttempts = 5,
    // Retained as source-compatible injection seams for current callers. Device
    // work intentionally never invokes either one after the W2 cutover.
    RecordingResultAwaiter? awaitResult,
    this.cleanupAudio = deleteAudioFile,
  }) : _clock = clock ?? DateTime.now,
       _jitter = jitter ?? Random().nextDouble,
       _configRevision =
           configRevision ??
           (() => workConfigRevisionForEndpoint(
             _ref.read(endpointConfigProvider),
           )),
       _leaseOwner =
           'device-${DateTime.now().microsecondsSinceEpoch}-'
           '${Random().nextInt(1 << 32)}';

  final Ref _ref;
  final DateTime Function() _clock;
  final double Function() _jitter;
  final int Function() _configRevision;
  final String _leaseOwner;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final Duration leaseDuration;
  final int maxAttempts;
  final AudioCleanup cleanupAudio;

  Future<void>? _activeDrain;
  bool _drainRequested = false;

  ItemsDao get _items => _ref.read(itemsDaoProvider);
  WorkQueueDao get _work => _ref.read(workQueueDaoProvider);
  WorkspacesDao get _workspaces => _ref.read(workspacesDaoProvider);
  MatomesDao get _matomes => _ref.read(matomesDaoProvider);
  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);
  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);
  MatomeSyncService get _matomeSync => _ref.read(matomeSyncServiceProvider);

  /// Coalesces all triggers into one process-local runner. Persisted leases also
  /// serialize separate executor instances against the same database.
  Future<void> drain() {
    _drainRequested = true;
    final active = _activeDrain;
    if (active != null) return active;

    late final Future<void> run;
    run = _runDrainLoop().whenComplete(() {
      if (identical(_activeDrain, run)) _activeDrain = null;
    });
    _activeDrain = run;
    return run;
  }

  /// Ensures temporary pre-W2 pending rows acquire durable work, then runs the
  /// fair global drain. New capture/import rows already insert both atomically.
  Future<void> drainRow(String localId) async {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    final item = await _items.getById(localId, ownerId);
    if (item == null) return;
    await _ensureWork(item);
    await drain();
  }

  /// Explicit user resume makes held/delayed upload work due without erasing its
  /// attempt history. The normal automatic drain still honors backoff.
  Future<void> resumeNow() async {
    await _work.makeDue(kWorkKindFileUpload, _now);
    await drain();
  }

  Future<void> _runDrainLoop() async {
    do {
      _drainRequested = false;
      await _drainPass();
    } while (_drainRequested);
  }

  Future<void> _drainPass() async {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    final now = _now;

    try {
      for (final item in await _items.listPendingUploads(ownerId)) {
        await _ensureWork(item);
      }
      await _work.prepareDrain(now: now, configRevision: _configRevision());
    } catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'work queue preparation failed',
        error,
        stack,
      );
      return;
    }

    final visited = <String>{};
    while (true) {
      final work = await _work.claimNext(
        leaseOwner: _leaseOwner,
        now: _now,
        leaseDuration: leaseDuration,
        excludedIds: visited,
        kinds: const {kWorkKindFileUpload},
      );
      if (work == null) return;
      visited.add(work.id);
      await _execute(work, ownerId);
    }
  }

  Future<void> _ensureWork(ItemWithPayload item) async {
    final existing = await _work.getForItem(item.id, kWorkKindFileUpload);
    if (existing != null) return;
    await _work.enqueueOrIgnore(
      fileUploadWork(
        itemId: item.id,
        sourceRevision: item.item.sourceRevision,
        now: _now,
        configRevision: _configRevision(),
        stage: _resumeStage(item),
      ),
    );
  }

  String _resumeStage(ItemWithPayload item) {
    if (item.file?.uploadState == 'uploaded' && item.coreId != null) {
      return kWorkStageEnqueueProcessing;
    }
    if (item.coreId != null) return kWorkStageUpload;
    return kWorkStageReconcileParent;
  }

  Future<void> _execute(WorkQueueRow work, String ownerId) async {
    if (work.kind != kWorkKindFileUpload) return;
    try {
      var item = await _items.getById(work.itemId, ownerId);
      if (item == null || item.file == null) {
        throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
      }

      final hold = await _egressHold(item);
      if (hold != null) {
        await _block(work, hold);
        return;
      }

      var stage = work.stage;
      RecordingCreateResult? created;

      if (stage == kWorkStageReconcileParent) {
        await _requireCoreParent(item);
        if (!await _advance(work, kWorkStageCreateRemote, 0.2)) return;
        stage = kWorkStageCreateRemote;
      }

      if (stage == kWorkStageCreateRemote) {
        created = await _createRemote(item);
        await _inbox.markCoreCreated(item.id, created.recording.id);
        if (!await _advance(work, kWorkStageUpload, 0.4)) return;
        stage = kWorkStageUpload;
        item = (await _items.getById(work.itemId, ownerId))!;
      }

      if (stage == kWorkStageUpload) {
        final hold = await _egressHold(item);
        if (hold != null) {
          await _block(work, hold);
          return;
        }
        created ??= await _createRemote(item);
        if (item.coreId != null && item.coreId != created.recording.id) {
          throw const _PermanentWorkFailure(kWorkErrorContentRejected);
        }
        if (item.coreId == null) {
          await _inbox.markCoreCreated(item.id, created.recording.id);
        }
        final localPath = item.localPath;
        if (localPath == null || localPath.isEmpty) {
          throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
        }
        if (!await _renew(work)) return;
        await _inbox.markFileUploading(item.id);
        await _repo.uploadFile(created.upload, File(localPath));
        await _inbox.markFileUploaded(item.id);
        if (!await _advance(work, kWorkStageEnqueueProcessing, 0.85)) return;
        stage = kWorkStageEnqueueProcessing;
      }

      if (stage == kWorkStageEnqueueProcessing) {
        item = (await _items.getById(work.itemId, ownerId))!;
        final coreId = item.coreId;
        if (coreId == null) {
          throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
        }
        if (!await _renew(work)) return;
        await _repo.enqueueProcessing(coreId);
        final completed = await _work.completeProcessingAccepted(
          work.id,
          itemId: item.id,
          ownerId: ownerId,
          leaseOwner: _leaseOwner,
          now: _now,
        );
        if (completed) await _inbox.reloadFromLocal();
      }
    } catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'durable work failed kind=${work.kind} stage=${work.stage}',
        error,
        stack,
      );
      await _handleFailure(work, error, ownerId);
    }
  }

  Future<int> _requireCoreParent(ItemWithPayload item) async {
    final matomeId = item.matomeId;
    if (matomeId == null) throw const _BlockedWork(kWorkBlockParent);
    final existing = (await _matomes.getById(matomeId))?.coreId;
    if (existing != null) return existing;
    final reconciled = await _matomeSync.reconcileParent(matomeId);
    if (reconciled == null) throw const _BlockedWork(kWorkBlockParent);
    return reconciled;
  }

  Future<RecordingCreateResult> _createRemote(ItemWithPayload item) async {
    final coreMatomeId = await _requireCoreParent(item);
    final localPath = item.localPath;
    if (localPath == null || localPath.isEmpty) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    return _repo.createItemRecording(
      title: item.title,
      matomeId: coreMatomeId,
      clientId: item.id,
      durationSeconds: item.durationSeconds ?? 0,
      mediaType: item.mediaType,
      contentLength: await _byteSizeOf(localPath),
    );
  }

  Future<String?> _egressHold(ItemWithPayload item) async {
    final matomeId = item.matomeId;
    if (matomeId == null) return kWorkBlockParent;
    final matome = await _matomes.getById(matomeId);
    if (matome == null) return kWorkBlockParent;
    final matomeSpaceId = matome.spaceId;
    if (matomeSpaceId == null) return null;

    final spaceId = EffectiveSpace.effectiveSpaceId(
      ItemMembership(
        matomeSpaceId: matomeSpaceId,
        workspaceId: item.workspaceId,
      ),
    );
    if (spaceId == null) return null;
    final space = await _workspaces.getWorkspaceById(spaceId);
    if (space == null || space.isLocal == 1) return kWorkBlockLocalSpace;
    if (FeatureFlags.localFirstSpaces &&
        !SyncPolicy.can(
          currentCaller(_ref),
          Operation.spaceSync,
          spaceRefFromRow(space),
        )) {
      return kWorkBlockLocalSpace;
    }
    return null;
  }

  Future<bool> _advance(WorkQueueRow work, String stage, double progress) {
    return _work.advance(
      work.id,
      leaseOwner: _leaseOwner,
      stage: stage,
      progress: progress,
      now: _now,
    );
  }

  Future<bool> _renew(WorkQueueRow work) {
    return _work.renew(
      work.id,
      leaseOwner: _leaseOwner,
      now: _now,
      leaseDuration: leaseDuration,
    );
  }

  Future<void> _block(WorkQueueRow work, String reason) async {
    final changed = await _work.block(
      work.id,
      leaseOwner: _leaseOwner,
      reason: reason,
      errorCode: reason == kWorkBlockSignedOut ? kWorkErrorUnauthorized : null,
      now: _now,
    );
    if (changed) await _markItemHeld(work.itemId, reason);
  }

  Future<void> _handleFailure(
    WorkQueueRow work,
    Object error,
    String ownerId,
  ) async {
    if (error is _BlockedWork) {
      await _block(work, error.reason);
      return;
    }
    final failure = _classify(error);
    if (failure.blocked) {
      await _block(work, failure.blockedReason!);
      return;
    }

    final nextAttempt = work.attempt + 1;
    final availableAt = _now + _retryDelay(nextAttempt).inMilliseconds;
    final changed = await _work.retry(
      work.id,
      leaseOwner: _leaseOwner,
      errorCode: failure.code,
      blockedReason: failure.blockedReason,
      availableAt: availableAt,
      maxAttempts: failure.retryable ? maxAttempts : nextAttempt,
      now: _now,
    );
    if (!changed) return;

    final updated = await _work.getForItem(work.itemId, kWorkKindFileUpload);
    if (updated?.state == kWorkStateDead) {
      await _items.updateItem(
        work.itemId,
        ownerId,
        ItemsCompanion(
          processingState: const Value('failed'),
          syncState: const Value('failed'),
          processingErrorCode: Value(failure.code),
          isDirty: const Value(true),
        ),
      );
    } else {
      await _markItemHeld(
        work.itemId,
        failure.blockedReason ?? kWorkBlockCore,
        errorCode: failure.code,
      );
    }
    await _inbox.reloadFromLocal();
  }

  _WorkFailure _classify(Object error) {
    if (error is _PermanentWorkFailure) {
      return _WorkFailure(error.code, retryable: false);
    }
    if (error is ApiException) {
      if (error.isUnauthorized) {
        return const _WorkFailure(
          kWorkErrorUnauthorized,
          retryable: false,
          blocked: true,
          blockedReason: kWorkBlockSignedOut,
        );
      }
      final status = error.statusCode;
      if (status == null) {
        return const _WorkFailure(
          kWorkErrorTransport,
          retryable: false,
          blocked: true,
          blockedReason: kWorkBlockOffline,
        );
      }
      if (status == 408) {
        return const _WorkFailure(kWorkErrorTimeout, retryable: true);
      }
      if (status == 429) {
        return const _WorkFailure(kWorkErrorRateLimited, retryable: true);
      }
      if (status >= 500) {
        return const _WorkFailure(kWorkErrorServerUnavailable, retryable: true);
      }
      return const _WorkFailure(kWorkErrorContentRejected, retryable: false);
    }
    return const _WorkFailure(kWorkErrorUnexpected, retryable: true);
  }

  Duration _retryDelay(int attempt) {
    final exponent = min(max(attempt - 1, 0), 30);
    final exponential = baseRetryDelay.inMilliseconds * (1 << exponent);
    final ceiling = min(maxRetryDelay.inMilliseconds, exponential);
    final jitter = _jitter().clamp(0.0, 1.0);
    return Duration(milliseconds: (ceiling * jitter).floor());
  }

  Future<void> _markItemHeld(
    String itemId,
    String reason, {
    String? errorCode,
  }) async {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    final status = switch (reason) {
      kWorkBlockSignedOut => kProcessingStatusBlockedSignedOut,
      kWorkBlockOffline => kProcessingStatusBlockedOffline,
      kWorkBlockLocalSpace => kProcessingStatusBlockedLocalSpace,
      kWorkBlockParent => kProcessingStatusBlockedParent,
      _ => kProcessingStatusBlockedCore,
    };
    await _items.updateItem(
      itemId,
      ownerId,
      ItemsCompanion(
        syncState: Value(status),
        processingErrorCode: Value(errorCode),
        isDirty: const Value(true),
      ),
    );
    await _inbox.reloadFromLocal();
  }

  Future<int?> _byteSizeOf(String path) async {
    try {
      final file = File(path);
      return await file.exists() ? file.length() : null;
    } catch (_) {
      return null;
    }
  }

  int get _now => _clock().millisecondsSinceEpoch;
}

class _BlockedWork implements Exception {
  const _BlockedWork(this.reason);

  final String reason;
}

class _PermanentWorkFailure implements Exception {
  const _PermanentWorkFailure(this.code);

  final String code;
}

class _WorkFailure {
  const _WorkFailure(
    this.code, {
    required this.retryable,
    this.blocked = false,
    this.blockedReason,
  });

  final String code;
  final bool retryable;
  final bool blocked;
  final String? blockedReason;
}

final uploadQueueProvider = Provider<UploadQueue>((ref) => UploadQueue(ref));
