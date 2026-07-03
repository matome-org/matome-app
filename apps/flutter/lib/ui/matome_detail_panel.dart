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
        if (trailing != null) ...[SizedBox(width: spacing.sm), trailing!],
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
    final radius = context.radius;
    final typography = context.typography;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: spacing.md, color: colors.accent),
        SizedBox(width: spacing.xs),
        Text(label, style: typography.label.copyWith(color: colors.accent)),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs),
        child: row,
      );
    }
    // Explicit click cursor + hover highlight + a padded hit area so the accent
    // "Add" affordance reads as tappable on desktop/web (a bare InkWell over a
    // tight Row gave no pointer cursor / no hover feedback).
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(radius.sm),
      hoverColor: colors.accent.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xs,
        ),
        child: row,
      ),
    );
  }
}

/// The media/type icon for a panel item row, derived from a [RecordingItem]'s
/// media type. Documents and text get the document glyph; images the image
/// glyph; videos the video glyph; everything else (audio) the mic glyph. This is the per-row analogue
/// of [AppCard]'s media icon, so the panel's compact rows show the right type
/// at a glance.
IconData matomeItemIcon(String mediaType) {
  if (mediaType.startsWith('image')) return Icons.image_outlined;
  if (mediaType.startsWith('video')) return Icons.video_file_outlined;
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
    rollup: item.isOnCloud ? MatomeSyncRollup.cloud : MatomeSyncRollup.onDevice,
  );
}

// ─── Assembled Detail panel (presentational) ─────────────────────────────────
//
// The COMPLETE Details panel, assembled from the section atoms above into one
// public, presentational widget. This is the "Matome detail" component the
// Widgetbook tree (and its shared golden) render — so the tree reads
// "MatomeDetailPanel" (a detail panel), not "MatomePanelSection" (an atom).
//
// It is the SINGLE owner of the panel's information architecture: the header
// plus the ordered, divider-framed sections (Items · People · Space · Notes ·
// Share). It is strictly presentation-only — no providers, no DB.
//
// CONVERGENCE (#1479): the LIVE screen
// (`features/matome/matome_detail_screen.dart`'s `_MatomeDetails`) renders THIS
// widget too — there is no longer a parallel inline composition. Because each
// live section is deeply interactive (a stateful Notes editor, an anchored
// "Add item" menu, per-item thumbnails / tap-routing / long-press, per-contact
// detach, a filing sheet), the panel exposes optional per-section *slot*
// widgets ([MatomeDetailPanelSlots]). When a slot is supplied the panel renders
// that full section in place of the data-driven default; when null it renders
// the default body built from [MatomeDetailPanelData]. The catalog drives the
// data-only path; the live screen drives the slot path. Either way the panel
// owns the ordering + framing, so the two can no longer drift.

/// Optional per-section override widgets for [MatomeDetailPanel]. Each slot, when
/// non-null, is rendered as the COMPLETE section in place of the panel's
/// data-driven default — letting the live feature layer inject its real,
/// provider-bound, interactive sections while the panel still owns the header
/// and the section ORDER. A slot is expected to render its own
/// [MatomePanelSection] frame (so live labels can carry live counts); the panel
/// inserts the inter-section spacing around it exactly as for the defaults.
///
/// All-null (the catalog default) → the panel renders every section from
/// [MatomeDetailPanelData].
class MatomeDetailPanelSlots {
  const MatomeDetailPanelSlots({
    this.itemsSection,
    this.peopleSection,
    this.spaceSection,
    this.notesSection,
    this.shareSection,
  });

  /// Replaces the "Items · N" section (live: interactive item rows + the
  /// anchored "Add item" menu).
  final Widget? itemsSection;

  /// Replaces the "People · N" section (live: contact rows with detach + the
  /// "Add person" picker).
  final Widget? peopleSection;

  /// Replaces the "Space" section (live: filed-space + Refile / the inbox
  /// File-into-space CTA, wired to the filing sheet).
  final Widget? spaceSection;

