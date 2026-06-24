// The Files section host (DR-003 / #1465): the `/files` screen that lists the
// CURRENT OWNER's files across all matomes AND loose/Unfiled rows (owner-scoped
// via the #1461 provider) and hosts the graduated `FilesGrid` / `FilesTable`.
//
// This is the wiring layer the presentational widgets deliberately lack: it
// reads the owner-scoped provider, maps each widget callback to real behaviour
// (open → go_router by media type; delete → DAO hard-delete + re-read; move →
// flagged stub; download → flagged stub), and renders the grid↔table layout the
// persisted [filesViewProvider] holds (the on-screen toggle was removed in
// #1474; Settings → "Default views" is the single control, #1468).
//
// NOTE (#1467): `/files` is reachable by deep-link / temporary entry; it is not
// yet a shipped nav destination. The nav cutover wires the destination later.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/feature_flags.dart';
import '../../core/db/app_database.dart' show MatomeRow, WorkspaceRow;
import '../../core/db/file_row.dart';
import '../../core/providers.dart';
import '../../core/settings/reading_pane.dart';
import '../../core/settings/settings_store.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/files_scope_filter.dart';
import '../../ui/loading_indicator.dart';
import '../../ui/master_detail_scaffold.dart';
import '../details/details_controller.dart';
import '../details/file_detail_screen.dart' show mediaKindForType;
import '../details/file_view.dart';
import '../home/inbox_controller.dart';
import 'files_providers.dart';
import 'widgets/files_grid.dart';
import 'widgets/files_table.dart';
import 'widgets/files_view_shared.dart';

/// Which Files layout is showing (grid ↔ table). A user-selectable view
/// controlled from Settings → "Default views" (#1468); the on-screen AppBar
/// toggle was removed (#1474) so Settings is the single control. The screen
/// still renders whichever view [filesViewProvider] holds, and the choice
/// survives a restart.
enum FilesView { grid, table }

const _filesViewKey = 'matome.files_view';

/// Persisted controller for [FilesView], hydrated from / written to the secure
/// [SettingsStore] (#1468). Mirrors [InboxViewController]: default is
/// [FilesView.grid] until the stored value loads.
class FilesViewController extends StateNotifier<FilesView> {
  FilesViewController(this._store) : super(FilesView.grid) {
    _hydrate();
  }

  final SettingsStore _store;

  Future<void> _hydrate() async {
    final view = _parse(await _store.read(_filesViewKey));
    if (view != null && mounted) state = view;
  }

  Future<void> setView(FilesView view) async {
    state = view;
    await _store.write(_filesViewKey, view.name);
  }

