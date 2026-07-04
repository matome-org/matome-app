import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/crypto/key_material.dart' show Dek;
import '../../core/crypto/media_playback_resolver.dart'
    show PlaybackScratchDirSource, resolvePlaybackPath;
import '../../core/db/db_encryption.dart'
    show FlutterSecureKeyStore, NativeDekProvisioner;
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../recordings/recording_ids.dart';
import '../recordings/recordings_repository.dart';
import '../recordings/upload_queue.dart';
import '../home/inbox_controller.dart';
import '../home/inbox_sync.dart';
import '../home/inbox_upload.dart';

/// Resolved audio playback source for the Details player.
///
/// Local file is preferred (offline, mobile-captured recordings store a real
/// path); otherwise the Core presigned download URL is used. `none` means there
/// is nothing to play (e.g. a synced row whose storageKey is just an object key
/// and the download-url could not be resolved).
enum AudioSourceKind { localFile, remoteUrl, none }

class AudioSource {
  const AudioSource(this.kind, this.value);
  const AudioSource.none() : kind = AudioSourceKind.none, value = null;

  final AudioSourceKind kind;
  final String? value;
}

/// Immutable view-state for the Details screen (S2).
class DetailsState {
  const DetailsState({
    required this.id,
    this.row,
    this.audioSource = const AudioSource.none(),
    this.isLoading = true,
    this.notFound = false,
    this.isProcessing = false,
    this.processingFailed = false,
    this.pendingUpload = false,
  });

  final String id;
  final RecordingRow? row;
  final AudioSource audioSource;
  final bool isLoading;
  final bool notFound;

  /// Live transcription state — drives the "transcribing…" spinner + retry CTA.
  final bool isProcessing;
  final bool processingFailed;

  /// Saved-on-device-but-not-yet-uploaded (plan #43, W5). Distinct from
  /// [isProcessing]: nothing is in flight, the recording is simply held locally
  /// until the upload queue reaches Core. Drives the SAFE-but-not-uploaded copy.
  final bool pendingUpload;

  String get title => row?.title ?? '';
  String? get summary => row?.summary;

  /// The editable Notes body — the user-owned `notes` field.
  ///
  /// The audio detail host ([FileDetailScreen.byId], #1439) seeds the Notes
  /// editor from this and reads the machine-owned `row.transcript` column into
  /// the read-only Contents section — the carry-forward read/UI rewire is done.
  String get initialText => row?.notes ?? '';

  /// Whether the audio player has something to play.
  bool get hasAudio => audioSource.kind != AudioSourceKind.none;

  String get badge => row?.badge ?? 'Inbox';

  /// Core numeric id for this recording, or null when the row is local-only and
  /// has not yet been reconciled with Core (plan #43, W3).
  ///
  /// Source of truth is the loaded row's `coreId` column — a `rec_local_<uuid>`
  /// row keeps `coreId` null until `POST /api/recordings` succeeds, at which
  /// point the upload/queue flow fills it (never a PK remap). Before the row is
  /// loaded (the Core-fetch-on-miss path in [DetailsController.load]) we fall
  /// back to parsing the id, which resolves the legacy case where Details is
  /// opened for a numeric-id Core recording not yet cached in Drift. For a
  /// local-only id (`rec_local_...`) the parse yields null, so Core calls are
  /// cleanly skipped rather than parse-failing silently.
  int? get coreId => row?.coreId ?? int.tryParse(id);

  DetailsState copyWith({
    RecordingRow? row,
    AudioSource? audioSource,
    bool? isLoading,
    bool? notFound,
    bool? isProcessing,
    bool? processingFailed,
    bool? pendingUpload,
  }) {
    return DetailsState(
      id: id,
      row: row ?? this.row,
      audioSource: audioSource ?? this.audioSource,
      isLoading: isLoading ?? this.isLoading,
      notFound: notFound ?? this.notFound,
      isProcessing: isProcessing ?? this.isProcessing,
      processingFailed: processingFailed ?? this.processingFailed,
      pendingUpload: pendingUpload ?? this.pendingUpload,
    );
  }
}

