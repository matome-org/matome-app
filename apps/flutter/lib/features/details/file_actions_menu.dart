import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';

/// The consistent overflow "…" menu for a FILE (recording / image), shown as a
/// [MenuAnchor] popup ANCHORED to its trigger — matching the matome actions menu
/// instead of a bottom sheet sliding up from the screen edge. Holds a single
/// destructive Delete (a file does not move between spaces — only the whole
/// matome does). Used by the matome Item tile (dense) and the file-detail
/// screens (audio + image), so every "…" on a file behaves the same.
class FileActionsMenu extends StatelessWidget {
  const FileActionsMenu({
    super.key,
    required this.onDelete,
    this.dense = false,
    this.triggerKey,
    this.deleteKey,
  });

  /// Destructive delete/remove action (rendered red).
  final VoidCallback onDelete;

  /// Tighter trigger for list rows (smaller icon, no padding, compact target).
  final bool dense;

  /// Optional keys for the trigger button and the delete entry (test reach).
  final Key? triggerKey;
  final Key? deleteKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Icon icon(IconData data, {Color? color}) =>
        Icon(data, size: spacing.md, color: color ?? colors.textSecondary);

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
      builder: (context, controller, child) {
        return IconButton(
          key: triggerKey,
          icon: Icon(
            Icons.more_horiz,
            size: dense ? spacing.md : spacing.lg,
            color: colors.textMuted,
          ),
          tooltip: t.details.moreActions,
          padding: dense ? EdgeInsets.zero : null,
          constraints: dense
              ? BoxConstraints(minWidth: spacing.xl, minHeight: spacing.xl)
              : null,
          visualDensity: dense ? VisualDensity.compact : null,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
      menuChildren: [
        MenuItemButton(
          key: deleteKey,
          leadingIcon: icon(Icons.delete_outline, color: colors.failed),
          onPressed: onDelete,
          child: Text(
            t.details.delete,
            style: typography.bodySmall.copyWith(color: colors.failed),
          ),
        ),
      ],
    );
  }
}
