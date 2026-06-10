import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/inbox_upload.dart';
import 'audio_recording_service.dart';
import 'meeting_recorder.dart';
import 'recording_controller.dart';

/// Orchestrates the S3 Finish flow, wiring F3 (audio finalize) → S1/F4 (Inbox
/// upload pipeline). Kept separate from the modal widget so it is unit-testable
/// with a fake recorder backend + a stubbed repository.
///
/// Finish sequence — LOCAL-FIRST (plan #43, W2):
///  1. F3 [RecordingController.finish] stops the live recorder and resolves the
///     single continuous session file (a durable copy already living in the app
///     documents dir — see [AudioRecordingService.stopRecording]).
///  2. [InboxUploader.upload] inserts the local Drift row FIRST
///     (`rec_local_<uuid>`, `pending_upload`, audio path on disk) so the Inbox
///     card shows immediately regardless of Core, THEN best-effort uploads to
///     Core and reconciles `coreId` / done back into the same row.
///
/// The crash-recovery segments are deliberately NOT discarded here: that was the
/// root of #828 (orphan-WAV — a Core failure wiped the only on-disk copy with no
/// local row). The audio must outlive a Core failure so it can be retried.
///
/// W2 (#46 / #871): the upload queue no longer deletes the local audio when a
/// row reaches confirmed `done` — the durable `audioFilePath` is the canonical
/// local-first copy and is RETAINED until the user explicitly deletes it. So the
/// old W4 confirm hook (`service.discardSegmentPaths(snapshot)`) that dropped the
/// finalized audio + draft on `done` is retired and NOT registered here.
///
/// finish() instead clears ONLY the crash-recovery DRAFT row (via
/// [AudioRecordingService.clearDraft]) once the session is finalized and persisted
/// local-first — WITHOUT deleting any segment file (W2 retention holds; the audio
/// stays). This is the split that fixes the stale-draft "recover an already-saved
/// recording" prompt: the draft no longer outlives a confirmed finish, but the
/// durable audio does. A Core failure still leaves the audio on disk for the
/// queue to retry; only the in-progress draft is cleared.
class RecordingFinisher {
  RecordingFinisher(
    this._ref, {
    StateNotifierProvider<RecordingController, RecordingState>?
        controllerProvider,
    Provider<AudioRecordingService>? serviceProvider,
  })  : _controllerProvider =
            controllerProvider ?? recordingControllerProvider,
        _serviceProvider = serviceProvider ?? audioRecordingServiceProvider;

  final Ref _ref;

  /// Which recorder this finisher drives — the mic recorder by default, or the
  /// meeting (loopback) recorder when constructed for the meeting flow. Both
  /// share the same single-file finalize → F4 upload pipeline below.
  final StateNotifierProvider<RecordingController, RecordingState>
      _controllerProvider;
  final Provider<AudioRecordingService> _serviceProvider;

  RecordingController get _controller =>
      _ref.read(_controllerProvider.notifier);

  /// The audio service backing this finisher (mic or meeting). [finish] calls
  /// [AudioRecordingService.clearDraft] through this to drop the crash-recovery
  /// draft row once the session is finalized + persisted — WITHOUT deleting any
  /// segment file (W2 retention).
  AudioRecordingService get service => _ref.read(_serviceProvider);
  InboxUploader get _uploader => _ref.read(inboxUploaderProvider);

  /// Finalize + persist the current session, local-first. Returns the **local**
  /// Drift id (`rec_local_<uuid>`).
  ///
  /// W2 contract change: the returned id is the local UUID id, NOT the Core id
  /// (the Core id, once known, lives in the row's `coreId` column). Today's
  /// callers (the recording modal `_finish`) only await this future and discard
  /// the id, so this is safe; flagged for W3 which swaps the `int.tryParse(id)`
  /// call sites to read `coreId`.
  ///
  /// [InboxUploader.upload] persists the local row before any Core call and is
  /// tolerant of a Core failure, so finish() no longer throws on an unreachable
  /// Core — the row + audio survive in `pending_upload` for W4's retry queue.
  Future<String> finish({String? title}) async {
    // 1. F3 finalizes the single session file into a durable documents-dir copy.
    final path = await _controller.finish();
    final durationSeconds = _ref.read(_controllerProvider).durationSeconds;

    // Snapshot the service so the post-persist draft-clear targets THIS
    // finisher's recorder (mic vs meeting) rather than re-reading later.
    final audioService = service;

    // Snapshot THIS session's segment + draft paths NOW (at finish), before the
    // upload await: the draft-clear below only drops the draft if it STILL
    // describes this snapshot, so a back-to-back session B that starts and saves
    // its own draft during a slow upload keeps its crash-recovery draft.
    final sessionPaths = await audioService.snapshotSessionCleanupPaths();

    // 2. Local-first persist + queued upload. The local row + on-disk audio
    //    survive even if Core never answers; the queue retries a failed upload
    //    and RETAINS the local audio on a confirmed `done` (#46 W2 / #871 — the
    //    durable `audioFilePath` is the canonical copy until the user deletes it).
    final localId = await _uploader.upload(
      PickedUpload(
        file: File(path),
        title: title ?? AudioRecordingService.generateTitle(null),
        mediaType: 'audio',
      ),
      durationSeconds: durationSeconds.round(),
    );

    // 3. The session is finalized + persisted local-first → clear the crash-
    //    recovery DRAFT row so a future launch does NOT prompt to "recover" this
    //    already-saved recording. This is split from file-deletion: the segment
    //    files (one of which IS the durable `audioFilePath`) STAY on disk (W2
    //    retention). Scoped to this session's snapshot so a back-to-back B's
    //    draft survives. Best-effort inside — never regresses the finish.
    await audioService.clearDraftForSession(sessionPaths);

    return localId;
  }
}

/// Provider for the S3 Finish orchestrator (mic recorder).
final recordingFinisherProvider =
    Provider<RecordingFinisher>((ref) => RecordingFinisher(ref));

/// Finish orchestrator for the **meeting (loopback) recorder** — same F4 upload
/// pipeline, wired to the meeting controller/service so the captured WAV flows
/// through `InboxUploader` unchanged (zero backend change).
final meetingRecordingFinisherProvider = Provider<RecordingFinisher>(
  (ref) => RecordingFinisher(
    ref,
    controllerProvider: meetingRecordingControllerProvider,
    serviceProvider: meetingRecordingServiceProvider,
  ),
);
