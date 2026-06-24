import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/recording_card.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/file_type_chip.dart';
import '../../ui/loading_indicator.dart';
import '../recordings/recording_ids.dart';
import 'audio_player_bar.dart';
import 'details_controller.dart';
import 'file_actions_menu.dart';
import 'file_view.dart';
import 'markdown_helpers.dart';

/// Maps a stored `mediaType` string (audio | image | document — the buckets
/// `mediaTypeForPath` writes) to the [FileMediaKind] that drives [FileView]'s
/// media header and default Contents tag. Anything not image/document is treated
/// as audio (the original default). Centralised here so the item-driven
/// ([FileDetailScreen.mediaKindOf]) and row-driven ([_FileDetailById]) paths
/// agree on a single mapping — an imported document (#1449) routes to
/// [FileMediaKind.doc], never image or audio.
FileMediaKind mediaKindForType(String mediaType) {
  if (mediaType.startsWith('image')) return FileMediaKind.image;
  if (mediaType.startsWith('document')) return FileMediaKind.doc;
  return FileMediaKind.audio;
}

/// Best-effort human size for the on-disk document, read synchronously from the
/// file at [path]. Returns null (→ the chip renders its unknown-size
/// placeholder) when the path is absent or the file cannot be stat-ed — a
/// missing size must never block the chip from rendering.
String? _fileSizeLabel(String? path) {
  if (path == null || path.isEmpty) return null;
  try {
    final bytes = File(path).lengthSync();
    return _formatBytes(bytes);
  } catch (_) {
    return null;
  }
}

/// Formats a byte count into a compact unit string (e.g. `2.4 MB`). Uses 1024
/// steps and trims a trailing `.0` so whole numbers read cleanly.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value.toStringAsFixed(1);
  final trimmed = text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  return '$trimmed ${units[unit]}';
}

/// Shared delete flow for a file (audio or image): confirm dialog → delete the
/// recording via [detailsControllerProvider] → pop the detail. Captures the
/// navigator up front so it survives the async gap. [onBeforeDelete] lets the
/// audio host clear its dirty baseline so the leave-guard doesn't block the pop.
Future<void> _fileDeleteFlow(
  BuildContext context,
  WidgetRef ref,
  String id, {
  VoidCallback? onBeforeDelete,
}) async {
  final navigator = Navigator.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      return AppDialog(
        title: Text(t.details.deleteConfirmTitle),
        content: Text(t.details.deleteConfirmBody),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          AppTextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.failed),
            child: Text(t.details.delete),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;
  onBeforeDelete?.call();
  await ref.read(detailsControllerProvider(id).notifier).delete();
  if (navigator.canPop()) navigator.pop();
}

/// FileDetailScreen — the unified file-detail HOST that wires a single file's
/// data/navigation around the presentational [FileView].
///
/// [FileView] is intentionally free of DB rows, providers and navigation; this
/// host is where those concerns live. There are two entry points onto the same
/// scaffold:
///
///   * [FileDetailScreen.new] (`item:`) — IMAGE path (#1438). The matome hub
///     already holds the full [RecordingItem] for the tapped tile, so the host
///     takes it directly. It is read-only (no notes persistence yet) and builds
///     the inline framed image media header whose tap opens a fullscreen viewer.
///
///   * [FileDetailScreen.byId] (`id:`) — AUDIO path (#1439). Routed from
///     `/recording/detail/:id`, it loads via [detailsControllerProvider] and
///     owns the full edit lifecycle: Notes save (to the user-owned `notes`
///     column), the unsaved-changes leave guard, retry / delete / move-to-space,
///     and an [AudioPlayerBar] media header. Audio Contents (read-only) reads the
///     machine-owned `transcript` column; per-file Summary is gone (it belongs to
///     the matome). The screen opens focused on Contents — the Notes field is not
///     auto-opened.
///
/// The [FileView] composition and the [RecordingItem]→[FileViewData] mapping are
/// shared across both paths; only the media header and the persistence wiring
/// differ.
///
/// Reuse seam for the next wave:
///   * #1440 (Contents state machine): both paths render [FileView]'s honest
///     empty/contents body; swap [FileViewData.contentsText] for the
///     state-driven body there.
class FileDetailScreen extends StatelessWidget {
  /// Image entry point — the [RecordingItem] is supplied directly.
  const FileDetailScreen({super.key, required this.item})
      : id = null,
        _rowOnlyKind = null;