/// Drives the Details screen: loads the recording (Drift first, Core fallback),
/// resolves the audio source, persists edits to Drift + Core, retries failed
/// transcription via the F4 pipeline, and supports delete / move-to-space.
///
/// Display source is ALWAYS Drift — Core is reconciled into Drift via the S1
/// (#780) sync conventions ([recordingToCompanion], int<->TEXT id) so edits
/// stay consistent across both stores.
class DetailsController extends StateNotifier<DetailsState> {
  DetailsController(
    this._ref,
    String id, {
    RecordingResultAwaiter awaitResult = liveRecordingResultAwaiter,
    Future<Dek> Function()? mediaDekSource,
    PlaybackScratchDirSource? playbackScratchDirSource,
  }) : _awaitTerminal = awaitResult,
       _mediaDekSource =
           mediaDekSource ??
           (() =>
               NativeDekProvisioner(FlutterSecureKeyStore.deviceKek()).obtainDek()),
       _playbackScratchDirSource =
           playbackScratchDirSource ?? _defaultPlaybackScratchDir,
       super(DetailsState(id: id)) {
    load();
  }

  final Ref _ref;

  /// Races the realtime socket against a poll fallback for the terminal result.
  /// Shared with the upload flow ([liveRecordingResultAwaiter], B1) so there is
  /// a single socket/poll await implementation; injected in tests.
  final RecordingResultAwaiter _awaitTerminal;

  /// Encrypted-media read seam (task #1866): supplies the DEK
  /// [resolvePlaybackPath] unwraps a recording's `wrappedFek` with. Defaults
  /// to the SAME `NativeDekProvisioner(FlutterSecureKeyStore.deviceKek())`
  /// wiring `inbox_upload.dart` uses on the write side; injected in tests so
  /// the encrypted branch is exercisable without a `flutter_secure_storage`
  /// platform channel.
  final Future<Dek> Function() _mediaDekSource;

  /// Where [resolvePlaybackPath] decrypts a `wrappedFek`-bearing recording
  /// to before handing it to the player; injected in tests, defaults to
  /// [_defaultPlaybackScratchDir].
  final PlaybackScratchDirSource _playbackScratchDirSource;

