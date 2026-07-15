import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/feature_flags.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/items_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../home/inbox_controller.dart';
import '../home/inbox_upload.dart';
import '../matome/matome_sync_service.dart';
import '../spaces/current_caller.dart';
import '../spaces/effective_space.dart';
import '../spaces/space_ref_mapping.dart';
import '../spaces/sync_policy.dart';
import 'processing_error.dart';
import 'recording_ids.dart';
import 'recordings_repository.dart';
import 'upload_descriptor.dart';

/// Best-effort delete of an on-disk audio file by path.
///
/// RETIRED on the `done` path (plan #46, W2 / #871): the queue NO LONGER deletes
/// the durable `audioFilePath` when an upload reaches `done` — see the retention
/// note in [_drainRow]. This typedef + the [UploadQueue.cleanupAudio] injection
/// seam are kept only so the now-retired behavior stays explicit and testable;
/// the live drain never invokes it. The real, EXPLICIT-USER deletion lives in
/// `DetailsController.delete` (file + row + Core).
typedef AudioCleanup = Future<void> Function(String audioFilePath);

/// Default [AudioCleanup]: best-effort delete of a finalized audio file by path.
/// Never throws. No longer wired into the confirmed-`done` path (W2 retention);
/// retained for the user-controlled delete affordance to reuse.
Future<void> deleteAudioFile(String audioFilePath) async {
  if (audioFilePath.isEmpty) return;
  AppLog.event(LogCat.upload, 'deleteAudioFile: $audioFilePath');
  try {
    final file = File(audioFilePath);
    if (await file.exists()) await file.delete();
  } catch (e, st) {
    AppLog.error(
      LogCat.upload,
      'deleteAudioFile: best-effort delete failed for $audioFilePath',
      e,
      st,
    );
    developer.log(
      'upload-queue audio cleanup failed',
      name: 'upload.queue',
      error: e,
    );
  }
}

/// Async, failure-tolerant uploader that drains legacy upload-work recording
/// rows. It runs on app/auth/lifecycle/config/network triggers and after local
/// capture while W2's canonical `work_queue` replacement is still pending.
///
/// For each row it reconciles the parent first, replays #2033's owner-scoped
/// idempotent item create for a fresh presign, then uploads, dispatches, awaits,
/// and applies the terminal result.
///
/// Failure policy (closing #828 end-to-end):
///  * Parent/Core/auth/transport hold ⇒ row stores an explicit `blocked_*`
///    status, audio stays durable, and the next trigger retries it.
///  * Terminal *processing* failure ⇒ row marked `failed` + reason persisted,
///    audio KEPT (a failed transcription is still re-inspectable; W5 surfaces
///    the reason). Not auto-retried (it is a real processing failure, not a
///    transport blip).
///  * Confirmed `done` ⇒ status reconciled, audio RETAINED (plan #46, W2 /
///    #871). The queue NEVER deletes a local file. `done` proves Core accepted
///    the upload, NOT that the user can retrieve + play a cloud copy, so the
///    local-first `audioFilePath` is the source of truth and persists until the
///    user explicitly deletes the recording. See the retention note in
///    [_drainRow].
///
/// Idempotency / single-flight:
///  * A row that already has a `coreId` replays the same permanent `client_id`;
///    Core returns the same item and a fresh upload descriptor.
///  * Concurrent drains of the same row are guarded by [_inFlight]; a second
///    trigger that arrives mid-drain is a no-op for that row.
class UploadQueue {
  UploadQueue(
    this._ref, {
    RecordingResultAwaiter awaitResult = liveRecordingResultAwaiter,
    this.cleanupAudio = deleteAudioFile,
  }) : _awaitTerminal = awaitResult;

  final Ref _ref;
  final RecordingResultAwaiter _awaitTerminal;

  /// RETIRED (plan #46, W2 / #871): formerly how a confirmed-`done` row's
  /// on-disk audio was dropped. The drain no longer invokes this — `done`
  /// retains the local file (see [_drainRow]). Kept as an injectable seam so the
  /// retired path stays explicit/testable; not read by the live drain.
  final AudioCleanup cleanupAudio;

