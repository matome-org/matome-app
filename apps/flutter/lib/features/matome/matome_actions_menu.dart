import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';

/// Matome-level secondary / rare actions, hung off a "…" overflow trigger
/// (task #1410). Primary actions (file, add item, add contact, edit notes) live
/// inline in the detail screen, not here.
///
/// Promoted from the approved Widgetbook proposal
/// (`proposals/matome_letter_proposal.dart`): a [MenuAnchor] off a `more_horiz`
/// trigger, with a [dense] variant for list rows (W6).
///
/// `rename` / `editDateTime` are surfaced but routed to [onAction] like the
/// rest — they are wired to real flows in W5, so the caller can leave them
/// unhandled for now. `share` is disabled with a "soon" tag. `archive` replaces
/// the proposal's destructive "Delete": it is a recoverable soft-delete, so it
/// renders in NEUTRAL styling (not destructive-red).
enum MatomeAction {
  rename,
  editDateTime,
  regenerateSummary,
  moveToSpace,
  share,
  copySummary,
  archive,
}

class MatomeActionsMenu extends StatelessWidget {
  const MatomeActionsMenu({
    super.key,
    required this.onAction,
    this.dense = false,
  });

  final ValueChanged<MatomeAction> onAction;

  /// Tighter trigger for list rows (smaller icon, no padding, 32px target).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final c = t.matome.actions;

    Widget itemLabel(String text, {Color? color}) => Text(
      text,
      style: typography.bodySmall.copyWith(color: color ?? colors.textPrimary),
    );

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
          key: const ValueKey('matome-actions-trigger'),
          icon: Icon(
            Icons.more_horiz,
            size: dense ? spacing.md : spacing.lg,
            color: colors.textMuted,
          ),
          tooltip: c.menuTooltip,
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
          key: const ValueKey('matome-action-rename'),
          leadingIcon: icon(Icons.edit_outlined),
          onPressed: () => onAction(MatomeAction.rename),
          child: itemLabel(c.rename),
        ),
        MenuItemButton(
          key: const ValueKey('matome-action-edit-datetime'),
          leadingIcon: icon(Icons.event_outlined),
          onPressed: () => onAction(MatomeAction.editDateTime),
          child: itemLabel(c.editDateTime),
        ),
        Divider(height: spacing.sm, color: colors.border),
        MenuItemButton(
          key: const ValueKey('matome-action-regenerate'),
          leadingIcon: icon(Icons.refresh),
          onPressed: () => onAction(MatomeAction.regenerateSummary),
          child: itemLabel(c.regenerateSummary),
        ),
        MenuItemButton(
          key: const ValueKey('matome-action-move'),
          leadingIcon: icon(Icons.drive_file_move_outlined),
          onPressed: () => onAction(MatomeAction.moveToSpace),
          child: itemLabel(c.moveToSpace),
        ),
        Divider(height: spacing.sm, color: colors.border),
        // Share is deferred — disabled with a "soon" trailing tag.
        MenuItemButton(
          key: const ValueKey('matome-action-share'),
          leadingIcon: icon(Icons.share_outlined, color: colors.textMuted),
          trailingIcon: Text(
            c.soon,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          onPressed: null,
          child: itemLabel(c.share, color: colors.textMuted),
        ),
        MenuItemButton(
          key: const ValueKey('matome-action-copy'),
          leadingIcon: icon(Icons.copy_outlined),
          onPressed: () => onAction(MatomeAction.copySummary),
          child: itemLabel(c.copySummary),
        ),
        Divider(height: spacing.sm, color: colors.border),
        // Archive replaces the proposal's red "Delete" — it is a recoverable
        // soft-delete (W3 backend), so it stays neutral, not destructive-red.
        MenuItemButton(
          key: const ValueKey('matome-action-archive'),
          leadingIcon: icon(Icons.archive_outlined),
          onPressed: () => onAction(MatomeAction.archive),
          child: itemLabel(c.archive),
        ),
      ],
    );
  }
}
