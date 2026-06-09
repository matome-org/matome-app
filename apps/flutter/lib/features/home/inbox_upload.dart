import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../recordings/recording.dart';
import '../recordings/recordings_repository.dart';
import 'inbox_controller.dart';
import 'inbox_sync.dart';

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
  InboxUploader(this._ref);

  final Ref _ref;

  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);
  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);

  /// Polls Core until the recording reaches a terminal state. Returns the last
  /// known recording (or the seed) on timeout. Overridable in tests.
  static const Duration pollInterval = Duration(seconds: 2);
  static const Duration pollTimeout = Duration(minutes: 10);

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
      final done = await _awaitResult(recording);
      await _inbox.applyUploadResult(
        localId,
        failed: done.status == RecordingStatus.failed,
        summary: done.summary,
        notes: done.transcript,
      );
    } catch (_) {
      await _inbox.applyUploadResult(localId, failed: true);
    }

    return localId;
  }

  /// Polls `GET /api/recordings/{id}` until the status is terminal, the F4
  /// status socket being the (separate) realtime channel used by the recording
  /// flow. Polling here keeps the import flow resilient when the socket is down.
  Future<Recording> _awaitResult(Recording seed) async {
    final deadline = DateTime.now().add(pollTimeout);
    var latest = seed;
    while (DateTime.now().isBefore(deadline)) {
      final fetched = await _repo.fetchRecording(seed.id);
      if (fetched != null) {
        latest = fetched;
        if (fetched.status == RecordingStatus.done ||
            fetched.status == RecordingStatus.failed) {
          return fetched;
        }
      }
      await Future<void>.delayed(pollInterval);
    }
    return latest;
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

final inboxUploaderProvider =
    Provider<InboxUploader>((ref) => InboxUploader(ref));