  /// Local ids currently being drained — single-flight guard against concurrent
  /// triggers racing the same row (e.g. an app-start drain overlapping a
  /// connectivity-regained drain).
  final Set<String> _inFlight = <String>{};

  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);
  ItemsDao get _dao => _ref.read(itemsDaoProvider);
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  MatomesDao get _matomesDao => _ref.read(matomesDaoProvider);
  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);
  MatomeSyncService get _matomeSync => _ref.read(matomeSyncServiceProvider);

  /// Per-local-id hooks registered by callers that own recorder-session
  /// resources (the finish flow registers `service.discardSegmentPaths`).
  ///
  /// RETIRED on `done` (plan #46, W2 / #871): the hook is NO LONGER RUN when a
  /// row reaches confirmed `done` — running it would discard the snapshotted
  /// session segments, and with the single-file finish flow the durable
  /// `audioFilePath` IS one of those segments, so it would delete the
  /// local-first copy. The registration is now just dropped (not invoked) on
  /// `done`. Kept registerable so the seam stays explicit; entries are cleared
  /// to avoid an unbounded map. Keyed so a queued retry across app restarts
  /// (recorder session gone) simply has no hook.
  final Map<String, Future<void> Function()> _confirmHooks =
      <String, Future<void> Function()>{};

  /// Register a [hook] for [localId]. RETIRED on `done` (W2 / #871): the hook is
  /// no longer invoked when the row reaches `done` (see [_confirmHooks]) — the
  /// entry is simply cleared. Retained so the finish flow's registration
  /// compiles and the seam stays explicit.
  void onConfirmed(String localId, Future<void> Function() hook) {
    _confirmHooks[localId] = hook;
  }

  /// Drain every pending, blocked, or interrupted local upload row once.
  Future<void> drain() async {
    AppLog.event(LogCat.upload, 'drain: start');
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    final List<ItemWithPayload> pending;
    try {
      pending = await _dao.listPendingUploads(ownerId);
    } catch (e, st) {
      AppLog.error(LogCat.upload, 'drain: could not read pending rows', e, st);
      developer.log(
        'upload-queue could not read pending rows',
        name: 'upload.queue',
        error: e,
      );
      return;
    }
    AppLog.event(LogCat.upload, 'drain: ${pending.length} pending rows');
    // Sequential drain: keeps Core load modest and avoids interleaving socket
    // waiters. Single-flight still guards the same row across overlapping calls.
    for (final row in pending) {
      await drainRow(row.id);
    }
  }

  /// Drain a single row by its local id. Idempotent + single-flight: a row that
  /// is mid-drain, terminal, or missing is a no-op.
  Future<void> drainRow(String localId) async {
    if (_inFlight.contains(localId)) return;
    AppLog.event(LogCat.upload, 'drainRow: $localId');
    _inFlight.add(localId);
    try {
      final ownerId = _ref.read(currentOwnerIdProvider);
      if (ownerId == null) return;
      final row = await _dao.getById(localId, ownerId);
      if (row == null) return;
      // A locally-minted `processing` row is resumable: the app may have died
      // after reconciling its Core id but before upload/enqueue completed.
      final resumableProcessing =
          row.processingStatus == 'processing' &&
          row.coreId != null &&
          isLocalRecordingId(row.id);
      if (!isUploadQueuePendingStatus(row.processingStatus) &&
          !resumableProcessing) {
        return;
      }
      // W0 parent rule: an Inbox Matome may be created without a workspace, but
      // a missing parent or explicitly local Space is durably blocked. Cloud
      // policy still routes through SyncPolicy when the feature is enabled.
      final blocked = await _syncBlockReason(row);
      if (blocked != null) {
        AppLog.event(LogCat.upload, 'drainRow: HELD ($blocked) $localId');
        await _markBlocked(localId, blocked);
        return;
      }
      await _drainRow(row);
    } finally {
      _inFlight.remove(localId);
    }
  }

  /// Returns a durable block status, or null when the row may advance. W0 permits
  /// an Inbox Matome parent with no Space, requires a parent for every child,
  /// and holds explicit local/unknown Spaces. Cloud decisions continue through
  /// [EffectiveSpace] and [SyncPolicy.can].
  Future<String?> _syncBlockReason(ItemWithPayload row) async {
    // matome WINS: if the row is in a matome, the matome's space_id is the
    // authoritative effective space and the row's own workspaceId is shadowed.
    final matomeId = row.matomeId;
    if (matomeId == null) return kProcessingStatusBlockedParent;
    final matome = await _matomesDao.getById(matomeId);
    if (matome == null) return kProcessingStatusBlockedParent;
    final matomeSpaceId = matome.spaceId;

    // W0 parent work may create an Inbox Matome on Core without a workspace.
    // A Matome explicitly filed into a local/unknown Space must never egress.
    if (matomeSpaceId == null) return null;
    final membership = ItemMembership(
      matomeSpaceId: matomeSpaceId,
      workspaceId: row.workspaceId,
    );
    final spaceId = EffectiveSpace.effectiveSpaceId(membership);
    if (spaceId == null) return null;

    final spaceRow = await _workspacesDao.getWorkspaceById(spaceId);
    // Fail-closed: an effective space id with no known `workspaces` row is
    // treated as not-syncable (never silently uploaded).
    if (spaceRow == null || spaceRow.isLocal == 1) {
      return kProcessingStatusBlockedLocalSpace;
    }

    if (FeatureFlags.localFirstSpaces &&
        !SyncPolicy.can(
          currentCaller(_ref),
          Operation.spaceSync,
          spaceRefFromRow(spaceRow),
        )) {
      return kProcessingStatusBlockedLocalSpace;
    }
    return null;
  }

  Future<void> _drainRow(ItemWithPayload row) async {
    final localId = row.id;

    // Resume point: a row may already carry a Core id from a prior attempt.
    // Replaying its permanent client id is idempotent and refreshes the presign.
    final localMatomeId = row.matomeId;
    if (localMatomeId == null) {
      await _markBlocked(localId, kProcessingStatusBlockedParent);
      return;
    }

    int? coreMatomeId = (await _matomesDao.getById(localMatomeId))?.coreId;
    if (coreMatomeId == null) {
      try {
        coreMatomeId = await _matomeSync.reconcileParent(localMatomeId);
      } catch (e, st) {
        AppLog.error(
          LogCat.upload,
          '_drainRow: parent reconcile failed $localId',
          e,
          st,
        );
        await _markBlocked(localId, _blockedStatusFor(e));
        return;
      }
      if (coreMatomeId == null) {
        await _markBlocked(localId, kProcessingStatusBlockedParent);
        return;
      }
    }

    // Replay the permanent client id on every non-terminal attempt. #2033 makes
    // this idempotent and returns a fresh upload descriptor, so a restart after
    // item reconcile, PUT, or dispatch can safely resume without duplicate work.
    final localPath = row.localPath;
    if (localPath == null || localPath.isEmpty) {
      await _markBlocked(localId, kProcessingStatusBlockedCore);
      return;
    }
    final contentLength = await _byteSizeOf(localPath);
    final RecordingCreateResult created;
    try {
      created = await _repo.createItemRecording(
        title: row.title,
        matomeId: coreMatomeId,
        clientId: localId,
        durationSeconds: _durationSecondsFor(row),
        mediaType: row.mediaType,
        contentLength: contentLength,
      );
    } catch (e, st) {
      AppLog.error(
        LogCat.upload,
        '_drainRow: createRecording failed (retry later) $localId',
        e,
        st,
      );
      await _markBlocked(localId, _blockedStatusFor(e));
      return;
    }
    final recording = created.recording;
    final coreId = recording.id;
    if (row.coreId != null && row.coreId != coreId) {
      await _markBlocked(localId, kProcessingStatusBlockedCore);
      return;
    }
    await _inbox.reconcileCoreId(localId, coreId);

    try {
      try {
        await _repo.uploadFile(created.upload, File(localPath));
      } catch (_) {
        await _inbox.markFileUploadFailed(localId);
        rethrow;
      }
      await _inbox.markFileUploaded(localId);
      await _repo.enqueueProcessing(coreId);
      final result = await _awaitTerminal(
        recording: recording,
        poll: () => _repo.fetchRecording(coreId),
        ref: _ref,
      );
      final done = result.recording;
      await _inbox.applyUploadResult(
        localId,
        failed: result.failed,
        summary: done?.summary,
        // WRITE-AUTHORITY (#1435): route the machine transcript to the
        // `transcript` column — the previous `notes: done?.transcript` alias
        // overwrote any user note on every `done`.
        transcript: done?.transcript,
        errorCode: result.failed
            ? processingErrorCodeForTerminal(result.errorReason)
            : null,
      );
      // RETENTION (plan #46, W2 / #871): reaching a confirmed `done` MUST NOT
      // delete any local file. This intentionally REVERSES the #43 W4 decision
      // that dropped the on-disk audio here.
      //
      // Why `done` no longer deletes:
      //  * LOCAL-FIRST source of truth — the row's durable `audioFilePath` is the
      //    canonical copy. A reconciled `done` proves Core ACCEPTED the upload; it
      //    does NOT prove the user can retrieve + PLAY a cloud copy on demand
      //    (verified: coreId=11 reached `done` yet its `import_*.wav` was gone and
      //    the recording was unplayable). `done` ≠ proof of a playable cloud copy.
      //  * The USER decides whether the local copy is freed — deletion is now an
      //    explicit user action only (Details delete → DetailsController.delete,
      //    which removes the file + row + Core). The queue never auto-evicts.
      //
      // The confirm hook (segment/draft discard) is likewise NOT run on `done`:
      // with the single-file finish flow the durable `audioFilePath` IS one of the
      // snapshotted session segments, so discarding them would delete the durable
      // copy too. Segment/draft sweeping still happens on the interactive
      // cancel/discard paths (cancelRecording / discardSegments) and on stale
      // crash-recovery drafts (detectRecoverableDraft) — i.e. files with NO
      // durable DB row, the original #828 orphan-WAV concern, remain sweepable.
      //
      // FOLLOW-UP (storage growth): local audio now accumulates for the life of
      // the row. A future user-facing "free up space" / cache-eviction policy
      // should let the user reclaim disk for already-synced recordings. Do NOT
      // auto-evict here — that reintroduces exactly the data-loss this reverses.
      _confirmHooks.remove(localId);
    } on ApiException catch (e, st) {
      AppLog.error(
        LogCat.upload,
        '_drainRow: retryable Core failure $localId',
        e,
        st,
      );
      await _markBlocked(localId, _blockedStatusFor(e));
    } catch (e, st) {
      // Terminal processing failure (the row already carries a coreId, so this
      // is a genuine post-create failure, not "Core unreachable"). Persist only
      // a bounded app-owned code and KEEP the audio for inspection / retry.
      // Raw exception text remains in developer logs and never reaches Drift.
      AppLog.error(
        LogCat.upload,
        '_drainRow: terminal processing failure $localId',
        e,
        st,
      );
      developer.log(
        'upload-queue terminal failure',
        name: 'upload.queue',
        error: e,
      );
      await _inbox.applyUploadResult(
        localId,
        failed: true,
        errorCode: kProcessingErrorUploadFailed,
      );
    }
  }

  Future<void> _markBlocked(String localId, String status) async {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    await _dao.updateItem(
      localId,
      ownerId,
      ItemsCompanion(syncState: Value(status), isDirty: const Value(true)),
    );
    await _inbox.reloadFromLocal();
  }

  static String _blockedStatusFor(Object error) {
    if (error is ApiException) {
      if (error.isUnauthorized) return kProcessingStatusBlockedSignedOut;
      if (error.statusCode == null) return kProcessingStatusBlockedOffline;
    }
    return kProcessingStatusBlockedCore;
  }

  /// Best-effort re-derive the duration (seconds) for a Core create from the
  /// row's `m:ss`-style duration TEXT. Unknown ⇒ 0 (the file-picker path also
  /// uploads with an unknown duration), so this never blocks a drain.
  int _durationSecondsFor(ItemWithPayload row) => row.durationSeconds ?? 0;

  /// Best-effort on-disk size in bytes of [path] (#1471), or null if the file is
  /// absent/unreadable. Declared as `content_length` on create so Core persists
  /// `byte_size` for the Files view; never throws (a real upload failure surfaces
  /// later on the actual PUT, not here).
  Future<int?> _byteSizeOf(String path) async {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.length();
    } catch (_) {
      return null;
    }
  }
}

final uploadQueueProvider = Provider<UploadQueue>((ref) => UploadQueue(ref));
