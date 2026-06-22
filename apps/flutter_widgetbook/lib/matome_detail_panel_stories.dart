// Assembled Matome **Detail panel** use-cases (#1476).
//
// Restores the owner-approved, fully-composed Details panel story that was lost
// when the proposal mock was re-deleted (#1475). These use-cases assemble the
// REAL, PUBLIC panel widgets shipped in
// `package:matome_flutter/ui/matome_detail_panel.dart` (MatomePanelSection /
// MatomePanelRow / MatomePanelAddRow + matomeItemIcon + MatomeSyncChip) with
// STATIC SAMPLE DATA — no providers, no DB. They render the SAME widgets the
// live `_MatomeDetails` composes, so the catalog can no longer drift from the
// app: there is one panel, not a mock + a copy.
//
// Section order mirrors the approved panel: Items · N → People · N → Space
// (filed → folder + name + "Refile"; inbox → folder + "File into space" pill) →
// Notes (label + "Edit" + body) → Share. Two states are provided — a FILED and
// an INBOX matome.

import 'package:flutter/material.dart';
import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/app_card.dart' show MatomeSyncChip;
import 'package:matome_flutter/ui/matome_detail_panel.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ─── Sample data ─────────────────────────────────────────────────────────────

/// A panel item: media type (drives the leading glyph via [matomeItemIcon]), a
/// title, a time/duration meta line, and a per-item cloud/on-device rollup. A
/// single child item is never "partial" — it is reconciled or it is not.
class _PanelItem {
  const _PanelItem({
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

const _items = <_PanelItem>[
  _PanelItem(
    mediaType: 'audio',
    title: 'Meeting audio',
    meta: '14:30 · 12:04',
    onCloud: true,
  ),
  _PanelItem(
    mediaType: 'audio',
    title: 'Follow-up note',
    meta: '14:55 · 03:20',
    onCloud: false,
  ),
  _PanelItem(
    mediaType: 'image',
    title: 'Whiteboard photo',
    meta: '15:10',
    onCloud: true,
  ),
  _PanelItem(
    mediaType: 'document',
    title: 'Quarterly report',
    meta: '15:24',
    onCloud: true,
  ),
];

/// A panel contact: initials avatar + name + role meta line.
class _PanelContact {
  const _PanelContact({
    required this.initial,
    required this.name,
    required this.role,
  });

  final String initial;
  final String name;
  final String role;
}

const _contacts = <_PanelContact>[
  _PanelContact(initial: 'A', name: 'Ana', role: 'Organizer'),
  _PanelContact(initial: 'K', name: 'Ken', role: 'Attendee'),
];

// ─── Use cases ───────────────────────────────────────────────────────────────

@widgetbook.UseCase(
  name: 'Detail panel — filed',
  type: MatomePanelSection,
  path: '[Catalog]/Matome detail',
)
Widget detailPanelFiledUseCase(BuildContext context) {
  return const _DetailPanelSurface(child: _AssembledDetailPanel(inbox: false));
}

@widgetbook.UseCase(
  name: 'Detail panel — inbox',
  type: MatomePanelSection,
  path: '[Catalog]/Matome detail',
)
Widget detailPanelInboxUseCase(BuildContext context) {
  return const _DetailPanelSurface(child: _AssembledDetailPanel(inbox: true));
}

/// Bounded, scrollable, themed surface for the assembled panel.
class _DetailPanelSurface extends StatelessWidget {
  const _DetailPanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The full approved Details panel, composed from the REAL `lib/ui` widgets with
/// static sample data. [inbox] toggles the Space section between the filed
/// folder + "Refile" row and the inbox "File into space" pill.
class _AssembledDetailPanel extends StatelessWidget {
  const _AssembledDetailPanel({required this.inbox});

  final bool inbox;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panel header.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Detail',
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
              ),
              Icon(Icons.close, size: spacing.md, color: colors.textMuted),
            ],
          ),
          SizedBox(height: spacing.md),

          // Items · N — compact rows (leading media icon · title · time/duration
          // · trailing per-item sync chip) + the accent "Add item" row. The
          // leading icon and sync chip both come from the real helpers so the
          // panel matches the app exactly (no inline ⋯).
          MatomePanelSection(
            label: 'Items · ${_items.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in _items) ...[
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
                const MatomePanelAddRow(label: 'Add item'),
              ],
            ),
          ),

          // People · N — contact rows (initials avatar + name + role) + the
          // accent "Add person" row.
          MatomePanelSection(
            label: 'People · ${_contacts.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final contact in _contacts) ...[
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
                const MatomePanelAddRow(
                  icon: Icons.person_add_alt_outlined,
                  label: 'Add person',
                ),
              ],
            ),
          ),

          // Space — filed: folder + name + "Refile"; inbox: folder + the
          // "File into space" accent pill (mirrors the live _FilingSection).
          MatomePanelSection(
            label: 'Space',
            child: inbox
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
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.sm,
                            vertical: spacing.xxs,
                          ),
                          child: Text(
                            'File into space',
                            style: typography.label.copyWith(
                              color: colors.onAccent,
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
                          'Marketing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodySmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'Refile',
                        style: typography.label.copyWith(color: colors.accent),
                      ),
                    ],
                  ),
          ),

          // Notes — label + inline accent "Edit" + body, no trailing divider.
          MatomePanelSection(
            label: 'Notes',
            showDivider: false,
            trailing: Text(
              'Edit',
              style: typography.label.copyWith(color: colors.accent),
            ),
            child: Text(
              'Recap the decisions, owners, and next steps so the matome reads '
              'like a short letter rather than a transcript dump.',
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),

          // Share — deferred affordance row.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.ios_share,
                size: spacing.md,
                color: colors.textPrimary,
              ),
              SizedBox(width: spacing.xs),
              Text(
                'Share',
                style: typography.label.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