  /// Audio entry point — the file is loaded by id via [detailsControllerProvider].
  const FileDetailScreen.byId({super.key, required this.id})
      : item = null,
        _rowOnlyKind = null;

  /// Image drill-down by id (`/recording/image/:id`). Loads ONLY the row (no
  /// audio-source resolution / `downloadUrl`) and renders the image host. The id
  /// lives in the route PATH so it SURVIVES go_router rebuilds — unlike `extra`,
  /// which go_router drops on rebuild, making `state.extra!` throw a null-check.
  const FileDetailScreen.imageById({super.key, required this.id})
      : item = null,
        _rowOnlyKind = FileMediaKind.image;

  /// Document drill-down by id (`/recording/document/:id`, #1450). Mirrors
  /// [imageById] exactly — loads ONLY the row via `getRecordingById` (NO
  /// audio-source `downloadUrl`; a document never hits the audio host) and
  /// renders the generic file host with [FileMediaKind.doc] (the "Document"
  /// Contents tag, no inline preview in v1). The id rides in the route PATH so
  /// it SURVIVES go_router rebuilds — `extra` is dropped on rebuild, which would
  /// make `state.extra!` throw a null-check.
  const FileDetailScreen.documentById({super.key, required this.id})
      : item = null,
        _rowOnlyKind = FileMediaKind.doc;

  /// The Item being shown (item-driven image path). Null on the id paths.
  final RecordingItem? item;

  /// The recording id to load (audio or image/document-by-id path).
  final String? id;

  /// Non-null on the row-only id paths ([imageById] / [documentById]): the kind
  /// to render after loading ONLY the row, bypassing the audio-centric details
  /// load. Null on the audio ([byId]) and item-driven paths.
  final FileMediaKind? _rowOnlyKind;

  /// Maps the `mediaType` carried by a [RecordingItem] to the [FileMediaKind]
  /// that selects [FileView]'s media header and default Contents tag. Mirrors
  /// the audio/image/document buckets `mediaTypeForPath` writes — an imported
  /// document (#1449) maps to [FileMediaKind.doc], NOT image/audio.
  static FileMediaKind mediaKindOf(RecordingItem item) =>
      mediaKindForType(item.mediaType);

  @override
  Widget build(BuildContext context) {
    final id = this.id;
    final rowOnlyKind = _rowOnlyKind;
    if (rowOnlyKind != null && id != null) {
      return _RowOnlyDetailById(id: id, mediaKind: rowOnlyKind);
    }
    if (id != null) return _FileDetailById(id: id);
    return _ImageDetailHost.fromItem(item: item!);
  }
}

/// Loads ONLY the row by id (no audio-source resolution / `downloadUrl`) and
/// renders the kind-specific host. Robust to go_router rebuilds — the id comes
/// from the route path, not `extra`.
final _imageRowProvider =
    FutureProvider.autoDispose.family<RecordingRow?, String>(
  (ref, id) => ref.watch(recordingsDaoProvider).getRecordingById(id),
);

/// The row-only id host shared by the image (`/recording/image/:id`) and
/// document (`/recording/document/:id`, #1450) routes. Both load ONLY the row —
/// no audio-source `downloadUrl` — and render the generic [_ImageDetailHost]
/// with the supplied [mediaKind] (image → framed preview; doc → "Document" tag,
/// no inline preview). Keeping a single host for both keeps the no-audio-load
/// invariant in ONE place.
class _RowOnlyDetailById extends ConsumerStatefulWidget {
  const _RowOnlyDetailById({required this.id, required this.mediaKind});

  final String id;
  final FileMediaKind mediaKind;

  @override
  ConsumerState<_RowOnlyDetailById> createState() => _RowOnlyDetailByIdState();
}

