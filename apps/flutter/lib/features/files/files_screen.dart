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

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/loading_indicator.dart';
import 'files_providers.dart';
import 'widgets/files_grid.dart';
import 'widgets/files_table.dart';
import 'widgets/files_view_shared.dart';

/// Which Files layout is showing. The persisted preference lands in #1468; here
/// it is ephemeral local view state.
enum FilesView { grid, table }

/// The reading-width cap for the centred content on wide windows.
const double _kFilesMaxWidth = 1080;

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  FilesView _view = FilesView.grid;

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
        // FLAGGED STUB (#1465): a files→matome move target picker is not built
        // yet (config/#1468 territory). Acknowledge so the affordance is honest
        // rather than silently doing nothing.
        messenger.showSnackBar(
          SnackBar(content: Text(t.files.moveToMatome)),
        );
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final async = ref.watch(filesForCurrentOwnerProvider);

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
              view: _view,
              onToggle: (v) => setState(() => _view = v),
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
                child: _view == FilesView.grid
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