  RecordingsDao get _dao => _ref.read(recordingsDaoProvider);
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);

  /// Loads the recording. Drift `getRecordingById` is the primary source; on a
  /// miss we fetch from Core, reconcile into Drift (S1 conventions) and re-read.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, notFound: false);
    var row = await _dao.getRecordingById(state.id);

    if (row == null) {
      final coreId = state.coreId;
      if (coreId != null) {
        try {
          final remote = await _repo.fetchRecording(coreId);
          if (remote != null) {
            // m007 (.docs/internal/architecture.md §11 (D3)): a Core-fetched recording must also be an Item of
            // a Matome — mint one in the same transaction if absent.
            await _dao.upsertRecordingWithMatome(recordingToCompanion(remote));
            row = await _dao.getRecordingById(state.id);
          }
        } catch (e, st) {
          // Offline / auth error — fall through to not-found below.
          AppLog.error(
            LogCat.sync,
            'details load Core fetch failed id=${state.id}',
            e,
            st,
          );
        }
      }
    }

    if (row == null) {
      state = state.copyWith(isLoading: false, notFound: true);
      return;
    }

    final source = await _resolveAudioSource(row);
    final pending = row.processingStatus == kProcessingStatusPendingUpload;
    state = state.copyWith(
      row: row,
      audioSource: source,
      isLoading: false,
      // A pending-upload row is held locally, not transcribing — keep the
      // spinner off so the UI reads as safe rather than "in progress".
      isProcessing: !pending && row.isProcessing == 1,
      processingFailed: row.processingStatus == 'failed',
      pendingUpload: pending,
    );
  }

  /// Audio source strategy: a real local file wins (mobile-captured rows store a
  /// playable path in `audioFilePath`); otherwise ask Core for a presigned
  /// download URL. Synced rows whose `audioFilePath` is just a storage key (not
  /// an existing file) fall through to the remote URL.
  ///
  /// ENCRYPTED-MEDIA READ SEAM (task #1866, okt-audit warning on #1857): a
  /// non-null `wrappedFek` means `audioFilePath` names `media_cipher.dart`
  /// ciphertext (written by `inbox_upload.dart`'s `encryptedDurableImportCopy`
  /// once `kMediaEncryptionEnabled` is on) — it is routed through
  /// [resolvePlaybackPath] to decrypt to a private scratch file BEFORE the
  /// player ever opens it. A null `wrappedFek` is today's exact behavior,
  /// unchanged: the raw path is handed straight to the player.
  Future<AudioSource> _resolveAudioSource(RecordingRow row) async {
    final path = row.audioFilePath;
    if (path.isNotEmpty && _isLocalPath(path) && File(path).existsSync()) {
      final wrappedFek = row.wrappedFek;
      if (wrappedFek == null) {
        return AudioSource(AudioSourceKind.localFile, path);
      }
      final resolvedPath = await resolvePlaybackPath(
        recordingId: row.id,
        sourcePath: path,
        wrappedFekBase64: wrappedFek,
        dekSource: _mediaDekSource,
        scratchDirSource: _playbackScratchDirSource,
      );
      return AudioSource(AudioSourceKind.localFile, resolvedPath);
    }
    // Read coreId off the row being resolved (state.row isn't published yet at
    // this point in load()). A local-only row (coreId null) has no remote URL.
    final coreId = row.coreId ?? int.tryParse(row.id);
    if (coreId != null) {
      try {
        final url = await _repo.downloadUrl(coreId);
        if (url != null && url.isNotEmpty) {
          return AudioSource(AudioSourceKind.remoteUrl, url);
        }
      } catch (e, st) {
        // No remote source available.
        AppLog.error(
          LogCat.error,
          'details resolve audio downloadUrl failed coreId=$coreId',
          e,
          st,
        );
      }
    }
    return const AudioSource.none();
  }

  static bool _isLocalPath(String path) {
    return path.startsWith('/') || path.startsWith('file:');
  }

  /// Default private scratch directory for [resolvePlaybackPath]'s
  /// decrypted-media output (task #1866). Deliberately `getTemporaryDirectory()`,
  /// NOT `matomeStorageDir()` — the decrypted bytes are transiently plaintext
  /// on disk for the player's use (documented trade-off, `media_cipher.dart`'s
  /// `decryptToFile` doc), so they belong under the OS-managed cache/temp
  /// area, never the durable Matome folder.
  static Future<Directory> _defaultPlaybackScratchDir() async {
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}/matome_playback_cache');
  }

  /// Persists the edited buffer to Drift (`notes`) AND Core (`notes`), keeping
  /// the two stores consistent.
  ///
  /// WRITE-AUTHORITY (task #1435): the editor buffer is the USER's note, so it
  /// is written to the user-owned `notes` field on BOTH stores. It must NEVER
  /// be PATCHed onto Core `transcript` (the machine-owned column) — that was the
  /// direct data-loss path that overwrote the transcript with whatever the user
  /// typed. The Drift `transcript` column is left untouched here.
  Future<void> save(String text) async {
    AppLog.event(LogCat.action, 'save recording=${state.id}');
    // Drift is the source of truth for display — write it first so the UI
    // reflects the save even if Core is unreachable.
    await _dao.updateRecording(
      state.id,
      RecordingsCompanion(notes: Value(text)),
    );
    final coreId = state.coreId;
    if (coreId != null) {
      await _repo.updateRecording(coreId, notes: text);
    }
    final row = await _dao.getRecordingById(state.id);
    if (row != null) state = state.copyWith(row: row);
  }

  /// Retries a failed recording.
  ///
  /// Two failure shapes exist (plan #43, W5):
  ///  * No `coreId` yet — the failure happened during the local-first UPLOAD
  ///    (create/transport), or the row is still `pending_upload`. Re-enqueue
  ///    through the SAME auto-retry queue ([UploadQueue.drainRow]) rather than
  ///    calling `/process` (there is no Core recording to process yet).
  ///  * Has a `coreId` — the upload reconciled but TRANSCRIPTION failed. Retry
  ///    via the F4 pipeline: `POST /process` then race the `recording:status`
  ///    channel against the poll. Marks the row processing immediately.
  Future<void> retry() async {
    AppLog.event(LogCat.action, 'retry recording=${state.id}');
    final coreId = state.coreId;
    if (coreId == null) {
      await _retryUpload();
      return;
    }

    await _dao.updateRecording(
      state.id,
      const RecordingsCompanion(
        isProcessing: Value(1),
        processingStatus: Value('processing'),
      ),
    );
    state = state.copyWith(isProcessing: true, processingFailed: false);

    try {
      final pending = await _repo.enqueueProcessing(coreId);
      // Single socket/poll await — shared with the upload flow (B1) so there is
      // no duplicated pipeline. First terminal signal from either source wins.
      final result = await _awaitTerminal(
        recording: pending,
        poll: () => _repo.fetchRecording(pending.id),
        ref: _ref,
      );
      if (result.failed) {
        await _applyTerminal(failed: true);
      } else {
        final done = result.recording;
        // WRITE-AUTHORITY (#1435): the machine transcript routes to the
        // `transcript` column, NOT `notes`. The previous alias
        // (`notes: done?.transcript`) clobbered any user note on every
        // terminal apply.
        await _applyTerminal(
          failed: false,
          summary: done?.summary,
          transcript: done?.transcript,
        );
      }
    } catch (e, st) {
      AppLog.error(
        LogCat.action,
        'retry processing failed recording=${state.id}',
        e,
        st,
      );
      await _applyTerminal(failed: true);
    }
  }

  /// Re-enqueue a not-yet-uploaded recording through the shared auto-retry
  /// queue (plan #43, W5), then reload the local row so Details reflects the
  /// new state. Delegates to [InboxController.retryUpload] so the manual retry
  /// path is identical to the Inbox card's — flip to `pending_upload`, drain.
  Future<void> _retryUpload() async {
    state = state.copyWith(
      pendingUpload: true,
      processingFailed: false,
      isProcessing: false,
    );
    await _ref.read(inboxControllerProvider.notifier).retryUpload(state.id);
    if (!mounted) return;
    await load();
  }

  Future<void> _applyTerminal({
    required bool failed,
    String? summary,
    String? transcript,
  }) async {
    // Merge, not null-overwrite (B3): a sparse socket `done` event can carry a
    // null summary/transcript even after good data exists, so [mergeText] leaves
    // the column untouched rather than wiping a previously-good value.
    //
    // WRITE-AUTHORITY (#1435): the machine transcript lands in the `transcript`
    // column; the user `notes` column is never touched on a terminal apply.
    await _dao.updateRecording(
      state.id,
      RecordingsCompanion(
        isProcessing: const Value(0),
        processingStatus: Value(failed ? 'failed' : 'done'),
        summary: failed ? const Value.absent() : mergeText(summary),
        transcript: failed ? const Value.absent() : mergeText(transcript),
      ),
    );
    final row = await _dao.getRecordingById(state.id);
    // Guard against a state emit after the autoDispose provider tore down (e.g.
    // the user navigated away mid-retry).
    if (!mounted) return;
    state = state.copyWith(
      row: row,
      isProcessing: false,
      processingFailed: failed,
    );
  }

  /// Deletes the recording: the local audio FILE, the Drift row, AND Core.
  ///
  /// This is the EXPLICIT, user-initiated deletion (plan #46, W2 / #871). Since
  /// the upload queue no longer auto-evicts the local audio on `done`, the
  /// local-first `audioFilePath` is the durable source of truth and lives until
  /// the user deletes it here. So this path must free the on-disk file too —
  /// otherwise a user-delete would leave an orphaned WAV on disk forever.
  ///
  /// Order: drop the on-disk file FIRST (we still hold the row + its path),
  /// then the Drift row, then Core (best-effort). We delete the file straight
  /// from the row's `audioFilePath` when it is a real local path (not a remote
  /// storage key) — deliberately NOT gated on the resolved playback source, so a
  /// `done`/synced row that still owns its local-first copy (exactly the W2
  /// scenario) still has that file freed. A synced-only row whose path is a Core
  /// object key is skipped — there is no local file to remove.
  Future<void> delete() async {
    AppLog.event(LogCat.action, 'delete recording=${state.id}');
    final path = state.row?.audioFilePath ?? '';
    if (path.isNotEmpty && (path.startsWith('/') || path.startsWith('file:'))) {
      // Reuse the queue's best-effort path delete (never throws).
      await deleteAudioFile(path);
    }
    await _dao.deleteRecording(state.id);
    final coreId = state.coreId;
    if (coreId != null) {
      try {
        await _repo.deleteRecording(coreId);
      } catch (e, st) {
        // Local row already gone; tolerate a Core failure (e.g. already
        // deleted server-side) so the UX still navigates away.
        AppLog.error(LogCat.sync, 'delete Core failed coreId=$coreId', e, st);
      }
    }
  }

  /// All workspaces available as move-to-space targets.
  Future<List<WorkspaceRow>> spaces() => _workspacesDao.getWorkspaces();

  /// Moves the recording into [workspaceId] (Drift-local, S1 convention).
  Future<void> moveToSpace(String workspaceId) async {
    AppLog.event(
      LogCat.action,
      'moveToSpace recording=${state.id} space=$workspaceId',
    );
    await _dao.updateRecording(
      state.id,
      RecordingsCompanion(workspaceId: Value(workspaceId)),
    );
    final row = await _dao.getRecordingById(state.id);
    if (row != null) state = state.copyWith(row: row);
  }
}

/// Family provider keyed by the recording id (the Drift TEXT id / stringified
/// Core id from the route param).
final detailsControllerProvider = StateNotifierProvider.autoDispose
    .family<DetailsController, DetailsState, String>(
      (ref, id) => DetailsController(ref, id),
    );
