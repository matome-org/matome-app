import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_playback.dart';
import '../../core/observability/app_log.dart';
import '../../core/storage/app_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../recordings/recording.dart';
import '../recordings/recording_ids.dart';
import '../recordings/recording_result_waiter.dart';
import '../recordings/recording_status_socket.dart';
import '../recordings/upload_queue.dart';
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

/// Copies a file-picker-imported [picked] file into durable app storage and
/// returns the durable path. Injectable so the durable-copy step can be unit
/// tested without `path_provider`'s platform channel.
///
/// Plan #45 W1 (unified local-first audio): a file-picker import must enter the
/// SAME pipeline as a captured recording — bytes live in durable app storage
/// FIRST, then the #43 [UploadQueue] syncs local→cloud. Returning the unchanged
/// [picked] (no copy) is the web behaviour (cloud-direct, no durable FS).
typedef DurableImportCopy = Future<PickedUpload> Function(PickedUpload picked);

/// Default [DurableImportCopy]: on NATIVE, copies the picked file's bytes into
/// `getApplicationDocumentsDirectory` (the same area the recorder writes its
/// finalized segment) and returns a [PickedUpload] pointing at that DURABLE
/// copy — so the stored `audioFilePath` survives the user deleting the source
/// and never depends on the source path remaining present.
///
/// On WEB (`kIsWeb`) there is no durable native filesystem, so the import stays
/// cloud-direct: the picked file is returned UNCHANGED (the upload queue streams
/// it straight to Core, as today).
Future<PickedUpload> durableImportCopy(PickedUpload picked) async {
  // WEB: cloud-direct — no durable local FS, return the picked file unchanged.
  if (kIsWeb) return picked;

  // NATIVE: copy bytes into the dedicated Matome folder and point at the copy.
  try {
    final dir = await matomeStorageDir();
    // Derive the extension from the BASENAME only: splitting the FULL path on
    // '.' breaks when a PARENT dir has a dot (e.g. `/home/a.b/file` → `b/file`).
    // Take the last path segment first, then its last '.'-suffix.
    final basename = picked.file.path.split('/').last;
    final ext = basename.contains('.') ? basename.split('.').last : 'bin';
    final destPath = '${dir.path}/import_'
        '${DateTime.now().millisecondsSinceEpoch}_${_randSuffix(6)}.$ext';
    final durable = await picked.file.copy(destPath);
    AppLog.event(LogCat.upload, 'durableImportCopy ok -> $destPath');
    return PickedUpload(
      file: durable,
      title: picked.title,
      mediaType: picked.mediaType,
    );
  } catch (e, st) {
    AppLog.error(
      LogCat.upload,
      'durableImportCopy fell back, kept source ${picked.file.path}',
      e,
      st,
    );
    // Best-effort: if the copy fails (e.g. no storage), fall back to the source
    // path so the import is no WORSE than before — the local-first insert still
    // happens and the queue can still try to upload the source while it exists.
    return picked;
  }
}

/// Probes the real duration (whole seconds) of a durable audio file. Returns 0
/// when the duration can't be determined (probe failed / web blob / non-audio).
/// Injectable so the import flow can be unit-tested without a real audio engine
/// — mirrors `AudioRecordingService`'s injectable `durationProbe` seam.
typedef ImportDurationProbe = Future<int> Function(String path);

/// Default [ImportDurationProbe] (plan #46 W3): reads the true clip length off a
/// durable local audio file through the platform-swappable [AudioPlayback]
/// abstraction (#870 W1) — the SAME `createAudioPlayback().setFilePath(...)`
/// probe the recorder uses, so it now works on Linux/Windows desktop too
/// (`just_audio` 0.9.x has no desktop backend → the old probe returned null).
///
/// On WEB there is no durable native file to probe here (the import is
/// cloud-direct, see [durableImportCopy]), so callers leave the duration 0 and
/// it is backfilled by Core once the pipeline resolves.
Future<int> probeImportDurationSeconds(String path) async {
  final player = createAudioPlayback();
  try {
    final dur = await player.setFilePath(path);
    final ms = dur?.inMilliseconds ?? 0;
    return ms > 0 ? (ms / 1000).round() : 0;
  } catch (e, st) {
    AppLog.error(
      LogCat.upload,
      'probeImportDurationSeconds: probe failed for $path (duration 0)',
      e,
      st,
    );
    return 0;
  } finally {
    await player.dispose();
  }
}

