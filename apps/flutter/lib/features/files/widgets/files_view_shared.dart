// Shared contract + chrome for the graduated Files view (DR-000 / DR-003, #1465).
//
// CONVERGENCE: `FilesGrid` and `FilesTable` are the two takes on the same data
// (the [FileRow] view-model from #1461) and share one selection / bulk-action /
// undo model. The pieces that BOTH surfaces use — the sort/action enums, the
// typed callback signatures, the confirm dialog, the bulk bar, the undo bar, the
// empty state, the per-file overflow menu, and the kind→icon mapping — live here
// so the two widgets stay in lockstep and there is one place to read the
// contract.
//
// Strictly presentational: props in, typed callbacks out. No providers, no
// navigation, no DB. The host ([FilesScreen]) builds the data from the
// owner-scoped provider and wires the callbacks (open → go_router, delete →
// DAO + SnackBar). The widgets own only EPHEMERAL UI state (selection, sort,
// the in-widget undo stash) so they are fully demonstrable in Widgetbook.

import 'package:flutter/material.dart';

import '../../../core/db/file_row.dart';
import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_dialog.dart';
import '../../../ui/file_type_chip.dart';

/// Sortable columns in the Files table. "When" is the default (newest-first);
/// Matome / Space / People / Sync are display-only columns.
enum FileSortKey { name, when, size }

/// Per-file overflow-menu actions and the targets of the bulk-action bar.
enum FileAction { open, moveToMatome, download, delete }

/// Open one file (row/tile tap, Enter, per-file Open). Host → navigation.
typedef FileOpenCallback = void Function(String id);

/// The active sort changed (column header / compact pill).
typedef FileSortCallback = void Function(FileSortKey sort, bool ascending);

/// The live selection changed.
typedef FileSelectionCallback = void Function(Set<String> ids);

/// A move / download / delete op was confirmed on a set of file ids. Host →
/// DAO + timed Undo. (The widgets also keep an in-widget undo affordance so the
/// recovery path is demonstrable with no host wiring.)
typedef FileBulkCallback = void Function(FileAction action, Set<String> ids);

/// Kind → (icon, tint). Documents fall through to the extension-specific glyph
/// via [FileTypeChip.iconForExtension] so a pdf/docx/xlsx reads at a glance.
({IconData icon, Color color}) fileKindVisual(BuildContext context, FileRow f) {
  final colors = context.colors;
  return switch (f.kind) {
    FileKind.audio => (icon: Icons.mic_none_rounded, color: colors.accentDark),
    FileKind.image => (icon: Icons.image_outlined, color: colors.badgeIdeas),
    FileKind.document => (
        icon: FileTypeChip.iconForExtension(f.ext),
        color: colors.textSecondary,
      ),
  };
}

/// What Undo restores: files removed by the last destructive op, with the index
/// they held in the master list so reinsert keeps original order.
class FilesUndoStash {
  const FilesUndoStash(this.message, this.removed, this.priorSelection);

  final String message;
  final List<MapEntry<int, FileRow>> removed; // (masterIndex, file), ascending
  final Set<String> priorSelection;
}