  static FilesView? _parse(String? raw) {
    for (final v in FilesView.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

final filesViewProvider =
    StateNotifierProvider<FilesViewController, FilesView>(
  (ref) => FilesViewController(ref.watch(settingsStoreProvider)),
);

/// The reading-width cap for the centred content on wide windows. Used only on
/// the shipped (flag-OFF) path; the [MasterDetailScaffold] path renders the
/// master full-width (no 1080 cap) so the right reading pane fills the freed
/// whitespace.
const double _kFilesMaxWidth = 1080;

/// Selected Files row for the master-detail reading pane (W3, #1542). On
/// expanded widths with the reading pane on the right, tapping a file sets this
/// instead of navigating, so the grid/table stays visible beside the
/// [_FilesPaneDetail] reading pane. Narrower widths (and the flag-OFF reality)
/// ignore it and route to `/recording/...` as before — the [selectsOnTap]
/// predicate in [_FilesScreenState._openFile] is the single source of truth.
final filesSelectionProvider = StateProvider<String?>((ref) => null);

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  /// The active Files filter (All / Loose / In-space), local UI state. Default
  /// All. Loose ⟺ effective space NULL, In-space ⟺ effective space non-null —
  /// both resolved via the ONE resolver (`FileRow.effectiveInSpace`), never an
  /// inline recompute (spec R1.2).
  FilesScope _scope = FilesScope.all;

  /// Partition [files] by the active [_scope] using the resolver-backed
  /// effective-space bit on each [FileRow]. No re-resolution here — the bit was
  /// computed once in the DAO via `EffectiveSpace.effectiveSpaceId`.
  List<FileRow> _applyScope(List<FileRow> files) {
    return switch (_scope) {
      FilesScope.all => files,
      FilesScope.loose => files.where((f) => f.loose).toList(growable: false),
      FilesScope.inSpace =>
        files.where((f) => f.effectiveInSpace).toList(growable: false),
    };
  }

  /// Clear the reading-pane selection so it never points at a file that is no
  /// longer in the loaded list (deleted, moved out of scope, or absent after a
  /// reload). Only meaningful behind the master-detail layout (where the pane is
  /// driven by [filesSelectionProvider]); a no-op cost otherwise.
  void _clearFilesSelection() {
    if (ref.read(filesSelectionProvider) != null) {
      ref.read(filesSelectionProvider.notifier).state = null;
    }
  }

  Future<void> _openFile(String fileId) async {
    // W3 (#1542): the unified [MasterDetailScaffold] owns the layout decision;
    // its [selectsOnTap] predicate is the single source of truth for whether a
    // tap selects in-pane (pane reality) or navigates full-screen.
    if (FeatureFlags.masterDetailLayout &&
        MasterDetailScaffold.selectsOnTap(
          context,
          ref.read(readingPaneModeProvider(ReadingPaneSurface.files)),
        )) {
      ref.read(filesSelectionProvider.notifier).state = fileId;
      return;
    }
    // A file is a recording; route by its media type so a document/image never
    // hits the audio-only detail host (mirrors the contacts host, #1464).
    final row = await ref.read(recordingsDaoProvider).getRecordingById(fileId);
    if (!mounted) return;
    final mediaType = row?.mediaType ?? 'audio';
    final path = switch (mediaType) {
      'image' => '/recording/image/$fileId',
      'document' => '/recording/document/$fileId',
      _ => '/recording/detail/$fileId',
    };
    context.push(path);
  }

  Future<void> _onBulk(FileAction action, Set<String> ids) async {
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case FileAction.open:
        break; // handled by onOpen
      case FileAction.moveToMatome:
        await _moveToMatome(ids);
      case FileAction.fileIntoSpace:
        await _fileIntoSpace(ids);
      case FileAction.download:
        // FLAGGED STUB (#1465): there is no file-download path in the client
        // yet, so download surfaces a "not available" notice instead of
        // pretending to download.
        messenger.showSnackBar(
          SnackBar(content: Text(t.files.downloadUnavailable)),
        );
      case FileAction.delete:
        // Permanent hard-delete — the widget already gated it behind a confirm
        // and shows the in-widget Undo affordance. After deleting we re-read the
        // owner-scoped provider so the rows drop out (mirrors the matome table).
        final dao = ref.read(recordingsDaoProvider);
        for (final id in ids) {
          await dao.deleteRecording(id);
        }
        ref.invalidate(filesForCurrentOwnerProvider);
        if (!mounted) return;
        // Never leave the reading pane pointing at a deleted file.
        if (ids.contains(ref.read(filesSelectionProvider))) {
          _clearFilesSelection();
        }
        messenger.showSnackBar(
          SnackBar(content: Text(t.files.deletedMsg(n: ids.length))),
        );
    }
  }

  /// Real move-to-matome (#1473): open the owner-scoped target picker, reassign
  /// `recordings.matome_id` via the DAO (owner-scoped — a move can never target
  /// or touch another owner's row), invalidate the files provider so the rows
  /// re-read with their new matome, and offer an Undo that restores the prior
  /// matome of every moved file (NULL ⟺ back to Unfiled).
  Future<void> _moveToMatome(Set<String> ids) async {
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    final dao = ref.read(recordingsDaoProvider);

    final targets =
        await ref.read(matomeTargetsForCurrentOwnerProvider.future);
    if (!mounted) return;
    if (targets.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.files.moveNoTargets)));
      return;
    }

    // (targetMatomeId) — null sentinel via the Unfiled tile; a non-selection
    // (dismiss) returns no value and aborts.
    final picked = await showAppBottomSheet<_MoveTarget>(
      context: context,
      builder: (_) => _MoveToMatomeSheet(targets: targets),
    );
    if (picked == null || !mounted) return;

    // Stash the prior filing BEFORE the write so Undo can restore it.
    final prior = await dao.matomeIdsForOwnedRecordings(ids, ownerId);
    final moved =
        await dao.moveRecordingsToMatome(ids, picked.matomeId, ownerId);
    ref.invalidate(filesForCurrentOwnerProvider);
    ref.invalidate(matomeTargetsForCurrentOwnerProvider);
    if (!mounted) return;
    if (moved == 0) return; // owner-scope rejected it — nothing moved.

    messenger.showSnackBar(
      SnackBar(
        content: Text(t.files.movedMsg(n: moved)),
        action: SnackBarAction(
          label: t.files.undo,
          onPressed: () async {
            await dao.restoreRecordingMatomes(prior, ownerId);
            ref.invalidate(filesForCurrentOwnerProvider);
            ref.invalidate(matomeTargetsForCurrentOwnerProvider);
          },
        ),
      ),
    );
  }

  /// File the selected loose items DIRECTLY into a space (no matome) — the
  /// local-first-spaces #102 W6 / #1501 file-into-space flow. Opens the
  /// space-target picker (owner's spaces + an "Inbox" tile that clears the
  /// space), then routes each pick through [InboxController.fileIntoSpace] which
  /// is OWNER-SCOPED on the assign AND gates the Core egress: filing into a
  /// LOCAL space holds locally (no upload); filing into a CLOUD space lets the
  /// gate drain it — sync follows the space type, enforced by the gate not the
  /// picker (spec R2).
  Future<void> _fileIntoSpace(Set<String> ids) async {
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;

    final targets = await ref.read(workspacesDaoProvider).getWorkspaces();
    if (!mounted) return;
    if (targets.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.files.fileNoSpaces)));
      return;
    }

    final picked = await showAppBottomSheet<_FileSpaceTarget>(
      context: context,
      builder: (_) => _FileIntoSpaceSheet(targets: targets),
    );
    if (picked == null || !mounted) return;

    final inbox = ref.read(inboxControllerProvider.notifier);
    var filed = 0;
    for (final id in ids) {
      final ok = await inbox.fileIntoSpace(id, picked.spaceId, ownerId: ownerId);
      if (ok) filed++;
    }
    ref.invalidate(filesForCurrentOwnerProvider);
    if (!mounted || filed == 0) return;
    messenger.showSnackBar(
      SnackBar(content: Text(t.files.filedMsg(n: filed))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final async = ref.watch(filesForCurrentOwnerProvider);
    final view = ref.watch(filesViewProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(
          t.files.title,
          style: context.typography.title.copyWith(color: colors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => Center(child: LoadingIndicator(color: colors.primary)),
          error: (err, _) => _CenteredMessage(message: err.toString()),
          data: (files) {
            final scoped = _applyScope(files);

            // W3 (#1542): never point the reading pane at a file that has left
            // the loaded list (deleted / filed / out of the active scope /
            // absent after a reload). Reconcile after the frame so we don't
            // mutate a provider mid-build. Only meaningful behind the flag.
            if (FeatureFlags.masterDetailLayout) {
              final selectedId = ref.watch(filesSelectionProvider);
              if (selectedId != null &&
                  !scoped.any((f) => f.id == selectedId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _clearFilesSelection();
                });
              }
            }

            if (FeatureFlags.masterDetailLayout) {
              // W3 (#1542): the Files surface renders through the unified
              // [MasterDetailScaffold]. The scaffold owns the layout decision
              // (master full-width vs master + reading pane) from the
              // per-surface [readingPaneModeProvider] and the current width
              // class; tap-vs-navigate is decided by the same [selectsOnTap]
              // predicate in [_openFile], so the two can never drift. The
              // master is the grid/table at FULL WIDTH (no 1080 centring) so the
              // freed whitespace is filled by the pane (the original complaint).
              final selectedId = ref.watch(filesSelectionProvider);
              return MasterDetailScaffold(
                master: _master(scoped, view, centered: false),
                detail: selectedId != null
                    ? _FilesPaneDetail(
                        key: ValueKey(selectedId),
                        id: selectedId,
                      )
                    : null,
                emptyState: const _FilesPaneEmptyState(),
                mode: ref.watch(
                  readingPaneModeProvider(ReadingPaneSurface.files),
                ),
              );
            }

            // Shipped behaviour (flag OFF): the centred 1080 column, byte-for-
            // byte unchanged.
            return _master(scoped, view, centered: true);
          },
        ),
      ),
    );
  }

  /// The master column: the (flag-gated) scope filter above the grid/table.
  /// [centered] = true wraps it in the shipped `SingleChildScrollView > Align >
  /// ConstrainedBox(1080)` (flag-OFF reality); [centered] = false renders it
  /// full-width with just padding (the [MasterDetailScaffold] path), so the
  /// reading pane fills the freed whitespace.
  Widget _master(List<FileRow> scoped, FilesView view, {required bool centered}) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Files filter (All / Loose / In-space) — wired to the resolver-backed
        // effective-space bit (#1501). Surfaced only behind the local-first-
        // spaces flag; the `const if` tree-shakes it out when OFF (shipped
        // reality).
        if (FeatureFlags.localFirstSpaces) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilesScopeFilter(
              value: _scope,
              allLabel: t.files.scopeAll,
              looseLabel: t.files.scopeLoose,
              inSpaceLabel: t.files.scopeInSpace,
              onChanged: (s) => setState(() => _scope = s),
            ),
          ),
          SizedBox(height: context.spacing.md),
        ],
        view == FilesView.grid
            ? FilesGrid(
                files: scoped,
                onOpen: _openFile,
                onBulk: _onBulk,
              )
            : FilesTable(
                files: scoped,
                onOpen: _openFile,
                onBulk: _onBulk,
              ),
      ],
    );

    if (!centered) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(context.spacing.lg),
        child: column,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kFilesMaxWidth),
          child: column,
        ),
      ),
    );
  }
}

