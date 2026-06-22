/// Presentational scaffolding for the Matome **Details panel** — the
/// owner-APPROVED sectioned layout (#1458). This is the SINGLE source of truth
/// for the panel's visual structure: labeled sections framed by a divider,
/// compact item rows with a leading media icon + a trailing per-item sync chip,
/// an accent "Add …" affordance row, and an inline section trailing action
/// (e.g. Notes' "Edit").
///
/// It lives in `lib/ui` (design-system surface, source-guard exempt) so BOTH
/// the live screen (`features/matome/matome_detail_screen.dart`'s
/// `_MatomeDetails`) AND the Widgetbook "Detail panel" use case render the
/// SAME widgets. The real screen composes these sections wired to live data /
/// callbacks; the catalog composes them with static sample data. They can no
/// longer drift because there is one panel, not a mock + a copy.
///
/// These widgets are deliberately presentation-only — no providers, no DB —
/// so the catalog can render them standalone and the feature layer owns all
/// data wiring.
library;

import 'package:flutter/material.dart';

import '../core/db/matome_card.dart';
import '../core/db/recording_card.dart';
import '../core/theme/app_theme.dart';
import 'app_card.dart' show MatomeSyncChip;

/// A single labeled section of the Details panel: an uppercase, muted,
/// letter-spaced label, an optional accent trailing action (e.g. "Edit"), the
/// section body, and a bottom divider that frames it off from the next section.
class MatomePanelSection extends StatelessWidget {
  const MatomePanelSection({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.onTrailingTap,
    this.showDivider = true,
  });

  /// The uppercase section heading (e.g. "Items · 3"). Rendered muted with the
  /// approved letter-spacing.
  final String label;

  /// The section body.
  final Widget child;

  /// Optional inline accent action rendered at the trailing edge of the heading
  /// row (e.g. Notes' "Edit"). Provide [onTrailingTap] to make it interactive;
  /// when null the label is rendered as static accent text (the catalog case).
  final Widget? trailing;

  /// Tap handler for [trailing]. Ignored when [trailing] is null.
  final VoidCallback? onTrailingTap;

  /// Whether to draw the bottom divider that frames this section from the next.
  /// The final section can pass false.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final Widget? trailingWidget = trailing == null
        ? null
        : (onTrailingTap == null
            ? trailing
            : InkWell(onTap: onTrailingTap, child: trailing));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: typography.label.copyWith(
                  color: colors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
                ?trailingWidget,
          ],
        ),
        SizedBox(height: spacing.sm),
        child,
        SizedBox(height: spacing.md),
        if (showDivider) ...[
          Divider(height: 1, color: colors.border),
          SizedBox(height: spacing.md),
        ],
      ],
    );
  }
}

/// One compact item/contact row in a panel section: a leading icon, a title
/// with an optional muted meta line beneath it, and an optional trailing slot
/// (e.g. a sync chip, an overflow menu). Mirrors the approved `_PanelItemRow`.
class MatomePanelRow extends StatelessWidget {
  const MatomePanelRow({
    super.key,
    required this.icon,
    required this.title,
    this.meta,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.leading,
  });

  /// The leading media/type icon (audio, image, document, person …). Ignored
  /// when [leading] is supplied.
  final IconData icon;

  /// Optional fully-custom leading widget (e.g. an avatar). Overrides [icon].
  final Widget? leading;

  /// The row title.
  final String title;

  /// Optional muted sub-line (e.g. "14:30 · 12:04", a contact role).
  final String? meta;

  /// Optional trailing widget (sync chip, overflow menu …).
  final Widget? trailing;

  /// Optional tap handler for the whole row.
  final VoidCallback? onTap;

  /// Optional long-press handler for the whole row. Used to surface per-item
  /// actions (e.g. Delete) without a row-cluttering inline overflow (#1475).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final row = Row(
      children: [
        leading ?? Icon(icon, size: spacing.md, color: colors.textSecondary),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.bodySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (meta != null && meta!.isNotEmpty)
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.label.copyWith(color: colors.textMuted),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: spacing.sm),
          trailing!,
        ],
      ],
    );

    if (onTap == null && onLongPress == null) return row;
    return InkWell(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}

/// The accent "Add …" affordance row used at the foot of a section (Add photo,
/// Add file, Add person). A leading "+" plus an accent label, optionally
/// tappable. Mirrors the approved `_AddRow`.
class MatomePanelAddRow extends StatelessWidget {
  const MatomePanelAddRow({
    super.key,
    required this.label,
    this.icon = Icons.add,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: spacing.md, color: colors.accent),
        SizedBox(width: spacing.xs),
        Text(label, style: typography.label.copyWith(color: colors.accent)),
      ],
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// The media/type icon for a panel item row, derived from a [RecordingItem]'s
/// media type. Documents and text get the document glyph; images the image
/// glyph; everything else (audio) the mic glyph. This is the per-row analogue
/// of [AppCard]'s media icon, so the panel's compact rows show the right type
/// at a glance.
IconData matomeItemIcon(String mediaType) {
  if (mediaType.startsWith('image')) return Icons.image_outlined;
  if (mediaType.contains('document') ||
      mediaType.contains('meeting') ||
      mediaType.contains('text')) {
    return Icons.description_outlined;
  }
  return Icons.mic_none_rounded;
}

/// The REAL per-item sync chip for a panel item row. A single child Item is
/// either reconciled to the cloud or still on-device — never "partial" — so we
/// reuse the shipped [MatomeSyncChip] with the matching single-item rollup. The
/// chip vocabulary therefore stays identical to the Matome-level rollup chip
/// and the per-tile badge (no mock chip, no drift).
MatomeSyncChip matomeItemSyncChip(RecordingItem item, {Key? key}) {
  return MatomeSyncChip(
    key: key,
    rollup:
        item.isOnCloud ? MatomeSyncRollup.cloud : MatomeSyncRollup.onDevice,
  );
}
