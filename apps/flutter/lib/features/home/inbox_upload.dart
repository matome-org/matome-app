import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/db/app_database.dart';
import '../../core/http/api_exception.dart';
import '../../core/providers.dart';
import '../recordings/recording.dart';
import '../recordings/recording_result_waiter.dart';
import '../recordings/recording_status_socket.dart';
import '../recordings/recordings_repository.dart';
import 'inbox_controller.dart';
import 'inbox_sync.dart';

/// Awaits a recording's terminal result by racing the `recording:status`
/// socket against a periodic poll. Injectable so the finish/upload flow can be
/// unit-tested without a live Phoenix socket.
///
/// The default ([liveRecordingResultAwaiter]) connects a [RecordingStatusSocket]
/// for the recording's owner (primary path) and falls back to polling
/// `GET /api/recordings/{id}` via [poll] when the socket is unavailable or
/// never emits — mirroring apps/mobile `coreRecordingService`.
typedef RecordingResultAwaiter = Future<RecordingResult> Function({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
});

/// Picked file ready to upload through the Inbox upload flow.
class PickedUpload {
  const PickedUpload({
    required this.file,
    required this.title,
    required this.mediaType,
  });

  final File file;
  final String title;

  /// `audio` / `image` / `document`, derived from the picked file extension.
  final String mediaType;
}

/// Resolves a coarse media type from a file path extension, mirroring the
/// audio/image/doc buckets apps/mobile uploadRecordingService uses.
String mediaTypeForPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  const audio = {'m4a', 'mp3', 'wav', 'aac', 'ogg', 'flac', 'caf', 'webm'};
  const image = {'png', 'jpg', 'jpeg', 'gif', 'heic', 'webp'};
  if (audio.contains(ext)) return 'audio';
  if (image.contains(ext)) return 'image';
  return 'document';
}

/// Orchestrates an Inbox file upload (S1, #780), porting apps/mobile
/// uploadRecordingService.uploadPickedRecording:
///
///  1. `POST /api/recordings` (create + presign) via the F4 pipeline.
///  2. Insert a local Drift row immediately (status processing) so the card
///     shows up before Core finishes — reconciling the Core int id to the
///     local TEXT primary key.
///  3. Stream-upload + enqueue + await result through the F4 pipeline.
///  4. Apply the terminal (done/failed) outcome back to the local row.
///
/// The Core id<->local id reconciliation is centralised in [inbox_sync].
class InboxUploader {
  InboxUploader(
    this._ref, {
    RecordingResultAwaiter awaitResult = liveRecordingResultAwaiter,
  }) : _awaitTerminal = awaitResult;

  final Ref _ref;

  /// Races the realtime socket against a poll fallback for the terminal result.
  /// Defaults to [liveRecordingResultAwaiter]; injected in tests.
  final RecordingResultAwaiter _awaitTerminal;

  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);
  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);

  /// Runs the full upload for [picked]: create + presign, insert the local
  /// Drift row immediately (processing), stream-upload, enqueue processing,
  /// then await the terminal result and reconcile it into the local row.
  ///
  /// [durationSeconds] is the known audio length (seconds) for a captured
  /// recording; the Inbox file-picker path leaves it 0 (unknown).
  ///
  /// Returns the created Core recording id (stringified, == local Drift id).
  Future<String> upload(PickedUpload picked, {int durationSeconds = 0}) async {
    // 1. Create + presign on Core.
    final created = await _repo.createRecording(
      title: picked.title,
      durationSeconds: durationSeconds,
      mediaType: picked.mediaType,
    );
    final recording = created.recording;
    final localId = coreIdToLocalId(recording.id);

    // 2. Insert the local row immediately as processing so the card appears
    //    in the Inbox before Core finishes.
    await _inbox.insertLocalUpload(
      _pendingCompanion(recording, picked, durationSeconds),
    );

    // 3 + 4. Upload + enqueue + await result, then reconcile the local row.
    try {
      await _repo.uploadFile(created.upload, picked.file);
      await _repo.enqueueProcessing(recording.id);
      // F4 realtime: socket `recording:status` primary, 2s poll fallback,
      // 10-min timeout. First terminal signal from either source wins.
      final result = await _awaitTerminal(
        recording: recording,
        poll: () => _repo.fetchRecording(recording.id),
        ref: _ref,
      );
      final done = result.recording;
      await _inbox.applyUploadResult(
        localId,
        failed: result.failed,
        summary: done?.summary,
        notes: done?.transcript,
      );
    } catch (error) {
      // Persist a real reason on terminal failure instead of a bare "failed":
      // an ApiException carries a friendly message; anything else falls back to
      // its toString so the failed card is diagnosable.
      final reason =
          error is ApiException ? error.message : error.toString();
      await _inbox.applyUploadResult(
        localId,
        failed: true,
        errorReason: reason,
      );
    }

    return localId;
  }

  RecordingsCompanion _pendingCompanion(
    Recording recording,
    PickedUpload picked,
    int durationSeconds,
  ) {
    final now = DateTime.now();
    return RecordingsCompanion(
      id: Value(coreIdToLocalId(recording.id)),
      title: Value(picked.title),
      timestamp: Value(formatClock(now)),
      duration: Value(formatDurationText(durationSeconds)),
      badge: const Value('Inbox'),
      isProcessing: const Value(1),
      audioFilePath: Value(picked.file.path),
      createdAt: Value(now.millisecondsSinceEpoch),
      mediaType: Value(picked.mediaType),
      processingStatus: const Value('processing'),
    );
  }
}

/// Default [RecordingResultAwaiter]: connects the `recording:status` socket for
/// [recording]'s owner (primary) and races it against [poll] (fallback) via a
/// [RecordingResultWaiter]. The socket is best-effort — if connect/join throws
/// or it never emits, the poll loop still resolves the pipeline.
Future<RecordingResult> liveRecordingResultAwaiter({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
}) async {
  final socket = RecordingStatusSocket(
    apiBaseUrl: AppConfig.apiBaseUrl,
    tokenStore: ref.read(tokenStoreProvider),
    ownerId: recording.ownerId,
  );

  RecordingResultWaiter? waiter;
  try {
    try {
      await socket.connectAndJoin();
    } catch (_) {
      // Socket unavailable — the poll fallback takes over.
    }

    waiter = RecordingResultWaiter(
      recordingId: recording.id,
      statusEvents: socket.events,
      poll: poll,
    );
    return await waiter.wait();
  } finally {
    waiter?.cancel();
    await socket.dispose();
  }
}

final inboxUploaderProvider =
    Provider<InboxUploader>((ref) => InboxUploader(ref));