/// The reading-pane detail for a selected file (W3, #1542). Renders the SAME
/// presentational [FileView] the file detail screen uses, fed off the SAME data
/// source ([detailsControllerProvider]) — NOT the multi-Scaffold
/// [FileDetailScreen]. There is no Scaffold/AppBar here: the pane is embedded
/// beside the master, so it owns no chrome. Notes are read-only in the pane (the
/// full edit lifecycle — dirty tracking, leave-guard, save FAB — lives on the
/// routed [FileDetailScreen]); the pane is the at-a-glance read surface.
class _FilesPaneDetail extends ConsumerWidget {
  const _FilesPaneDetail({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(detailsControllerProvider(id));

    if (state.isLoading) {
      return ColoredBox(
        color: colors.background,
        child: Center(child: LoadingIndicator(color: colors.primary)),
      );
    }
    final row = state.row;
    if (state.notFound || row == null) {
      return const _FilesPaneEmptyState();
    }

    final mediaKind = mediaKindForType(row.mediaType);
    return ColoredBox(
      color: colors.background,
      child: FileView(
        key: const ValueKey('files-pane-view'),
        data: FileViewData(
          title: state.title.isEmpty ? t.recording.title : state.title,
          mediaKind: mediaKind,
          place: row.badge,
          syncCoreId: state.coreId,
          processingStatus: row.processingStatus,
          // The machine-owned Contents (audio → transcript, doc → stub summary;
          // image keeps it null). Read-only, derived from the row's OWN fields.
          contentsText: mediaKind == FileMediaKind.image ? null : row.transcript,
          notesText: row.notes,
        ),
        // The pane is a read surface — the editable Notes lifecycle stays on the
        // routed detail screen.
        notesReadOnly: true,
      ),
    );
  }
}

/// The "select a file to read it here" teaching placeholder shown in the
/// reading pane when nothing is selected.
class _FilesPaneEmptyState extends StatelessWidget {
  const _FilesPaneEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return ColoredBox(
      color: colors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: spacing.xxl,
              color: colors.textMuted,
            ),
            SizedBox(height: spacing.sm),
            Text(
              t.files.selectHint,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The result of the move picker — a chosen matome id, or null ⟺ Unfiled.
/// A dedicated type (vs a bare nullable String) so the sheet can distinguish
/// "picked Unfiled" (a real choice) from "dismissed" (the sheet returns null).
class _MoveTarget {
  const _MoveTarget(this.matomeId);
  final String? matomeId;
}

/// Filing-target picker for the Files view's "Move to matome" action (#1473) —
/// mirrors [_MoveToSpaceSheet] (keyed ListTiles in an [AppBottomSheet]). Lists
/// the OWNER's matomes (owner-scoped upstream) plus an "Unfiled" tile that moves
/// the files OUT of any matome (`matome_id` → NULL).
class _MoveToMatomeSheet extends StatelessWidget {
  const _MoveToMatomeSheet({required this.targets});

  final List<MatomeRow> targets;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        t.files.moveSheetTitle,
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        ListTile(
          key: const ValueKey('files-move-target-unfiled'),
          leading: Icon(Icons.inbox_outlined, color: colors.textSecondary),
          title: Text(t.files.moveUnfiled),
          trailing: Text(
            t.files.moveUnfiledHint,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          onTap: () => Navigator.of(context).pop(const _MoveTarget(null)),
        ),
        for (final m in targets)
          ListTile(
            key: ValueKey('files-move-target-${m.id}'),
            leading:
                Icon(Icons.folder_outlined, color: colors.textSecondary),
            title: Text(m.title),
            onTap: () => Navigator.of(context).pop(_MoveTarget(m.id)),
          ),
      ],
    );
  }
}

/// The result of the file-into-space picker — a chosen space id, or null ⟺
/// Inbox (clear the space). A dedicated type (vs a bare nullable String) so the
/// sheet distinguishes "picked Inbox" (a real choice) from "dismissed" (null).
class _FileSpaceTarget {
  const _FileSpaceTarget(this.spaceId);
  final String? spaceId;
}

/// Space-target picker for the Files view's "File into space" action (#1501) —
/// mirrors [_MoveToMatomeSheet]. Lists the owner's spaces plus an "Inbox" tile
/// that files the items OUT of any space (`workspace_id` → NULL). Filing here is
/// pure organization; whether it SYNCS is decided downstream by the gate (filing
/// ≠ sync, spec R2) — the sheet never makes that decision.
class _FileIntoSpaceSheet extends StatelessWidget {
  const _FileIntoSpaceSheet({required this.targets});

  final List<WorkspaceRow> targets;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        t.files.fileIntoSpace,
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        ListTile(
          key: const ValueKey('files-space-target-inbox'),
          leading: Icon(Icons.inbox_outlined, color: colors.textSecondary),
          title: Text(t.files.fileIntoSpaceInbox),
          trailing: Text(
            t.files.fileIntoSpaceInboxHint,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          onTap: () => Navigator.of(context).pop(const _FileSpaceTarget(null)),
        ),
        for (final w in targets)
          ListTile(
            key: ValueKey('files-space-target-${w.id}'),
            leading: Icon(
              w.isLocal == 1
                  ? Icons.workspaces_outline
                  : Icons.cloud_outlined,
              color: colors.textSecondary,
            ),
            title: Text(w.name),
            onTap: () => Navigator.of(context).pop(_FileSpaceTarget(w.id)),
          ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.typography.bodySmall
              .copyWith(color: context.colors.textMuted),
        ),
      ),
    );
  }
}