class _RowOnlyDetailByIdState extends ConsumerState<_RowOnlyDetailById> {
  void _onDelete() => _fileDeleteFlow(context, ref, widget.id);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget shell(Widget body) => Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            surfaceTintColor: colors.background,
          ),
          body: body,
        );

    return ref.watch(_imageRowProvider(widget.id)).when(
          data: (row) => row == null
              ? shell(Center(child: Text(t.recording.title)))
              : _ImageDetailHost.fromRow(
                  row: row,
                  place: null,
                  mediaKind: widget.mediaKind,
                  // Same "…" popup as audio (Delete), so every file detail has
                  // a consistent overflow.
                  trailing: FileActionsMenu(onDelete: _onDelete),
                ),
          loading: () => shell(const Center(child: LoadingIndicator())),
          error: (_, _) => shell(Center(child: Text(t.recording.title))),
        );
  }
}

/// Loads the row by id and dispatches to the kind-specific host. Keeps the two
/// hosts free of the load/dispatch concern: image → [_ImageDetailHost], audio →
/// [_AudioDetailHost], both fed off the SAME [detailsControllerProvider] load so
/// the route renders the right screen for any file type.
class _FileDetailById extends ConsumerWidget {
  const _FileDetailById({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(detailsControllerProvider(id));

    // While the row is loading (or if it is genuinely missing) defer to the
    // audio host, which already renders the honest loading / not-found bodies —
    // a single place for those states rather than duplicating them here.
    final row = state.row;
    if (state.isLoading || row == null) {
      return _AudioDetailHost(id: id);
    }
    // Route by the row's media kind (NOT a bare `startsWith('image')`):
    //   * image  → the framed image host,
    //   * doc    → the generic file host (no inline preview; v1 only STORES
    //              documents — open/extract/parse is deferred, #1449),
    //   * audio  → the audio host (the default).
    switch (mediaKindForType(row.mediaType)) {
      case FileMediaKind.image:
        return _ImageDetailHost.fromRow(row: row, place: state.badge);
      case FileMediaKind.doc:
        return _ImageDetailHost.fromRow(
          row: row,
          place: state.badge,
          mediaKind: FileMediaKind.doc,
        );
      case FileMediaKind.audio:
        return _AudioDetailHost(id: id);
    }
  }
}

// ─── Image host (read-only) ─────────────────────────────────────────────────

/// The image detail host: maps a [RecordingItem] into a [FileViewData], builds
/// the inline framed image media header, and owns the fullscreen-viewer
/// navigation. Read-only Notes for now (image notes persistence is out of scope).
class _ImageDetailHost extends StatelessWidget {
  /// Built from the [RecordingItem] the matome hub already holds (the direct
  /// `FileDetailScreen(item:)` entry — embedded / two-pane hosts).
  _ImageDetailHost.fromItem({required RecordingItem item})
      : title = item.title,
        place = item.workspaceName,
        coreId = item.coreId,
        processingStatus = item.processingStatus,
        path = item.filePath,
        notes = item.notes,
        mediaKind = mediaKindForType(item.mediaType),
        originalExtension = null,
        // The item-driven path carries no machine text/processing flag, so the
        // doc Contents falls back to its honest derivation (empty).
        contentsText = null,
        isProcessing = false,
        trailing = null;

  /// Built from a loaded [RecordingRow] — the id-driven `/recording/detail/:id`
  /// route, which now dispatches images here (#97 unification) so the image and
  /// audio tiles drill down through the SAME go_router route. [mediaKind]
  /// defaults to image but is [FileMediaKind.doc] for an imported document
  /// (#1449) so the view shows the "Document" tag (and NO inline image preview).
  _ImageDetailHost.fromRow({
    required RecordingRow row,
    required this.place,
    this.trailing,
    this.mediaKind = FileMediaKind.image,
  })  : title = row.title,
        coreId = row.coreId,
        processingStatus = row.processingStatus,
        // The image's on-disk path lives in the `audioFilePath` column (the
        // generic media-path column shared across kinds).
        path = row.audioFilePath,
        notes = row.notes,
        // The machine-produced text (Core-owned `transcript` column — the SAME
        // column audio uses) carries the document's stub summary once the
        // pipeline resolves (#1454). The doc Contents renders it as the "ready"
        // body; image keeps it null (its description producer is deferred).
        contentsText = row.transcript,
        isProcessing = row.isProcessing == 1,
        // The persisted source extension (#1449) drives the doc chip's type
        // icon; null on non-document rows (and on the item-driven path).
        originalExtension = row.originalExtension;

  final String title;
  final String? place;
  final int? coreId;
  final String? processingStatus;
  final String? path;
  final String? notes;

