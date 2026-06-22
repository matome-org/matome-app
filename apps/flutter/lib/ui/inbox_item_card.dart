/// Inbox entry cards for the **local-first spaces** model (plan #102, W0).
///
/// Under that model the INBOX is the view over everything whose effective space
/// is NULL — the unorganized, local staging area. Two kinds of thing live there
/// and need distinct cards (today the home screen only renders matomes):
///   • a **loose item** — a bare recording/photo/doc/note with no matome and no
///     space; and
///   • a **draft matome** — items grouped into a matome that has not yet been
///     filed into a space.
/// Both are local (never sync) until filed into a cloud space, so both carry the
/// [SpaceSyncChip] `local` state and a "file / organize" affordance.
///
/// Purely presentational; lives in `lib/ui`. NOT wired yet — W0 is the
/// widgetbook approval gate. The live home screen will map its state onto this
/// card in a later wave.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'space_sync_chip.dart';

/// Which kind of unorganized inbox entry a card represents.
enum InboxEntryKind {
  /// A bare item (no matome, no space).
  looseItem,

  /// A matome with no space (grouped but not yet filed).
  draftMatome,
}

/// A single inbox entry — a loose item or a draft matome. Presentational:
/// labels (title, meta, the kind tag, the file affordance) are supplied by the
/// caller so the feature layer owns i18n + data wiring (mirrors
/// `MatomeDetailPanel` / `RelationshipPicker`).
class InboxItemCard extends StatelessWidget {
  const InboxItemCard({
    super.key,
    required this.kind,
    required this.title,
    required this.meta,
    required this.tagLabel,
    required this.fileLabel,
    this.icon,
    this.leading,
    this.syncState = SpaceSyncState.local,
    this.onTap,
    this.onFile,
  });

  final InboxEntryKind kind;

  /// Row title (item title / matome title).
  final String title;

  /// Muted sub-line: e.g. "2h · 12:04" for an item, "3 items · 2h" for a draft.
  final String meta;

  /// The kind tag shown next to the title: e.g. "Loose" / "Draft".
  final String tagLabel;

  /// The triage affordance label: e.g. "File" / "Organize".
  final String fileLabel;

  /// Leading glyph (media type for an item; defaults by [kind] when null).
  final IconData? icon;

  /// Fully-custom leading (e.g. a thumbnail) overriding [icon].
  final Widget? leading;

  /// Inbox entries are local by design; exposed for completeness.
  final SpaceSyncState syncState;

  final VoidCallback? onTap;

  /// The "file into a space / organize" action — the triage gesture that pulls
  /// this entry out of the inbox.
  final VoidCallback? onFile;

  IconData get _defaultIcon => switch (kind) {
        InboxEntryKind.looseItem => Icons.insert_drive_file_outlined,
        InboxEntryKind.draftMatome => Icons.workspaces_outline,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final card = Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ??
              Icon(icon ?? _defaultIcon,
                  size: spacing.lg, color: colors.textSecondary),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.body.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    _KindTag(label: tagLabel),
                  ],
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.label.copyWith(color: colors.textMuted),
                ),
                SizedBox(height: spacing.sm),
                Row(
                  children: [
                    SpaceSyncChip(state: syncState),
                    const Spacer(),
                    _FileAffordance(label: fileLabel, onTap: onFile),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(radius.lg),
      child: card,
    );
  }
}

/// The small outlined "Loose" / "Draft" tag next to the title.
class _KindTag extends StatelessWidget {
  const _KindTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: typography.label.copyWith(color: colors.textMuted),
      ),
    );
  }
}

/// The accent "File / Organize" triage affordance.
class _FileAffordance extends StatelessWidget {
  const _FileAffordance({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.drive_file_move_outline, size: spacing.md, color: colors.accent),
        SizedBox(width: spacing.xxs),
        Text(label, style: typography.label.copyWith(color: colors.accent)),
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(radius.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.xxs, vertical: spacing.xxs),
        child: row,
      ),
    );
  }
}
