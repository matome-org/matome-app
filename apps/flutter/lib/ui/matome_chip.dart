import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../i18n/strings.g.dart';

/// MatomeChip — the file↔**matome** relationship indicator (DR-003).
///
/// A **filled** pill (`colors.subtleFill`) carrying a `workspaces` glyph + the
/// matome title. When [matome] is null the file is **Unfiled** (no matome
/// relation) and the chip shows the italic, muted `t.files.unfiled` label.
///
/// This is deliberately the *filled* counterpart to [SpaceChip]'s *outlined*
/// pill — matome and space are INDEPENDENT relations, so the two read as
/// distinct categories at a glance rather than two instances of one thing.
///
/// Strictly presentational: props in, no callbacks, no providers, no DB. Reads
/// theme only through `context.colors/spacing/radius/typography`.
class MatomeChip extends StatelessWidget {
  const MatomeChip({super.key, this.matome});

  /// The matome title this file belongs to, or null when the file is Unfiled.
  final String? matome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final filed = matome != null;
    final icon = filed ? Icons.workspaces_outlined : Icons.inbox_outlined;
    final label = filed ? matome! : t.files.unfiled;
    final color = filed ? colors.textSecondary : colors.textMuted;

    return Container(
      key: const ValueKey('matome-chip'),
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
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