final _rng = Random();

String _randSuffix(int len) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
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

/// Orchestrates an Inbox file upload (S1, #780), local-first (plan #43, W2).
///
/// The order is **inverted** from the original mobile port: the local Drift row
/// is written BEFORE any Core call, so a Core-create failure can never leave the
/// captured audio orphaned with no row (the #828 root cause). The flow is:
///
///  1. Mint a local `rec_local_<uuid>` id and INSERT the local Drift row
///     immediately — `coreId = null`, status `pending_upload`, audio path on
///     disk — so the Inbox card shows up regardless of Core reachability.
///  2. Hand the persisted row off to the [UploadQueue] (plan #43, W4), which
///     runs the failure-tolerant `POST /api/recordings` → reconcile `coreId` →
///     stream-upload → enqueue → await terminal → apply pipeline. On any Core
///     failure the queue leaves the row `pending_upload` with the audio on disk
///     and retries it on the next trigger (app start / connectivity regained);
///     on a confirmed `done` the queue drops the on-disk audio.
///
/// The Core id reconcile is centralised in [InboxController.reconcileCoreId];
/// the create→upload→reconcile drain lives in [UploadQueue].
class InboxUploader {
  InboxUploader(
    this._ref, {
    DurableImportCopy? durableCopy,
    ImportDurationProbe? durationProbe,
  })  : _durableCopy = durableCopy ?? durableImportCopy,
        _durationProbe = durationProbe ?? probeImportDurationSeconds;

  final Ref _ref;

  /// Copies a file-picker import into durable app storage before the local-first
  /// insert (plan #45 W1). Injectable for tests; defaults to [durableImportCopy]
  /// (native = copy, web = cloud-direct no-copy).
  final DurableImportCopy _durableCopy;

