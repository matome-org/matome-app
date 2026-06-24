/// Space widgets for the **local-first spaces** model (plan #102, W0).
///
/// A space is local-only or cloud-synced ([SpaceSyncState]). The Spaces screen
/// needs to (a) show each space's sync state and offer a **promote to cloud**
/// affordance while it is local, and (b) let the user pick local-vs-cloud when
/// creating a space (default local). Both are presentational here; NOT wired —
/// W0 is the widgetbook approval gate.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'space_sync_chip.dart';

/// A space row: folder + name + count + its [SpaceSyncChip], and — while the
/// space is local — a "promote to cloud" affordance (the consent flow lives in
/// the feature layer; this only surfaces the trigger).
class SpaceSyncTile extends StatelessWidget {
  const SpaceSyncTile({
    super.key,
    required this.name,
    required this.meta,
    required this.state,
    required this.promoteLabel,
    this.onTap,
    this.onPromote,
    this.selected = false,
  });

  final String name;

  /// Muted sub-line, e.g. "4 matomes".
  final String meta;

  final SpaceSyncState state;

  /// Label for the promote affordance, e.g. "Turn on sync".
  final String promoteLabel;

  final VoidCallback? onTap;

  /// Promote local→cloud. Shown only when [state] is [SpaceSyncState.local].
  final VoidCallback? onPromote;

  /// When true, renders the master-detail OPEN state: accent left bar + tint.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final showPromote = state == SpaceSyncState.local && onPromote != null;

    final card = Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: selected ? colors.accentSoft : colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: selected
            ? Border(
                left: BorderSide(color: colors.accent, width: 3),
                top: BorderSide(color: colors.border),
                right: BorderSide(color: colors.border),
                bottom: BorderSide(color: colors.border),
              )
            : Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: spacing.lg, color: colors.textSecondary),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing.xxs),
                Text(meta,
                    style: typography.label.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              SpaceSyncChip(state: state),
              if (showPromote) ...[
                SizedBox(height: spacing.xs),
                InkWell(
                  key: const ValueKey('space-promote'),
                  onTap: onPromote,
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(radius.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: spacing.md, color: colors.accent),
                      SizedBox(width: spacing.xxs),
                      Text(promoteLabel,
                          style:
                              typography.label.copyWith(color: colors.accent)),
                    ],
                  ),
                ),
              ],
            ],
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

/// The local-vs-cloud choice shown when creating a space (default local). A
/// two-option segmented control; the feature layer owns persistence + the
/// cloud-consent copy.
class SpaceSyncChoice extends StatelessWidget {
  const SpaceSyncChoice({
    super.key,
    required this.isLocal,
    required this.localLabel,
    required this.cloudLabel,
    required this.onChanged,
  });

  final bool isLocal;
  final String localLabel;
  final String cloudLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    return Container(
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _Segment(
            icon: Icons.cloud_off_outlined,
            label: localLabel,
            selected: isLocal,
            onTap: () => onChanged(true),
          ),
          _Segment(
            icon: Icons.cloud_done_outlined,
            label: cloudLabel,
            selected: !isLocal,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final fg = selected ? colors.onAccent : colors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(radius.md),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: spacing.md, color: fg),
              SizedBox(width: spacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.label
                      .copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
