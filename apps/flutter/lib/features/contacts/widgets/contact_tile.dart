import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One contact row in the directory (the `/contacts` grid/list): a tinted
/// person glyph, the name, optional notes, and a chevron.
///
/// PRESENTATIONAL only — primitive props, no providers, no DB row type — so the
/// Widgetbook catalog can render the SAME widget the screen does (DR-000
/// convergence). The caller owns the accent [color] (e.g.
/// `context.colors.spaceColor(index)`) and passes a `ValueKey('contact-tile-<id>')`
/// as the [key]; tap/long-press hit-test through to the inner [InkWell].
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.name,
    required this.color,
    this.notes = '',
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final String name;
  final Color color;
  final String notes;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// When true, renders the master-detail OPEN state: accent left bar + tint.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Semantics(
      button: true,
      label: 'Contact: $name',
      child: Material(
        color: selected ? colors.accentSoft : colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius.lg),
          child: Container(
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
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
                Container(
                  width: spacing.xl + spacing.xs,
                  height: spacing.xl + spacing.xs,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(radius.md),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: typography.title.fontSize,
                    color: color,
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        SizedBox(height: spacing.xxs),
                        Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.label.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: spacing.md + spacing.xxs,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