  /// The machine-produced Contents text (Core-owned `transcript` column). On the
  /// doc path this carries the AI-stub summary once the upload pipeline resolves;
  /// null on the image path (its description producer is deferred, #1445).
  final String? contentsText;

  /// Whether the row is mid-pipeline (`isProcessing == 1`). Drives the doc
  /// Contents "Processing…" state; ignored on the image path.
  final bool isProcessing;

  /// The persisted lower-case source extension (`original_extension`, #1449)
  /// used by the doc media header to pick its type icon. Null on image/audio.
  final String? originalExtension;

  /// The media kind driving the FileView header + Contents tag. image by
  /// default; doc for an imported document (no inline preview in v1).
  final FileMediaKind mediaKind;

  /// The "…" overflow menu rendered in the AppBar (Move + Delete). Null on the
  /// item-driven [fromItem] path.
  final Widget? trailing;

  FileViewData _viewData(BuildContext context) {
    return FileViewData(
      title: title,
      mediaKind: mediaKind,
      place: place,
      syncCoreId: coreId,
      processingStatus: processingStatus,
      // Each kind swaps its own media header:
      //   * image → the framed inline preview that opens the fullscreen viewer,
      //   * doc   → the FileTypeChip (type icon + name + size + DISABLED "Open"
      //             labelled "soon"; open/preview is deferred, #1455),
      //   * audio → handled by the audio host, not here.
      mediaHeader: switch (mediaKind) {
        FileMediaKind.image => _ImageMediaHeader(
            path: path,
            onOpenFullscreen: () => _openFullscreen(context),
          ),
        FileMediaKind.doc => FileTypeChip(
            fileName: title,
            extension: originalExtension,
            sizeLabel: _fileSizeLabel(path),
          ),
        FileMediaKind.audio => null,
      },
      // Contents body, per kind:
      //   * image → "Description". The image description producer is deferred
      //     (#1445), so there is no honest "processing": the Contents state
      //     machine (#1440) converges on the EMPTY terminal state ("No
      //     description yet") rather than a fake "Describing…".
      //   * doc   → "Document". The document IS processed end-to-end (#1454): the
      //     AI-stub summary lands in the machine `transcript` column, so the doc
      //     Contents renders the LIVE state machine driven by the row's own
      //     fields — processing while in flight, failed on a failed pipeline,
      //     ready once the summary arrives, empty otherwise. This wires the
      //     `contentsStatus.doc.*` strings (en + ja) to real states rather than
      //     leaving them as the placeholder empty body.
      contentsText: mediaKind == FileMediaKind.doc ? contentsText : null,
      contentsState: mediaKind == FileMediaKind.doc
          ? _docContentsState()
          : ContentsState.empty,
      notesText: notes,
    );
  }

  /// Honest, producer-independent Contents state for a document, derived from
  /// the row's OWN fields — mirrors the audio host's `_contentsState`:
  ///   * `processingStatus == 'failed'` → failed ("Processing failed"),
  ///   * mid-pipeline (`isProcessing`, but not a locally-held pending upload) →
  ///     processing ("Processing…"),
  ///   * machine summary present → ready (render it),
  ///   * otherwise → empty ("No contents yet").
  /// A `pending_upload` row is held locally (not in the pipeline), so it reads
  /// as empty rather than a misleading "Processing…".
  ContentsState _docContentsState() {
    if (processingStatus == 'failed') return ContentsState.failed;
    final pending = processingStatus == kProcessingStatusPendingUpload;
    if (isProcessing && !pending) return ContentsState.processing;
    final text = contentsText;
    if (text != null && text.trim().isNotEmpty) return ContentsState.ready;
    return ContentsState.empty;
  }

  void _openFullscreen(BuildContext context) {
    final path = this.path;
    if (path == null || path.isEmpty) return;
    // Push the fullscreen viewer on the LOCAL navigator (the one that owns this
    // detail screen), NOT the root navigator: this detail screen is itself a
    // go_router page, so its enclosing Navigator is the right host for a
    // child modal — and it keeps the viewer scoped to the detail route.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(path: path, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(
          title.isEmpty ? t.recording.title : title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [?trailing],
      ),
      body: fileReadingCard(
        context,
        child: FileView(
          key: const ValueKey('file-detail-view'),
          shrinkWrap: true,
          data: _viewData(context),
        ),
      ),
    );
  }
}

