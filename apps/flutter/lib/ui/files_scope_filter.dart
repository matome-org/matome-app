/// Files-scope filter for the **local-first spaces** model (plan #102, W0).
///
/// The Files screen needs to filter by organization: everything, only the
/// **loose** items (effective space NULL), or only items **in a space**. This
/// replaces the ambiguous "Unfiled" wording (glossary bans it). Presentational
/// only — NOT wired; W0 is the widgetbook approval gate.
///
/// Style follows the app-standard filter pattern (the RelationshipPicker
/// `_FilterChips` strip): a row of pill chips, each independently outlined, the
/// active one filled accent, optional leading icon. NOT a segmented control —
/// the rest of the app filters with chips.
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

/// A three-option chip filter over [FilesScope]. Labels are caller-supplied
/// (i18n owned by the feature layer). Matches the app-standard filter chip
/// strip — pill chips, accent-filled when active, outlined otherwise.
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
    final spacing = context.spacing;

    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [
        _FilterChip(
          label: allLabel,
          scope: FilesScope.all,
          selected: value == FilesScope.all,
          onTap: () => onChanged(FilesScope.all),
        ),
        _FilterChip(
          icon: Icons.inbox_outlined,
          label: looseLabel,
          scope: FilesScope.loose,
          selected: value == FilesScope.loose,
          onTap: () => onChanged(FilesScope.loose),
        ),
        _FilterChip(
          icon: Icons.folder_outlined,
          label: inSpaceLabel,
          scope: FilesScope.inSpace,
          selected: value == FilesScope.inSpace,
          onTap: () => onChanged(FilesScope.inSpace),
        ),
      ],
    );
  }
}

/// One filter pill — mirrors the app-standard chip (RelationshipPicker).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.scope,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final FilesScope scope;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final fg = selected ? colors.onAccent : colors.textSecondary;

    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(radius.pill),
      child: InkWell(
        key: ValueKey('files-scope-${scope.name}'),
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(radius.pill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.pill),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: spacing.md, color: fg),
                SizedBox(width: spacing.xxs),
              ],
              Text(label, style: typography.label.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