  /// Replaces the "Notes" section (live: the stateful inline editor).
  final Widget? notesSection;

  /// Replaces the trailing "Share" affordance (live: the deferred tooltip row).
  final Widget? shareSection;

  bool get isEmpty =>
      itemsSection == null &&
      peopleSection == null &&
      spaceSection == null &&
      notesSection == null &&
      shareSection == null;
}

/// One item row in the assembled [MatomeDetailPanel]: a media type (drives the
/// leading glyph via [matomeItemIcon]), a title, a time/duration meta line, and
/// whether the item is reconciled to the cloud (drives the trailing sync chip).
class MatomeDetailPanelItem {
  const MatomeDetailPanelItem({
    required this.mediaType,
    required this.title,
    required this.meta,
    required this.onCloud,
  });

  final String mediaType;
  final String title;
  final String meta;
  final bool onCloud;
}

/// One contact row in the assembled [MatomeDetailPanel]: an initials avatar, a
/// name, and a role meta line.
class MatomeDetailPanelContact {
  const MatomeDetailPanelContact({
    required this.initial,
    required this.name,
    required this.role,
  });

  final String initial;
  final String name;
  final String role;
}

/// The presentational data for an assembled [MatomeDetailPanel]. Plain props —
/// no providers, no DB — so both the catalog (static fixtures) and, in future,
/// the live screen (mapped from controller state) can drive the same widget.
class MatomeDetailPanelData {
  const MatomeDetailPanelData({
    this.title = 'Detail',
    this.items = const [],
    this.contacts = const [],
    this.spaceName,
    this.notes,
    this.addItemLabel = 'Add item',
    this.addPersonLabel = 'Add person',
    this.notesLabel = 'Notes',
    this.notesEditLabel = 'Edit',
    this.spaceLabel = 'Space',
    this.refileLabel = 'Refile',
    this.fileIntoSpaceLabel = 'File into space',
    this.shareLabel = 'Share',
  });

  final String title;
  final List<MatomeDetailPanelItem> items;
  final List<MatomeDetailPanelContact> contacts;

  /// The filed space (folder) name, or null for an Inbox matome (renders the
  /// "File into space" accent pill instead of folder + "Refile").
  final String? spaceName;

  /// The notes body. When null/empty the Notes section is still rendered with
  /// its label + Edit affordance but no body.
  final String? notes;

  final String addItemLabel;
  final String addPersonLabel;
  final String notesLabel;
  final String notesEditLabel;
  final String spaceLabel;
  final String refileLabel;
  final String fileIntoSpaceLabel;
  final String shareLabel;

  bool get isInbox => spaceName == null || spaceName!.isEmpty;
}

/// The COMPLETE Matome **Details panel** — the owner-approved sectioned layout
/// (Items · N → People · N → Space → Notes → Share) assembled from the
/// [MatomePanelSection] / [MatomePanelRow] / [MatomePanelAddRow] atoms. Purely
/// presentational and driven by [MatomeDetailPanelData]; callbacks are optional
/// so the catalog can render it inert.
class MatomeDetailPanel extends StatelessWidget {
  const MatomeDetailPanel({
    super.key,
    required this.data,
    this.slots = const MatomeDetailPanelSlots(),
    this.showHeader = true,
    this.padding,
    this.onClose,
    this.onAddItem,
    this.onAddPerson,
    this.onEditNotes,
    this.onRefile,
    this.onFileIntoSpace,
    this.onShare,
  });

  final MatomeDetailPanelData data;

  /// Optional per-section override widgets (live screen → real interactive
  /// sections). Defaults to all-null → the data-driven catalog rendering.
  final MatomeDetailPanelSlots slots;

  /// Whether to render the panel header (title + close affordance). The catalog
  /// shows it; the live side panel supplies its own title chrome and the mobile
  /// "Show more" reveal wants no header, so both pass false.
  final bool showHeader;