// ─── Audio host (editable, id-driven) ───────────────────────────────────────

/// The audio detail host: loads the recording via [detailsControllerProvider]
/// and renders it through the unified [FileView] — audio Contents reads the
/// machine `transcript` column (read-only), Notes reads/writes the user-owned
/// `notes` column. Owns the Notes save, the unsaved-changes leave guard, and the
/// retry / delete / move-to-space actions ported from the retired details
/// screen. Default focus is Contents; the Notes field is not auto-opened.
class _AudioDetailHost extends ConsumerStatefulWidget {
  const _AudioDetailHost({required this.id});

  final String id;

  @override
  ConsumerState<_AudioDetailHost> createState() => _AudioDetailHostState();
}

class _AudioDetailHostState extends ConsumerState<_AudioDetailHost> {
  final TextEditingController _notesController = TextEditingController();
  // The text last persisted — the isDirty baseline. Wrapped in a DirtyTracker so
  // the unsaved-changes leave guard matches the retired details-screen semantics.
  late DirtyTracker _dirty;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _dirty = DirtyTracker('');
    _notesController.addListener(() {
      _dirty.setTranscript(_notesController.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _isDirty => _dirty.isDirty;

  void _syncFromState(DetailsState state) {
    if (_initialized || state.isLoading || state.row == null) return;
    _initialized = true;
    final notes = state.row?.notes ?? '';
    _dirty = DirtyTracker(notes);
    _notesController.text = notes;
  }

  Future<void> _save() async {
    final controller =
        ref.read(detailsControllerProvider(widget.id).notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.save(_notesController.text);
      _dirty.save();
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(SnackBar(content: Text(t.details.saved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.details.saveFailed)));
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;

        return AppDialog(
          title: Text(t.details.unsavedTitle),
          content: Text(t.details.unsavedBody),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.details.keepEditing),
            ),
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: colors.failed),
              child: Text(t.details.discard),
            ),
          ],
        );
      },
    );
    if (discard == true) {
      // Reset the baseline so a re-render on the way out doesn't re-trigger the
      // guard (W-02 avoidance, ported from the retired details screen).
      _dirty.discard(_notesController.text);
    }
    return discard ?? false;
  }

  Future<void> _onRetry() async {
    await ref.read(detailsControllerProvider(widget.id).notifier).retry();
  }

  void _onDelete() => _fileDeleteFlow(
        context,
        ref,
        widget.id,
        // Clear dirty so the leave-guard doesn't block the post-delete pop.
        onBeforeDelete: () => _dirty.discard(_notesController.text),
      );

  FileViewData _viewData(DetailsState state) {
    final row = state.row;
    return FileViewData(
      title: state.title,
      mediaKind: FileMediaKind.audio,
      place: row?.badge,
      syncCoreId: state.coreId,
      processingStatus: row?.processingStatus,
      mediaHeader: AudioPlayerBar(source: state.audioSource),
      // Contents (audio → "Transcript") reads the machine-owned transcript
      // column (#1439) and renders the #1440 state machine driven by the
      // recording's OWN fields — not a backend producer.
      contentsText: row?.transcript,
      contentsState: _contentsState(state),
      onContentsRetry: _onRetry,
      // Notes seed is unused here — the host owns [_notesController] so dirty
      // tracking and save work — but kept for parity with the image path.
      notesText: row?.notes,
    );
  }

  /// Derives the honest Contents state from the recording's existing fields:
  /// a failed transcription → failed (+retry); in-flight → processing; present
  /// transcript text → ready; otherwise → empty ("No transcript yet"). This is
  /// producer-independent — it reads only the loaded row's own status.
  ContentsState _contentsState(DetailsState state) {
    if (state.processingFailed) return ContentsState.failed;
    if (state.isProcessing) return ContentsState.processing;
    final transcript = state.row?.transcript;
    if (transcript != null && transcript.trim().isNotEmpty) {
      return ContentsState.ready;
    }
    return ContentsState.empty;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailsControllerProvider(widget.id));
    final colors = context.colors;
    final spacing = context.spacing;
    final dirtyDotOffset = -spacing.xs / spacing.xxs;
    final dirtyDotSize = spacing.xs + spacing.xs / spacing.xxs;
    _syncFromState(state);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldLeave = await _confirmLeave();
        if (shouldLeave && mounted) {
          navigator.maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          surfaceTintColor: colors.background,
          title: Text(
            state.title.isEmpty ? t.recording.title : state.title,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (!state.isLoading && !state.notFound)
              FileActionsMenu(onDelete: _onDelete),
          ],
        ),
        floatingActionButton: (state.isLoading || state.notFound)
            ? null
            : FloatingActionButton(
                heroTag: 'file-detail-save',
                onPressed: _save,
                backgroundColor: colors.accent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.check, color: colors.onAccent),
                    if (_isDirty)
                      Positioned(
                        right: dirtyDotOffset,
                        top: dirtyDotOffset,
                        child: Container(
                          width: dirtyDotSize,
                          height: dirtyDotSize,
                          decoration: BoxDecoration(
                            color: colors.failed,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.accent, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        body: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(DetailsState state) {
    final colors = context.colors;
    final typography = context.typography;

    if (state.isLoading) {
      return Center(child: LoadingIndicator(color: colors.accent));
    }
    if (state.notFound) {
      return Center(
        child: Text(
          t.details.notFound,
          style: typography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    // Failed / pending-upload rows surface the retry CTA inline above the
    // unified composition rather than the old per-tab Notes affordance.
    return fileReadingCard(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.processingFailed || state.pendingUpload)
            _RetryBanner(
              label: state.pendingUpload
                  ? t.cardStatus.pendingUpload
                  : t.recording.transcriptionFailed,
              onRetry: _onRetry,
            ),
          FileView(
            key: const ValueKey('file-detail-view'),
            shrinkWrap: true,
            data: _viewData(state),
            notesController: _notesController,
            onNotesChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

/// Inline retry affordance for a failed / pending-upload audio recording, shown
/// above the unified [FileView] composition.
class _RetryBanner extends StatelessWidget {
  const _RetryBanner({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      color: colors.subtleFill,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
          AppTextButton.icon(
            key: const ValueKey('file-detail-retry'),
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: spacing.md),
            label: Text(t.common.retry),
            style: TextButton.styleFrom(
              foregroundColor: colors.onAccent,
              backgroundColor: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image media header + fullscreen viewer ─────────────────────────────────

/// The inline, framed image preview shown as [FileView]'s media header. Tapping
/// it opens the fullscreen viewer — the lightbox is now a header *action*, not
/// the whole screen.
class _ImageMediaHeader extends StatelessWidget {
  const _ImageMediaHeader({required this.path, required this.onOpenFullscreen});

  final String? path;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final spacing = context.spacing;
    final typography = context.typography;
    final path = this.path;

    final Widget frame = path == null
        ? const _UnavailableFrame()
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _UnavailableFrame(),
          );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.lg),
      child: InkWell(
        key: const ValueKey('file-detail-image-header'),
        onTap: path == null ? null : onOpenFullscreen,
        borderRadius: BorderRadius.circular(radius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: frame,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fullscreen,
                    size: typography.label.fontSize,
                    color: colors.textSecondary,
                  ),
                  SizedBox(width: spacing.xxs),
                  Text(
                    t.fileView.viewFullscreen,
                    style: typography.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder frame for a missing / unreadable image. Carries an accessible
/// label without leaking a visual literal past the design-system source guard.
class _UnavailableFrame extends StatelessWidget {
  const _UnavailableFrame();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: t.matome.imageUnavailable,
      child: ColoredBox(
        color: colors.subtleFill,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: colors.textMuted),
        ),
      ),
    );
  }
}

/// Fullscreen pinch-zoom viewer — the relocated lightbox, now a media-header
/// action rather than the entire image experience.
class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          key: const ValueKey('file-detail-fullscreen-viewer'),
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _ViewerUnavailable(),
          ),
        ),
      ),
    );
  }
}

class _ViewerUnavailable extends StatelessWidget {
  const _ViewerUnavailable();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    return Padding(
      padding: EdgeInsets.all(spacing.xl),
      child: Text(
        t.matome.imageUnavailable,
        style: typography.bodySmall.copyWith(color: colors.textMuted),
      ),
    );
  }
}
