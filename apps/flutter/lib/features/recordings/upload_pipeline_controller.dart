import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import 'recording.dart';
import 'recording_progress.dart';
import 'recording_result_waiter.dart';
import 'recording_status_socket.dart';
import 'recordings_repository.dart';

/// Drives the F4 upload + realtime-result pipeline and exposes per-recording
/// [RecordingProgress] keyed by recording id.
///
/// Flow for [run]:
///  1. `POST /api/recordings` -> recording + presign (phase: uploading).
///  2. Stream the file to the presigned URL.
///  3. `POST /api/recordings/{id}/process` (phase: processing).
///  4. Race the `recording:status` channel against a 2s poll until
///     done/failed, with a 10-minute timeout.
class UploadPipelineController
    extends StateNotifier<Map<int, RecordingProgress>> {
  UploadPipelineController(this._ref) : super(const {});

  final Ref _ref;

  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);

  /// Progress for a single recording id (defaults to idle).
  RecordingProgress progressFor(int id) =>
      state[id] ?? RecordingProgress.idle;

  void _put(int id, RecordingProgress progress) {
    state = {...state, id: progress};
  }

  /// Runs the full pipeline for [file]. Resolves with the final [Recording]
  /// (status `done`) or throws on failure/timeout.
  Future<Recording> run({
    required File file,
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
  }) async {
    // 1. Create + presign.
    final created = await _repo.createRecording(
      title: title,
      durationSeconds: durationSeconds,
      badge: badge,
      mediaType: mediaType,
      workspaceId: workspaceId,
    );
    final recording = created.recording;
    final id = recording.id;
    _put(
      id,
      RecordingProgress(
        phase: RecordingPhase.uploading,
        recordingId: id,
        recording: recording,
      ),
    );

    // 2. Stream-upload to the presigned URL.
    try {
      await _repo.uploadFile(created.upload, file);
    } catch (error) {
      _put(
        id,
        RecordingProgress(
          phase: RecordingPhase.failed,
          recordingId: id,
          recording: recording,
          errorReason: 'upload_failed',
        ),
      );
      rethrow;
    }

    // 3. Enqueue processing.
    _put(id, progressFor(id).copyWith(phase: RecordingPhase.processing));
    await _repo.enqueueProcessing(id);

    // 4. Await result (socket primary, poll fallback).
    return _awaitResult(recording);
  }

  Future<Recording> _awaitResult(Recording recording) async {
    final id = recording.id;
    final socket = RecordingStatusSocket(
      apiBaseUrl: AppConfig.apiBaseUrl,
      tokenStore: _ref.read(tokenStoreProvider),
      ownerId: recording.ownerId,
    );

    RecordingResultWaiter? waiter;
    try {
      // Best-effort connect+join; if it throws/never emits, the poll loop
      // still resolves the pipeline.
      try {
        await socket.connectAndJoin();
      } catch (_) {
        // Socket unavailable — poll fallback takes over.
      }

      waiter = RecordingResultWaiter(
        recordingId: id,
        statusEvents: socket.events,
        poll: () => _repo.fetchRecording(id),
      );

      final result = await waiter.wait();
      if (result.failed) {
        _put(
          id,
          RecordingProgress(
            phase: RecordingPhase.failed,
            recordingId: id,
            recording: result.recording ?? recording,
            errorReason: result.errorReason,
          ),
        );
        throw StateError(
          'Recording $id failed: ${result.errorReason ?? 'unknown'}',
        );
      }
      final done = result.recording ?? recording;
      _put(
        id,
        RecordingProgress(
          phase: RecordingPhase.done,
          recordingId: id,
          recording: done,
        ),
      );
      return done;
    } finally {
      waiter?.cancel();
      await socket.dispose();
    }
  }
}

final uploadPipelineControllerProvider = StateNotifierProvider<
    UploadPipelineController, Map<int, RecordingProgress>>(
  (ref) => UploadPipelineController(ref),
);
