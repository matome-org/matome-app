/// Files-scope filter for the **local-first spaces** model (plan #102, W0).
///
/// The Files screen needs to filter by organization: everything, only the
/// **loose** items (effective space NULL), or only items **in a space**. This
/// replaces the ambiguous "Unfiled" wording (glossary bans it). Presentational
/// segmented control; NOT wired — W0 is the widgetbook approval gate.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Which slice of files to show.
enum FilesScope {
  /// Every file.
  all,

  /// Loose only — effective space NULL (the inbox staging files).
  loose,

  /// Filed into a space (local or cloud).
  inSpace,
}

/// A three-option segmented control over [FilesScope]. Labels are caller-
/// supplied (i18n owned by the feature layer).
class FilesScopeFilter extends StatelessWidget {
  const FilesScopeFilter({
    super.key,
    required this.value,
    required this.allLabel,
    required this.looseLabel,
    required this.inSpaceLabel,
    required this.onChanged,
  });

  final FilesScope value;
  final String allLabel;
  final String looseLabel;
  final String inSpaceLabel;
  final ValueChanged<FilesScope> onChanged;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(
            label: allLabel,
            scope: FilesScope.all,
            selected: value == FilesScope.all,
            onTap: () => onChanged(FilesScope.all),
          ),
          _Seg(
            label: looseLabel,
            scope: FilesScope.loose,
            selected: value == FilesScope.loose,
            onTap: () => onChanged(FilesScope.loose),
          ),
          _Seg(
            label: inSpaceLabel,
            scope: FilesScope.inSpace,
            selected: value == FilesScope.inSpace,
            onTap: () => onChanged(FilesScope.inSpace),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final FilesScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final fg = selected ? colors.onAccent : colors.textSecondary;

    return InkWell(
      key: ValueKey('files-scope-${scope.name}'),
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(radius.md),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(radius.md),
        ),
        child: Text(
          label,
          style:
              typography.label.copyWith(color: fg, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
