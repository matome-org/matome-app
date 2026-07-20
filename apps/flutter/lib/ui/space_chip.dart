import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../i18n/strings.g.dart';

/// SpaceChip — the file↔**space** (folder) relationship indicator (DR-003).
///
/// An **outlined** pill (transparent fill + `colors.border`) carrying a
/// `folder` glyph + the space name. When [space] is null the file is in the
/// **Inbox** (no space relation) and the chip shows the italic, muted
/// `t.matome.placeInbox` label.
///
/// The outlined treatment is intentional: it is the visual opposite of
/// [MatomeChip]'s *filled* pill so the two INDEPENDENT relations (matome vs
/// space) never read as the same thing. "Inbox" (no space) and "Unfiled" (no
/// matome) are distinct per-dimension absences, not synonyms (DR-003).
///
/// Strictly presentational: props in, no callbacks, no providers, no DB.
class SpaceChip extends StatelessWidget {
  const SpaceChip({super.key, this.space});

  /// The filed space (folder) name, or null when the file is in the Inbox.
  final String? space;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final filed = space != null;
    final icon = filed ? Icons.folder_outlined : Icons.inbox_outlined;
    final label = filed ? space! : t.matome.placeInbox;
    final color = filed ? colors.textSecondary : colors.textMuted;

    return Container(
      key: const ValueKey('space-chip'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: spacing.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(
                color: color,
                fontStyle: filed ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
