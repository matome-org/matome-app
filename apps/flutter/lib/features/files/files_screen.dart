// The Files section host (DR-003 / #1465): the `/files` screen that lists the
// CURRENT OWNER's files across all matomes AND loose/Unfiled rows (owner-scoped
// via the #1461 provider) and hosts the graduated `FilesGrid` / `FilesTable`.
//
// This is the wiring layer the presentational widgets deliberately lack: it
// reads the owner-scoped provider, maps each widget callback to real behaviour
// (open → go_router by media type; delete → DAO hard-delete + re-read; move →
// flagged stub; download → flagged stub), and owns the grid↔table view toggle as
// LOCAL view state (the PERSISTED preference is #1468 — not built here).
//
// NOTE (#1467): `/files` is reachable by deep-link / temporary entry; it is not
// yet a shipped nav destination. The nav cutover wires the destination later.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart' show MatomeRow;
import '../../core/providers.dart';
import '../../core/settings/settings_store.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/loading_indicator.dart';
import 'files_providers.dart';
import 'widgets/files_grid.dart';
import 'widgets/files_table.dart';
import 'widgets/files_view_shared.dart';

/// Which Files layout is showing (grid ↔ table). A user-selectable view: the
/// AppBar toggle and the Settings radio (#1468) both drive the SAME persisted
/// preference via [filesViewProvider], so the choice survives a restart and the
/// two controls stay in sync.
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

/// The reading-width cap for the centred content on wide windows.
const double _kFilesMaxWidth = 1080;

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  Future<void> _openFile(String fileId) async {
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
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.spacing.md),
            child: _FilesViewToggle(
              view: view,
              onToggle: (v) => ref.read(filesViewProvider.notifier).setView(v),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => Center(child: LoadingIndicator(color: colors.primary)),
          error: (err, _) => _CenteredMessage(message: err.toString()),
          data: (files) => SingleChildScrollView(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kFilesMaxWidth),
                child: view == FilesView.grid
                    ? FilesGrid(
                        files: files,
                        onOpen: _openFile,
                        onBulk: _onBulk,
                      )
                    : FilesTable(
                        files: files,
                        onOpen: _openFile,
                        onBulk: _onBulk,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid↔table view toggle, mirroring the inbox cards↔table toggle.
class _FilesViewToggle extends StatelessWidget {
  const _FilesViewToggle({required this.view, required this.onToggle});

  final FilesView view;
  final ValueChanged<FilesView> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget segment(FilesView value, IconData icon, String label) {
      final active = view == value;
      return Semantics(
        button: true,
        selected: active,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            key: ValueKey('files-view-${value.name}'),
            borderRadius: BorderRadius.circular(radius.sm),
            onTap: () => onToggle(value),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              child: Icon(
                icon,
                size: typography.body.fontSize,
                color: active ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(FilesView.grid, Icons.grid_view_outlined, t.files.viewGrid),
          segment(
              FilesView.table, Icons.table_rows_outlined, t.files.viewTable),
        ],
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