  /// Outer padding. Defaults to `spacing.lg` on every side (the catalog frame);
  /// the live screen passes `EdgeInsets.zero` since its host already pads.
  final EdgeInsetsGeometry? padding;

  final VoidCallback? onClose;
  final VoidCallback? onAddItem;
  final VoidCallback? onAddPerson;
  final VoidCallback? onEditNotes;
  final VoidCallback? onRefile;
  final VoidCallback? onFileIntoSpace;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Padding(
      padding: padding ?? EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panel header.
          if (showHeader) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: typography.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (onClose != null)
                  InkWell(
                    onTap: onClose,
                    child: Icon(
                      Icons.close,
                      size: spacing.md,
                      color: colors.textMuted,
                    ),
                  )
                else
                  Icon(Icons.close, size: spacing.md, color: colors.textMuted),
              ],
            ),
            SizedBox(height: spacing.md),
          ],

          // Items · N — live interactive section, or the data-driven default.
          slots.itemsSection ??
              MatomePanelSection(
                label: 'Items · ${data.items.length}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in data.items) ...[
                      MatomePanelRow(
                        icon: matomeItemIcon(item.mediaType),
                        title: item.title,
                        meta: item.meta,
                        trailing: MatomeSyncChip(
                          rollup: item.onCloud
                              ? MatomeSyncRollup.cloud
                              : MatomeSyncRollup.onDevice,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                    ],
                    MatomePanelAddRow(
                      label: data.addItemLabel,
                      onTap: onAddItem,
                    ),
                  ],
                ),
              ),

          // People · N.
          slots.peopleSection ??
              MatomePanelSection(
                label: 'People · ${data.contacts.length}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final contact in data.contacts) ...[
                      MatomePanelRow(
                        icon: Icons.person_outline,
                        leading: CircleAvatar(
                          radius: spacing.md,
                          backgroundColor: colors.subtleFill,
                          child: Text(
                            contact.initial,
                            style: typography.label.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        title: contact.name,
                        meta: contact.role,
                      ),
                      SizedBox(height: spacing.xs),
                    ],
                    MatomePanelAddRow(
                      icon: Icons.person_add_alt_outlined,
                      label: data.addPersonLabel,
                      onTap: onAddPerson,
                    ),
                  ],
                ),
              ),

          // Space — filed (folder + name + Refile) or inbox (File into space).
          slots.spaceSection ??
              MatomePanelSection(
                label: data.spaceLabel,
                child: data.isInbox
                    ? Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: spacing.md,
                            color: colors.textSecondary,
                          ),
                          SizedBox(width: spacing.xs),
                          Material(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(radius.pill),
                            child: InkWell(
                              onTap: onFileIntoSpace,
                              borderRadius: BorderRadius.circular(radius.pill),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.sm,
                                  vertical: spacing.xxs,
                                ),
                                child: Text(
                                  data.fileIntoSpaceLabel,
                                  style: typography.label.copyWith(
                                    color: colors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: spacing.md,
                            color: colors.textSecondary,
                          ),
                          SizedBox(width: spacing.xs),
                          Expanded(
                            child: Text(
                              data.spaceName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: onRefile,
                            child: Text(
                              data.refileLabel,
                              style: typography.label.copyWith(
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

          // Notes — label + inline accent "Edit" + body, no trailing divider.
          slots.notesSection ??
              MatomePanelSection(
                label: data.notesLabel,
                showDivider: false,
                trailing: Text(
                  data.notesEditLabel,
                  style: typography.label.copyWith(color: colors.accent),
                ),
                onTrailingTap: onEditNotes,
                child: Text(
                  (data.notes != null && data.notes!.isNotEmpty)
                      ? data.notes!
                      : '',
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),

          // Share — deferred affordance row.
          slots.shareSection ??
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: onShare,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ios_share,
                        size: spacing.md,
                        color: colors.textPrimary,
                      ),
                      SizedBox(width: spacing.xs),
                      Text(
                        data.shareLabel,
                        style: typography.label.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