  /// Probes a durable imported audio file's real duration (plan #46 W3).
  /// Injectable for tests; defaults to [probeImportDurationSeconds] (the #870
  /// platform-swappable audio probe — works on Linux desktop too).
  final ImportDurationProbe _durationProbe;

  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);
  UploadQueue get _queue => _ref.read(uploadQueueProvider);

  /// Persists [picked] locally FIRST, then best-effort uploads to Core.
  ///
  /// 1. Insert a local `rec_local_<uuid>` row (`pending_upload`, `coreId` null,
  ///    audio path on disk) — this NEVER depends on Core and shows the Inbox
  ///    card immediately.
  /// 2. Hand off to the [UploadQueue]: create → reconcile `coreId` → upload →
  ///    enqueue → await → apply, all failure-tolerant. Any Core failure leaves
  ///    the row `pending_upload` + audio on disk for the queue to retry; a
  ///    confirmed `done` drops the on-disk audio.
  ///
  /// [durationSeconds] is the known audio length (seconds) for a captured
  /// recording; the Inbox file-picker path leaves it 0 (unknown).
  ///
  /// [onConfirmed], when given, is registered on the queue as a post-upload
  /// cleanup hook for this row — run ONCE the upload is confirmed `done` (the
  /// capture finisher passes `service.discardSegments` so crash-recovery
  /// segments + the draft are dropped only after a confirmed upload).
  ///
  /// Returns the **local** Drift id (`rec_local_<uuid>`). NOTE (W3): callers
  /// must not assume this equals the Core id — it no longer does. The Core id,
  /// once known, lives in the row's `coreId` column. Today's only callers (the
  /// recording modal `_finish`, the Inbox file-picker) discard the return value,
  /// so this is safe.
  Future<String> upload(
    PickedUpload picked, {
    int durationSeconds = 0,
    Future<void> Function()? onConfirmed,
    bool importFromExternalSource = false,
  }) async {
    AppLog.event(
      LogCat.upload,
      'upload: ${picked.mediaType} import=$importFromExternalSource',
    );
    // 0. DURABLE-COPY (plan #45 W1): a file-picker import names the user's SOURCE
    //    file (e.g. ~/Videos/…mp3) which can vanish, leaving playback dead. The
    //    import must enter the SAME pipeline as a captured recording — copy the
    //    bytes into durable app storage FIRST and store THAT path, so the audio
    //    no longer depends on the source surviving. The recorder finish path
    //    already hands a durable segment (#43 W2), so it skips this step to avoid
    //    a redundant copy that would also slip the #43 cleanup. On WEB the copy
    //    is a no-op (cloud-direct), see [durableImportCopy].
    final stored =
        importFromExternalSource ? await _durableCopy(picked) : picked;

    // 0b. DURATION PROBE (plan #46 W3): an imported audio file arrives with NO
    //     known length, so the card + Details showed a BLANK duration. Probe the
    //     real length off the now-DURABLE local file (so we read a stable path,
    //     after the #45 copy) via the #870 platform-swappable probe — the SAME
    //     probe the recorder uses — and store it on FIRST insert so the card and
    //     Details render the duration immediately (no row-update round-trip).
    //
    //     Probe BEFORE insert because: the upload itself is already fire-and-
    //     forget (the home-screen FAB does `unawaited(upload(...))`), so this
    //     short file read never blocks the UI; and storing the real value up
    //     front means the duration is correct on the card's first render with
    //     ZERO extra pipeline plumbing (an after-insert update would re-render
    //     and risk racing the Core-side backfill).
    //
    //     Only the IMPORT path needs this: the recorder already passes its known
    //     `durationSeconds`. Skip when a caller already supplied one, on WEB (no
    //     durable file to probe; cloud-direct — Core backfills it), and for
    //     non-audio media.
    var resolvedDuration = durationSeconds;
    if (resolvedDuration <= 0 &&
        importFromExternalSource &&
        !kIsWeb &&
        stored.mediaType == 'audio') {
      try {
        resolvedDuration = await _durationProbe(stored.file.path);
      } catch (e, st) {
        AppLog.error(
          LogCat.upload,
          'upload: duration probe failed (duration unknown)',
          e,
          st,
        );
        // Best-effort: a probe failure just leaves the duration unknown (0) —
        // no worse than before; Core may still backfill it.
        resolvedDuration = 0;
      }
    }

    // 1. LOCAL-FIRST: persist the row before touching Core so the capture can
    //    never be orphaned (the #828 root cause). The card appears immediately.
    final localId = mintLocalRecordingId();
    await _inbox.insertLocalUpload(
      _pendingCompanion(localId, stored, resolvedDuration),
    );

    // Register the post-confirm cleanup BEFORE draining so the queue runs it the
    // moment this row reconciles `done` (closes the #828 orphan-WAV seam).
    if (onConfirmed != null) _queue.onConfirmed(localId, onConfirmed);

    // 2. Hand the persisted row to the retry queue, which drives the Core
    //    handoff and is itself the connectivity-driven background drain. This
    //    in-line drain attempts the upload immediately; if Core is unreachable
    //    the row stays pending_upload and a later trigger (app start /
    //    connectivity regained) re-drains it. Never throws out of upload().
    await _queue.drainRow(localId);

    return localId;
  }

  RecordingsCompanion _pendingCompanion(
    String localId,
    PickedUpload picked,
    int durationSeconds,
  ) {
    final now = DateTime.now();
    return RecordingsCompanion(
      id: Value(localId),
      coreId: const Value(null),
      title: Value(picked.title),
      timestamp: Value(formatClock(now)),
      duration: Value(formatDurationText(durationSeconds)),
      badge: const Value('Inbox'),
      isProcessing: const Value(1),
      audioFilePath: Value(picked.file.path),
      createdAt: Value(now.millisecondsSinceEpoch),
      mediaType: Value(picked.mediaType),
      processingStatus: const Value(kProcessingStatusPendingUpload),
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
    } catch (e, st) {
      AppLog.error(
        LogCat.upload,
        'liveRecordingResultAwaiter: socket connect/join failed (poll fallback)',
        e,
        st,
      );
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
