import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../../i18n/strings.g.dart';
import '../home/inbox_controller.dart';
import '../home/inbox_upload.dart';
import 'recording.dart';
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

/// Async, failure-tolerant uploader that drains `pending_upload` recording rows
/// (plan #43, W4). This lifts the W2 inline `_bestEffortCore` best-effort
/// handoff into a reusable, row-driven, single-flight service so it can run on
/// three triggers — app start, after a finish(), and on connectivity regained —
/// rather than only once inline at upload time.
///
/// For each `pending_upload` row it runs the same W2/W3 pipeline:
///   createRecording → reconcileCoreId → uploadFile → enqueueProcessing →
///   await terminal → applyUploadResult.
///
/// Failure policy (closing #828 end-to-end):
///  * Core create/transport failure ⇒ row stays `pending_upload`, audio kept,
///    queue retries on the next trigger. NEVER throws out of [drain].
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
///  * A row that already has a `coreId` is never re-created on Core — the queue
///    resumes from upload/await for it.
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
  RecordingsDao get _dao => _ref.read(recordingsDaoProvider);
  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);

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

  /// Drain every `pending_upload` row. Safe to call repeatedly; never throws.
  /// Returns when all currently-pending rows have been attempted once.
  Future<void> drain() async {
    AppLog.event(LogCat.upload, 'drain: start');
    final List<RecordingRow> pending;
    try {
      pending = await _dao.getPendingUploadRecordings();
    } catch (e, st) {
      AppLog.error(
        LogCat.upload,
        'drain: could not read pending rows',
        e,
        st,
      );
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
  /// is mid-drain, no longer `pending_upload`, or missing is a no-op.
  Future<void> drainRow(String localId) async {
    if (_inFlight.contains(localId)) return;
    AppLog.event(LogCat.upload, 'drainRow: $localId');
    _inFlight.add(localId);
    try {
      final row = await _dao.getRecordingById(localId);
      if (row == null) return;
      // Only `pending_upload` rows are drainable. A row that already reconciled
      // to processing/done/failed is intentionally skipped (idempotency).
      if (row.processingStatus != kProcessingStatusPendingUpload) return;
      await _drainRow(row);
    } finally {
      _inFlight.remove(localId);
    }
  }

  Future<void> _drainRow(RecordingRow row) async {
    final localId = row.id;

    // Resume point: a row may already carry a coreId from a prior attempt that
    // created on Core but failed mid upload/await. NEVER double-create in that
    // case — pick up from upload/enqueue with the known coreId.
    int? coreId = row.coreId;
    Recording recording;
    UploadDescriptor? upload;

    if (coreId == null) {
      final RecordingCreateResult created;
      try {
        created = await _repo.createRecording(
          title: row.title,
          durationSeconds: _durationSecondsFor(row),
          mediaType: row.mediaType,
        );
      } catch (e, st) {
        AppLog.error(
          LogCat.upload,
          '_drainRow: createRecording failed (retry later) $localId',
          e,
          st,
        );
        // Core unreachable / rejected — retryable transport state. Leave the
        // row pending_upload + audio on disk; the next trigger retries.
        return;
      }
      recording = created.recording;
      upload = created.upload;
      coreId = recording.id;
      // Reconcile the Core id into the row (keeps the local PK), flipping
      // pending_upload → processing so a concurrent trigger won't re-create.
      await _inbox.reconcileCoreId(localId, coreId);
    } else {
      // Resume: row already reconciled a coreId but is still pending_upload —
      // re-fetch the Core recording so we can re-run upload/enqueue/await.
      // (This branch is defensive; reconcileCoreId already flips status to
      // processing, so a coreId + pending_upload pairing is rare.)
      final fetched = await _safeFetch(coreId);
      if (fetched == null) return; // Core unreachable — retry later, audio kept.
      recording = fetched;
      // The row was created on Core but may never have been enqueued for
      // processing (a prior attempt died between create and enqueue). Without
      // this, the await below has nothing to wait FOR and dead-waits the full
      // ~10-min timeout before marking the row failed. POST /process is
      // server-side idempotent, so re-enqueueing an already-queued recording is
      // safe. Best-effort: if the recording already progressed (or Core blips),
      // the await still resolves the real terminal state — never block it.
      try {
        await _repo.enqueueProcessing(coreId);
      } catch (e, st) {
        AppLog.error(
          LogCat.upload,
          '_drainRow: resume re-enqueue best-effort failed $localId',
          e,
          st,
        );
        developer.log(
          'upload-queue resume re-enqueue best-effort failed',
          name: 'upload.queue',
          error: e,
        );
      }
    }

    try {
      // Re-upload only when we hold a fresh presign from this attempt's create.
      // (A resumed row without a presign cannot re-PUT; it falls through to
      // await the terminal result of whatever Core already has.)
      if (upload != null) {
        await _repo.uploadFile(upload, File(row.audioFilePath));
        await _repo.enqueueProcessing(coreId);
      }
      final result = await _awaitTerminal(
        recording: recording,
        poll: () => _repo.fetchRecording(coreId!),
        ref: _ref,
      );
      final done = result.recording;
      await _inbox.applyUploadResult(
        localId,
        failed: result.failed,
        summary: done?.summary,
        notes: done?.transcript,
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
    } catch (e, st) {
      // Terminal processing failure (the row already carries a coreId, so this
      // is a genuine post-create failure, not "Core unreachable"). Persist a
      // SANITIZED reason and KEEP the audio for inspection / a manual retry.
      //
      // `errorReason` lands in the `notes` column (no dedicated error column),
      // which is rendered in Details AND PATCHable up to Core as transcript —
      // so raw `error.toString()` / an arbitrary transport message must NEVER
      // reach it. We persist a curated string and keep the full detail in the
      // developer log only.
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
        errorReason: _sanitizeFailureReason(e),
      );
    }
  }

  /// Map a drain failure to a SAFE, user-visible reason for the `notes` column.
  ///
  /// Only a curated [ApiException.message] for a KNOWN [ApiException.code] is
  /// whitelisted through (those messages are app-authored, not raw transport
  /// text). Everything else — an ApiException with no/unknown code, or any
  /// non-ApiException — collapses to a generic localized string. Never returns
  /// `error.toString()`. Full detail stays in `developer.log` (logged above).
  static String _sanitizeFailureReason(Object error) {
    if (error is ApiException) {
      final code = error.code;
      if (code != null &&
          _knownErrorCodes.contains(code) &&
          error.message.isNotEmpty) {
        return error.message;
      }
    }
    return t.cardStatus.failed;
  }

  /// Backend/app error slugs whose [ApiException.message] is curated and safe to
  /// surface in `notes`. Kept narrow on purpose — anything not listed here gets
  /// the generic fallback rather than leaking raw text into a Core-synced field.
  static const Set<String> _knownErrorCodes = <String>{
    'unauthorized',
    'upload_failed',
    'malformed_response',
  };

  Future<Recording?> _safeFetch(int coreId) async {
    try {
      return await _repo.fetchRecording(coreId);
    } catch (e, st) {
      AppLog.error(
        LogCat.upload,
        '_safeFetch: fetchRecording failed for coreId=$coreId',
        e,
        st,
      );
      return null;
    }
  }

  /// Best-effort re-derive the duration (seconds) for a Core create from the
  /// row's `m:ss`-style duration TEXT. Unknown ⇒ 0 (the file-picker path also
  /// uploads with an unknown duration), so this never blocks a drain.
  int _durationSecondsFor(RecordingRow row) {
    final text = row.duration.trim();
    if (text.isEmpty) return 0;
    var total = 0;
    final mins = RegExp(r'(\d+)\s*m').firstMatch(text);
    final secs = RegExp(r'(\d+)\s*s').firstMatch(text);
    if (mins != null) total += (int.tryParse(mins.group(1)!) ?? 0) * 60;
    if (secs != null) total += int.tryParse(secs.group(1)!) ?? 0;
    return total;
  }
}

final uploadQueueProvider =
    Provider<UploadQueue>((ref) => UploadQueue(ref));
