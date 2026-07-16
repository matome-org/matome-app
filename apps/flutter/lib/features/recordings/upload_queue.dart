import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../matome/matome_sync_service.dart';
import '../spaces/current_caller.dart';
import '../spaces/effective_space.dart';
import '../spaces/space_ref_mapping.dart';
import '../spaces/sync_policy.dart';
import 'recording_ids.dart';
import 'recordings_repository.dart';
import 'upload_descriptor.dart';

typedef ProcessingEligibility = bool Function(ItemWithPayload item);

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
    ProcessingEligibility? shouldProcess,
  }) : _clock = clock ?? DateTime.now,
       _jitter = jitter ?? Random().nextDouble,
       _shouldProcess = shouldProcess ?? _defaultProcessingEligibility,
       _configRevision =
           configRevision ?? (() => _ref.read(systemPolicyProvider).revision),
       _leaseOwner =
           'device-${DateTime.now().microsecondsSinceEpoch}-'
           '${Random().nextInt(1 << 32)}';

  final Ref _ref;
  final DateTime Function() _clock;
  final double Function() _jitter;
  final int Function() _configRevision;
  final ProcessingEligibility _shouldProcess;
  final String _leaseOwner;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final Duration leaseDuration;
  final int maxAttempts;

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
    if (item.coreId != null) {
      return item.file?.checksumSha256 == null
          ? kWorkStageHashFile
          : kWorkStageRequestUpload;
    }
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
      UploadDescriptor? upload;

      // A pre-W4 worker could persist enqueue_processing after a raw PUT, before
      // Core had any verified-completion API. Never trust that legacy stage when
      // the local file has no checksum evidence.
      if (stage == kWorkStageEnqueueProcessing &&
          item.file?.checksumSha256 == null) {
        if (!await _advance(work, kWorkStageHashFile, 0.1)) return;
        stage = kWorkStageHashFile;
      }

      if (stage == kWorkStageReconcileParent) {
        await _requireCoreParent(item);
        if (!await _advance(work, kWorkStageHashFile, 0.1)) return;
        stage = kWorkStageHashFile;
      }

      if (stage == kWorkStageCreateRemote) {
        if (item.file?.checksumSha256 == null) {
          await _persistFileFacts(item, ownerId);
          item = (await _items.getById(work.itemId, ownerId))!;
        }
        final created = await _createRemote(item);
        await _inbox.markCoreCreated(item.id, created.recording.id);
        if (!await _advance(work, kWorkStageRequestUpload, 0.2)) return;
        stage = kWorkStageRequestUpload;
        item = (await _items.getById(work.itemId, ownerId))!;
      }

      // `upload` is the pre-W4 stage. Existing databases resume by hashing the
      // canonical finalized file before obtaining fresh Core credentials.
      if (stage == kWorkStageUpload) stage = kWorkStageHashFile;

      if (stage == kWorkStageHashFile) {
        await _persistFileFacts(item, ownerId);
        item = (await _items.getById(work.itemId, ownerId))!;
        if (item.coreId == null) {
          if (!await _advance(work, kWorkStageCreateRemote, 0.15)) return;
          final created = await _createRemote(item);
          await _inbox.markCoreCreated(item.id, created.recording.id);
          item = (await _items.getById(work.itemId, ownerId))!;
        }
        if (!await _advance(work, kWorkStageRequestUpload, 0.2)) return;
        stage = kWorkStageRequestUpload;
      }

      if (stage == kWorkStageRequestUpload) {
        final hold = await _egressHold(item);
        if (hold != null) {
          await _block(work, hold);
          return;
        }
        upload = await _requestUpload(item);
        if (upload.isUploaded) {
          await _persistVerifiedUpload(item, ownerId, upload);
          stage = await _nextAfterUpload(work, item);
        } else {
          await _persistUploadContext(item, ownerId, upload);
          stage = upload.mode == UploadMode.multipart
              ? kWorkStageUploadParts
              : kWorkStageUploadSingle;
          if (!await _advance(work, stage, 0.25)) return;
        }
      }

      if (stage == kWorkStageUploadSingle) {
        final context = _LocalUploadContext.fromJson(
          item.file?.multipartContext,
        );
        if (context?.etag == null) {
          upload ??= await _requestUpload(item);
          if (upload.isUploaded) {
            await _persistVerifiedUpload(item, ownerId, upload);
            stage = await _nextAfterUpload(work, item);
          } else {
            final request = upload.request;
            final file = await _localFile(item);
            if (request == null || upload.mode != UploadMode.single) {
              throw const _PermanentWorkFailure(kWorkErrorContentRejected);
            }
            if (!await _renew(work)) return;
            final etag = await _repo.uploadFileRange(
              request,
              file,
              start: 0,
              endExclusive: item.file!.byteSize,
            );
            await _persistUploadContext(item, ownerId, upload, etag: etag);
            if (!await _advance(work, kWorkStageCompleteUpload, 0.82)) return;
            stage = kWorkStageCompleteUpload;
            item = (await _items.getById(work.itemId, ownerId))!;
          }
        } else {
          if (!await _advance(work, kWorkStageCompleteUpload, 0.82)) return;
          stage = kWorkStageCompleteUpload;
        }
      }

      if (stage == kWorkStageUploadParts) {
        upload = await _requestUpload(item);
        if (upload.isUploaded) {
          await _persistVerifiedUpload(item, ownerId, upload);
          stage = await _nextAfterUpload(work, item);
        } else {
          if (upload.mode != UploadMode.multipart || upload.partSize == null) {
            throw const _PermanentWorkFailure(kWorkErrorContentRejected);
          }
          final file = await _localFile(item);
          final accepted = <int, UploadPart>{
            for (final part in upload.acceptedParts) part.partNumber: part,
          };
          await _persistUploadContext(
            item,
            ownerId,
            upload,
            parts: accepted.values,
          );
          for (final partNumber in upload.missingParts) {
            final start = (partNumber - 1) * upload.partSize!;
            final end = min(start + upload.partSize!, item.file!.byteSize);
            final checksum = await _checksumRange(file, start, end);
            final part = await _repo.presignUploadPart(
              upload.uploadId,
              partNumber: partNumber,
              checksumSha256: checksum,
            );
            if (part.byteSize != end - start ||
                part.checksumSha256 != checksum) {
              throw const _PermanentWorkFailure(kWorkErrorContentRejected);
            }
            if (!await _renew(work)) return;
            final etag = await _repo.uploadFileRange(
              part.request,
              file,
              start: start,
              endExclusive: end,
            );
            accepted[partNumber] = UploadPart(
              partNumber: partNumber,
              etag: etag,
              checksumSha256: checksum,
              byteSize: end - start,
            );
            await _persistUploadContext(
              item,
              ownerId,
              upload,
              parts: accepted.values,
            );
            final acceptedBytes = accepted.values.fold<int>(
              0,
              (total, part) => total + part.byteSize,
            );
            final progress = 0.25 + 0.55 * acceptedBytes / item.file!.byteSize;
            if (!await _advance(
              work,
              kWorkStageUploadParts,
              progress.clamp(0.25, 0.8),
            )) {
              return;
            }
          }
          if (!await _advance(work, kWorkStageCompleteUpload, 0.82)) return;
          stage = kWorkStageCompleteUpload;
          item = (await _items.getById(work.itemId, ownerId))!;
        }
      }

      if (stage == kWorkStageCompleteUpload) {
        final context = _LocalUploadContext.fromJson(
          item.file?.multipartContext,
        );
        if (context == null) {
          throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
        }
        if (!await _renew(work)) return;
        final completed = await _repo.completeUpload(
          context.uploadId,
          uploadGeneration: context.uploadGeneration,
          checksumSha256: item.file!.checksumSha256!,
          etag: context.etag,
          parts: context.parts,
        );
        if (completed.state == UploadState.stale ||
            completed.state == UploadState.failed ||
            completed.state == UploadState.aborted) {
          if (!await _advance(work, kWorkStageRequestUpload, 0.2)) return;
          throw const ApiException(
            'Upload generation must be refreshed.',
            code: 'upload_expired',
          );
        }
        await _persistVerifiedUpload(item, ownerId, completed);
        stage = await _nextAfterUpload(work, item);
      }

      if (stage == kWorkStageUploadOnlyComplete) {
        final completed = await _work.completeUploadOnly(
          work.id,
          itemId: item.id,
          ownerId: ownerId,
          leaseOwner: _leaseOwner,
          now: _now,
        );
        if (completed) await _inbox.reloadFromLocal();
        return;
      }

      if (stage == kWorkStageEnqueueProcessing) {
        item = (await _items.getById(work.itemId, ownerId))!;
        final coreId = item.coreId;
        if (coreId == null || item.file?.uploadState != 'uploaded') {
          throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
        }
        if (!await _renew(work)) return;
        final accepted = await _repo.enqueueProcessing(coreId);
        final completed = await _work.completeProcessingAccepted(
          work.id,
          itemId: item.id,
          ownerId: ownerId,
          leaseOwner: _leaseOwner,
          now: _now,
          processingState: accepted.processing.state.wireName,
          processingRunId: accepted.processing.runId,
          processingAttempt: accepted.processing.attempt,
          processingRequestedOutputs: accepted.processing.requestedOutputs.map(
            (kind) => kind.wireName,
          ),
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
      checksumSha256: item.file?.checksumSha256,
    );
  }

  Future<void> _persistFileFacts(ItemWithPayload item, String ownerId) async {
    final file = await _localFile(item, requireKnownLength: false);
    final before = await file.stat();
    if (before.size <= 0) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    final checksum = await _checksumRange(file, 0, before.size);
    final after = await file.stat();
    if (after.size != before.size || after.modified != before.modified) {
      throw const _BlockedWork(kWorkBlockCore);
    }
    final changed = await _items.updateFile(
      item.id,
      ownerId,
      FileBlobsCompanion(
        byteSize: Value(after.size),
        checksumSha256: Value(checksum),
        uploadState: const Value('pending'),
        uploadedAt: const Value(null),
        multipartContext: const Value(null),
        updatedAt: Value(_now),
        isDirty: const Value(true),
      ),
    );
    if (changed != 1) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
  }

  Future<UploadDescriptor> _requestUpload(ItemWithPayload item) {
    final coreId = item.coreId;
    final file = item.file;
    if (coreId == null ||
        file == null ||
        file.byteSize <= 0 ||
        file.checksumSha256 == null) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    return _repo.requestUpload(
      coreId,
      inputRevision: item.item.sourceRevision,
      byteSize: file.byteSize,
      contentType: file.contentType,
      checksumSha256: file.checksumSha256!,
    );
  }

  Future<File> _localFile(
    ItemWithPayload item, {
    bool requireKnownLength = true,
  }) async {
    final path = item.localPath;
    if (path == null || path.isEmpty) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    if (requireKnownLength && await file.length() != item.file?.byteSize) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    return file;
  }

  Future<String> _checksumRange(File file, int start, int endExclusive) async {
    if (start < 0 || endExclusive <= start) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
    return (await sha256.bind(file.openRead(start, endExclusive)).first)
        .toString();
  }

  Future<void> _persistUploadContext(
    ItemWithPayload item,
    String ownerId,
    UploadDescriptor upload, {
    String? etag,
    Iterable<UploadPart>? parts,
  }) async {
    final context = _LocalUploadContext(
      uploadId: upload.uploadId,
      uploadGeneration: upload.uploadGeneration,
      mode: upload.mode,
      partSize: upload.partSize,
      etag: etag,
      parts: (parts ?? upload.acceptedParts).toList(growable: false),
    );
    final changed = await _items.updateFile(
      item.id,
      ownerId,
      FileBlobsCompanion(
        uploadState: const Value('uploading'),
        uploadGeneration: Value(upload.uploadGeneration),
        uploadedAt: const Value(null),
        multipartContext: Value(context.toJson()),
        updatedAt: Value(_now),
        isDirty: const Value(true),
      ),
    );
    if (changed != 1) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
  }

  Future<void> _persistVerifiedUpload(
    ItemWithPayload item,
    String ownerId,
    UploadDescriptor upload,
  ) async {
    final file = item.file;
    if (!upload.isUploaded ||
        file == null ||
        upload.verifiedByteSize != file.byteSize ||
        upload.verifiedChecksumSha256 != file.checksumSha256) {
      throw const _PermanentWorkFailure(kWorkErrorContentRejected);
    }
    final changed = await _items.updateFile(
      item.id,
      ownerId,
      FileBlobsCompanion(
        byteSize: Value(upload.verifiedByteSize!),
        checksumSha256: Value(upload.verifiedChecksumSha256),
        uploadState: const Value('uploaded'),
        uploadGeneration: Value(upload.uploadGeneration),
        uploadedAt: Value(_now),
        multipartContext: const Value(null),
        updatedAt: Value(_now),
        isDirty: const Value(false),
      ),
    );
    if (changed != 1) {
      throw const _PermanentWorkFailure(kWorkErrorInvalidLocalData);
    }
  }

  Future<String> _nextAfterUpload(
    WorkQueueRow work,
    ItemWithPayload item,
  ) async {
    final stage = _shouldProcess(item)
        ? kWorkStageEnqueueProcessing
        : kWorkStageUploadOnlyComplete;
    if (!await _advance(work, stage, 0.9)) {
      throw const _BlockedWork(kWorkBlockCore);
    }
    return stage;
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
    final current = await _work.getForItem(work.itemId, kWorkKindFileUpload);
    if (error is ApiException &&
        _refreshesUpload(error.code) &&
        current != null &&
        const {
          kWorkStageRequestUpload,
          kWorkStageUploadSingle,
          kWorkStageUploadParts,
          kWorkStageCompleteUpload,
        }.contains(current.stage)) {
      await _advance(work, kWorkStageRequestUpload, 0.2);
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
      if (_refreshesUpload(error.code)) {
        return const _WorkFailure(kWorkErrorTransport, retryable: true);
      }
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

  bool _refreshesUpload(String? code) => const {
    'upload_expired',
    'stale_upload_generation',
    'upload_failed',
    'upload_missing_etag',
    'verification_failed',
  }.contains(code);

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

bool _defaultProcessingEligibility(ItemWithPayload item) =>
    const {'audio', 'image', 'document'}.contains(item.file?.mediaType);

class _LocalUploadContext {
  const _LocalUploadContext({
    required this.uploadId,
    required this.uploadGeneration,
    required this.mode,
    required this.partSize,
    required this.etag,
    required this.parts,
  });

  factory _LocalUploadContext.fromMap(Map<String, dynamic> json) {
    final rawParts = json['accepted_parts'];
    return _LocalUploadContext(
      uploadId: json['upload_id'] as String,
      uploadGeneration: json['upload_generation'] as int,
      mode: json['mode'] == 'multipart'
          ? UploadMode.multipart
          : UploadMode.single,
      partSize: json['part_size'] as int?,
      etag: json['etag'] as String?,
      parts: rawParts is List
          ? rawParts
                .whereType<Map<String, dynamic>>()
                .map(UploadPart.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  static _LocalUploadContext? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic>
          ? _LocalUploadContext.fromMap(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  final String uploadId;
  final int uploadGeneration;
  final UploadMode mode;
  final int? partSize;
  final String? etag;
  final List<UploadPart> parts;

  String toJson() {
    final sortedParts = [...parts]
      ..sort((left, right) => left.partNumber.compareTo(right.partNumber));
    return jsonEncode(<String, dynamic>{
      'upload_id': uploadId,
      'upload_generation': uploadGeneration,
      'mode': mode.name,
      'part_size': partSize,
      'etag': etag,
      'accepted_parts': sortedParts.map((part) => part.toJson()).toList(),
    });
  }
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

final uploadQueueProvider = Provider<UploadQueue>((ref) {
  final policy = ref.watch(systemPolicyProvider);
  return UploadQueue(
    ref,
    configRevision: () => policy.revision,
    baseRetryDelay: policy.baseRetryDelay,
    maxRetryDelay: policy.maxRetryDelay,
    leaseDuration: policy.leaseDuration,
    maxAttempts: policy.maxAttempts,
    shouldProcess: (item) =>
        policy.enabledInputKinds.contains(item.file?.mediaType) &&
        _defaultProcessingEligibility(item),
  );
});