/// Shared destructive-op confirm: a confirm + undo is the approved delete model
/// (DR-003). Returns true when the user confirms.
Future<bool> confirmDeleteFiles(BuildContext context, int n) async {
  final colors = context.colors;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      backgroundColor: colors.surface,
      title: Text(t.files.deleteTitle),
      content: Text(t.files.deleteBody(n: n)),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(t.files.cancel),
        ),
        PrimaryButton(
          key: const ValueKey('files-delete-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.failed),
          child: Text(t.files.delete),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// The dash a caller renders when a per-file value (size / people) is absent.
class FilesMutedDash extends StatelessWidget {
  const FilesMutedDash({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      t.files.noSize,
      style: typography.label.copyWith(color: colors.textMuted),
    );
  }
}

/// Per-file overflow menu — the real affordance, shared by grid tiles + table
/// rows. Emits a [FileAction]; the parent maps it to a callback.
class FileActionsMenu extends StatelessWidget {
  const FileActionsMenu({super.key, required this.onAction});

  final ValueChanged<FileAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget item(IconData icon, String label, FileAction action,
        {Color? color}) {
      return MenuItemButton(
        leadingIcon: Icon(icon,
            size: context.typography.body.fontSize,
            color: color ?? colors.textSecondary),
        onPressed: () => onAction(action),
        child: Text(
          label,
          style:
              typography.bodySmall.copyWith(color: color ?? colors.textPrimary),
        ),
      );
    }

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radius.md),
            side: BorderSide(color: colors.border),
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: spacing.xs),
        ),
      ),
      builder: (context, controller, child) => IconButton(
        icon: Icon(Icons.more_horiz,
            size: context.typography.body.fontSize, color: colors.textMuted),
        tooltip: t.files.fileActions,
        padding: EdgeInsets.zero,
        constraints:
            BoxConstraints(minWidth: spacing.xl, minHeight: spacing.xl),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        item(Icons.open_in_new, t.files.open, FileAction.open),
        item(Icons.drive_file_move_outlined, t.files.moveToMatome,
            FileAction.moveToMatome),
        item(Icons.download_outlined, t.files.download, FileAction.download),
        Divider(height: spacing.sm, color: colors.border),
        item(Icons.delete_outline, t.files.delete, FileAction.delete,
            color: colors.failed),
      ],
    );
  }
}

/// The bulk-action bar shown while a selection is active: clear, the count, and
/// the move / download / delete actions (DR-003).
class FilesBulkBar extends StatelessWidget {
  const FilesBulkBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onMove,
    required this.onDownload,
    required this.onDelete,
    this.leadingWidth,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  /// When set, the clear button is boxed to this width so it aligns with the
  /// table's checkbox column. Null → the button sizes to itself (grid).
  final double? leadingWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final clear = IconButton(
      icon: Icon(Icons.close,
          size: context.typography.body.fontSize, color: colors.accentDark),
      visualDensity: VisualDensity.compact,
      tooltip: t.files.clear,
      onPressed: onClear,
    );

    return Container(
      key: const ValueKey('files-bulk-bar'),
      color: colors.accentSoft,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          if (leadingWidth != null)
            SizedBox(width: leadingWidth, child: clear)
          else
            clear,
          SizedBox(width: spacing.xxs),
          Text(
            t.files.selected(n: count),
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilesBulkAction(
                icon: Icons.drive_file_move_outlined,
                label: t.files.moveToMatome,
                onPressed: onMove,
              ),
              _FilesBulkAction(
                icon: Icons.download_outlined,
                label: t.files.download,
                onPressed: onDownload,
              ),
              _FilesBulkAction(
                icon: Icons.delete_outline,
                label: t.files.delete,
                onPressed: onDelete,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilesBulkAction extends StatelessWidget {
  const _FilesBulkAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final fg = danger ? colors.failed : colors.textPrimary;

    return AppTextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: context.typography.body.fontSize, color: fg),
      label: Text(label, style: typography.label.copyWith(color: fg)),
      style: TextButton.styleFrom(
        padding:
            EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// The recovery half of a destructive op: a message + Undo + dismiss.
class FilesUndoBar extends StatelessWidget {
  const FilesUndoBar({
    super.key,
    required this.message,
    required this.onUndo,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      key: const ValueKey('files-undo-bar'),
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          Icon(Icons.history,
              size: context.typography.body.fontSize,
              color: colors.textSecondary),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          AppTextButton(onPressed: onUndo, child: Text(t.files.undo)),
          IconButton(
            icon: Icon(Icons.close,
                size: context.typography.body.fontSize,
                color: colors.textMuted),
            visualDensity: VisualDensity.compact,
            tooltip: t.files.clear,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The empty state both surfaces show when there are no files.
class FilesEmptyState extends StatelessWidget {
  const FilesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: context.spacing.xl, color: colors.border),
          SizedBox(height: spacing.sm),
          Text(
            t.files.emptyTitle,
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            t.files.emptyBody,
            textAlign: TextAlign.center,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
