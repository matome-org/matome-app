import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/inbox_upload.dart';
import 'audio_recording_service.dart';
import 'recording_controller.dart';

/// Orchestrates the S3 Finish flow, wiring F3 (audio finalize) → S1/F4 (Inbox
/// upload pipeline). Kept separate from the modal widget so it is unit-testable
/// with a fake recorder backend + a stubbed repository.
///
/// Finish sequence (mirrors apps/mobile `RecordingScreen.handleFinish`):
///  1. F3 [RecordingController.finish] stops the live recorder and resolves the
///     single continuous session file (path).
///  2. [InboxUploader.upload] creates the Core recording, inserts the local
///     Drift row as `processing` (so the Inbox card shows immediately), streams
///     the file to the presigned URL, enqueues processing, awaits the terminal
///     result and reconciles it back into the Drift row (processing → done).
///  3. F3 [AudioRecordingService.discardSegments] cleans the on-disk segment
///     files + the crash-recovery draft (the audio now lives in Core/S3).
class RecordingFinisher {
  RecordingFinisher(this._ref);

  final Ref _ref;

  RecordingController get _controller =>
      _ref.read(recordingControllerProvider.notifier);
  AudioRecordingService get _service =>
      _ref.read(audioRecordingServiceProvider);
  InboxUploader get _uploader => _ref.read(inboxUploaderProvider);

  /// Finalize + upload the current session. Returns the local Drift id
  /// (== stringified Core recording id) on success. Throws on failure so the
  /// modal can revert to the `paused` phase and surface an error.
  Future<String> finish({String? title}) async {
    // 1. F3 finalizes the single session file.
    final path = await _controller.finish();
    final durationSeconds = _ref.read(recordingControllerProvider).durationSeconds;

    // 2. S1/F4 pipeline: create Core + local Drift row + upload + enqueue +
    //    await + reconcile.
    final localId = await _uploader.upload(
      PickedUpload(
        file: File(path),
        title: title ?? AudioRecordingService.generateTitle(null),
        mediaType: 'audio',
      ),
      durationSeconds: durationSeconds.round(),
    );

    // 3. Privacy cleanup — the audio now lives in Core/S3; drop local segment
    //    files + the crash-recovery draft.
    await _service.discardSegments();

    return localId;
  }
}

/// Provider for the S3 Finish orchestrator.
final recordingFinisherProvider =
    Provider<RecordingFinisher>((ref) => RecordingFinisher(ref));
