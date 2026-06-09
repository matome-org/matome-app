import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/providers.dart';
import '../recordings/recordings_repository.dart';
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
  const AudioSource.none()
      : kind = AudioSourceKind.none,
        value = null;

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
  });

  final String id;
  final RecordingRow? row;
  final AudioSource audioSource;
  final bool isLoading;
  final bool notFound;

  /// Live transcription state — drives the "transcribing…" spinner + retry CTA.
  final bool isProcessing;
  final bool processingFailed;

  String get title => row?.title ?? '';
  String? get summary => row?.summary;

  /// The editable body. Mobile stores transcript in `notes` (see F2 notes), so
  /// notes is the canonical editable field, falling back to summary.
  String get initialText => row?.notes ?? row?.summary ?? '';

  /// Whether the audio player has something to play.
  bool get hasAudio => audioSource.kind != AudioSourceKind.none;

  String get badge => row?.badge ?? 'Inbox';

  /// Core numeric id when this row maps to a Core recording (the Drift id is the
  /// stringified Core id), else null for purely-local rows.
  int? get coreId => int.tryParse(id);

  DetailsState copyWith({
    RecordingRow? row,
    AudioSource? audioSource,
    bool? isLoading,
    bool? notFound,
    bool? isProcessing,
    bool? processingFailed,
  }) {
    return DetailsState(
      id: id,
      row: row ?? this.row,
      audioSource: audioSource ?? this.audioSource,
      isLoading: isLoading ?? this.isLoading,
      notFound: notFound ?? this.notFound,
      isProcessing: isProcessing ?? this.isProcessing,
      processingFailed: processingFailed ?? this.processingFailed,
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
  })  : _awaitTerminal = awaitResult,
        super(DetailsState(id: id)) {
    load();
  }

  final Ref _ref;

  /// Races the realtime socket against a poll fallback for the terminal result.
  /// Shared with the upload flow ([liveRecordingResultAwaiter], B1) so there is
  /// a single socket/poll await implementation; injected in tests.
  final RecordingResultAwaiter _awaitTerminal;

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
            await _dao.upsertRecording(recordingToCompanion(remote));
            row = await _dao.getRecordingById(state.id);
          }
        } catch (_) {
          // Offline / auth error — fall through to not-found below.
        }
      }
    }

    if (row == null) {
      state = state.copyWith(isLoading: false, notFound: true);
      return;
    }

    final source = await _resolveAudioSource(row);
    state = state.copyWith(
      row: row,
      audioSource: source,
      isLoading: false,
      isProcessing: row.isProcessing == 1,
      processingFailed: row.processingStatus == 'failed',
    );
  }

  /// Audio source strategy: a real local file wins (mobile-captured rows store a
  /// playable path in `audioFilePath`); otherwise ask Core for a presigned
  /// download URL. Synced rows whose `audioFilePath` is just a storage key (not
  /// an existing file) fall through to the remote URL.
  Future<AudioSource> _resolveAudioSource(RecordingRow row) async {
    final path = row.audioFilePath;
    if (path.isNotEmpty && _isLocalPath(path) && File(path).existsSync()) {
      return AudioSource(AudioSourceKind.localFile, path);
    }
    final coreId = state.coreId;
    if (coreId != null) {
      try {
        final url = await _repo.downloadUrl(coreId);
        if (url != null && url.isNotEmpty) {
          return AudioSource(AudioSourceKind.remoteUrl, url);
        }
      } catch (_) {
        // No remote source available.
      }
    }
    return const AudioSource.none();
  }

  static bool _isLocalPath(String path) {
    return path.startsWith('/') || path.startsWith('file:');
  }

  /// Persists edited text to Drift (`notes`) AND Core (`transcript`), keeping
  /// the two stores consistent. Mirrors apps/mobile handleSave (patch Core when
  /// the id is numeric, then update the local row).
  Future<void> save(String text) async {
    // Drift is the source of truth for display — write it first so the UI
    // reflects the save even if Core is unreachable.
    await _dao.updateRecording(
      state.id,
      RecordingsCompanion(notes: Value(text)),
    );
    final coreId = state.coreId;
    if (coreId != null) {
      await _repo.updateRecording(coreId, transcript: text);
    }
    final row = await _dao.getRecordingById(state.id);
    if (row != null) state = state.copyWith(row: row);
  }

  /// Retries transcription for a failed recording via the F4 pipeline:
  /// `POST /process` then race the `recording:status` channel against the poll.
  /// Marks the local row processing immediately so the UI shows live progress.
  Future<void> retry() async {
    final coreId = state.coreId;
    if (coreId == null) return;

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
        await _applyTerminal(
          failed: false,
          summary: done?.summary,
          notes: done?.transcript,
        );
      }
    } catch (_) {
      await _applyTerminal(failed: true);
    }
  }

  Future<void> _applyTerminal({
    required bool failed,
    String? summary,
    String? notes,
  }) async {
    // Merge, not null-overwrite (B3): a sparse socket `done` event can carry a
    // null summary/transcript even after good data exists, so [mergeText] leaves
    // the column untouched rather than wiping a previously-good value.
    await _dao.updateRecording(
      state.id,
      RecordingsCompanion(
        isProcessing: const Value(0),
        processingStatus: Value(failed ? 'failed' : 'done'),
        summary: failed ? const Value.absent() : mergeText(summary),
        notes: failed ? const Value.absent() : mergeText(notes),
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

  /// Deletes the recording from Drift AND Core.
  Future<void> delete() async {
    await _dao.deleteRecording(state.id);
    final coreId = state.coreId;
    if (coreId != null) {
      try {
        await _repo.deleteRecording(coreId);
      } catch (_) {
        // Local row already gone; tolerate a Core failure (e.g. already
        // deleted server-side) so the UX still navigates away.
      }
    }
  }

  /// All workspaces available as move-to-space targets.
  Future<List<WorkspaceRow>> spaces() => _workspacesDao.getWorkspaces();

  /// Moves the recording into [workspaceId] (Drift-local, S1 convention).
  Future<void> moveToSpace(String workspaceId) async {
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
