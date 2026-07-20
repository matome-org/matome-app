import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/items_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../recordings/recording.dart';
import '../recordings/recording_ids.dart';
import '../recordings/recording_result_waiter.dart';
import '../recordings/recordings_repository.dart';
import '../recordings/upload_queue.dart';
import '../home/inbox_controller.dart';
import '../home/inbox_sync.dart';
import '../home/inbox_upload.dart';

/// Opaque Vault identity is preferred; signed remote URLs stay memory-only.
enum AudioSourceKind { vaultBlob, remoteUrl, none }

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
  final ItemWithPayload? row;
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

  String get badge => row?.workspaceId == null ? 'Inbox' : 'Space';

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
    ItemWithPayload? row,
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
  }) : _awaitTerminal = awaitResult,
       super(DetailsState(id: id)) {
    load();
  }

  final Ref _ref;

  /// Observes one explicit Core run through bounded polling; injected in tests.
  /// The observation timeout never authors a failed Core state.
  final RecordingResultAwaiter _awaitTerminal;

  ItemsDao get _dao => _ref.read(itemsDaoProvider);
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  RecordingsRepository get _repo => _ref.read(recordingsRepositoryProvider);
  String? get _ownerId => _ref.read(currentOwnerIdProvider);

  /// Loads the recording. Drift `getRecordingById` is the primary source; on a
  /// miss we fetch from Core, reconcile into Drift (S1 conventions) and re-read.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, notFound: false);
    final id = state.id;
    final ownerId = _ownerId;
    if (ownerId == null) {
      state = state.copyWith(isLoading: false, notFound: true);
      return;
    }
    var row = await _dao.getById(id, ownerId);
    if (!mounted) return;

    if (row == null) {
      final coreId = state.coreId;
      if (coreId != null) {
        try {
          final remote = await _repo.fetchRecording(coreId);
          if (remote != null) {
            // m007 (.docs/internal/architecture.md §11 (D3)): a Core-fetched recording must also be an Item of
            // a Matome — mint one in the same transaction if absent.
            final companions = recordingToItemCompanions(remote);
            await _dao.upsertFileItem(
              item: companions.item,
              file: companions.file,
              ensureMatome: true,
            );
            row = await _dao.getById(id, ownerId);
          }
        } catch (e, st) {
          if (!mounted) return;
          // Offline / auth error — fall through to not-found below.
          AppLog.error(
            LogCat.sync,
            'details load Core fetch failed id=$id',
            e,
            st,
          );
        }
      }
    }
    if (!mounted) return;

    if (row == null) {
      state = state.copyWith(isLoading: false, notFound: true);
      return;
    }

    final source = await _resolveAudioSource(row);
    if (!mounted) return;
    final pending = isUploadQueuePendingStatus(row.processingStatus);
    state = state.copyWith(
      row: row,
      audioSource: source,
      isLoading: false,
      // A pending-upload row is held locally, not transcribing — keep the
      // spinner off so the UI reads as safe rather than "in progress".
      isProcessing: !pending && row.isProcessing,
      processingFailed: row.processingState == ProcessingState.failed,
      pendingUpload: pending,
    );
  }

  Future<AudioSource> _resolveAudioSource(ItemWithPayload row) async {
    final blobId = row.blobId;
    if (blobId != null && row.blobState == 'ready') {
      return AudioSource(AudioSourceKind.vaultBlob, blobId);
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
    final ownerId = _requireOwner();
    await _dao.updateItem(
      state.id,
      ownerId,
      ItemsCompanion(notes: Value(text), isDirty: const Value(true)),
    );
    final coreId = state.coreId;
    if (coreId != null) {
      await _repo.updateRecording(coreId, notes: text);
    }
    final row = await _dao.getById(state.id, ownerId);
    if (row != null) state = state.copyWith(row: row);
  }

  /// Retries failed processing without coupling it to upload/cloud state.
  ///
  /// Two failure shapes exist (plan #43, W5):
  ///  * No `coreId` yet — the failure happened during the local-first UPLOAD
  ///    (create/transport), or the row is still `pending_upload`. Re-enqueue
  ///    through the SAME auto-retry queue ([UploadQueue.drainRow]) rather than
  ///    calling `/process` (there is no Core recording to process yet).
  ///  * Has a `coreId` — Core creates a new logical run. Polling accepts only
  ///    that run, while prior successful machine output remains visible.
  Future<void> retry() async {
    AppLog.event(LogCat.action, 'retry recording=${state.id}');
    final coreId = state.coreId;
    if (coreId == null) {
      await _retryUpload();
      return;
    }

    try {
      final pending = await _repo.enqueueProcessing(coreId);
      await _applyRemoteProcessing(pending);
      if (mounted) await load();
      final runId = pending.processing.runId;
      if (runId == null || pending.processing.state.isTerminal) return;
      final result = await _awaitTerminal(
        recording: pending,
        poll: () => _repo.fetchRecording(pending.id),
        ref: _ref,
      );
      final terminal = result.recording;
      if (result.outcome == RecordingWaitOutcome.terminal && terminal != null) {
        await _applyRemoteProcessing(terminal, expectedRunId: runId);
      }
      if (mounted) await load();
    } catch (e, st) {
      AppLog.error(
        LogCat.action,
        'retry processing failed recording=${state.id}',
        e,
        st,
      );
      // A request/transport error is not an authoritative Core run result.
      if (mounted) await load();
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

  Future<void> _applyRemoteProcessing(
    Recording remote, {
    String? expectedRunId,
  }) async {
    final ownerId = _requireOwner();
    final current = await _dao.getById(state.id, ownerId);
    if (current == null) return;
    if (expectedRunId != null && remote.processing.runId != expectedRunId) {
      return;
    }
    await _dao.updateItem(
      state.id,
      ownerId,
      itemProcessingUpdate(remote, existing: current),
    );
  }

  /// Creates a durable tombstone. The shared executor orders remote delete,
  /// lease-aware Vault deletion and metadata convergence across restarts.
  Future<void> delete() async {
    AppLog.event(LogCat.action, 'delete recording=${state.id}');
    await _ref
        .read(itemDeletionServiceProvider)
        .delete(state.id, _requireOwner());
  }

  /// All workspaces available as move-to-space targets.
  Future<List<WorkspaceRow>> spaces() => _workspacesDao.getWorkspaces();

  /// Moves the recording into [workspaceId] (Drift-local, S1 convention).
  Future<void> moveToSpace(String workspaceId) async {
    AppLog.event(
      LogCat.action,
      'moveToSpace recording=${state.id} space=$workspaceId',
    );
    final ownerId = _requireOwner();
    await _dao.updateItem(
      state.id,
      ownerId,
      ItemsCompanion(
        workspaceId: Value(workspaceId),
        isDirty: const Value(true),
      ),
    );
    final row = await _dao.getById(state.id, ownerId);
    if (row != null) state = state.copyWith(row: row);
  }

  String _requireOwner() {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('An authenticated owner is required');
    }
    return ownerId;
  }
}

/// Family provider keyed by the recording id (the Drift TEXT id / stringified
/// Core id from the route param).
final detailsControllerProvider = StateNotifierProvider.autoDispose
    .family<DetailsController, DetailsState, String>(
      (ref, id) => DetailsController(ref, id),
    );
