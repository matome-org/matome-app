import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../i18n/strings.g.dart';

/// A contact's role on a matome, from the `matome_contacts` join (DR-004).
enum MatomeContactRole {
  organizer,
  attendee,
  speaker;

  /// Parse a stored role string (e.g. from Core) into the enum, defaulting to
  /// [attendee] for unknown / null values so the chip always renders.
  static MatomeContactRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'organizer':
        return MatomeContactRole.organizer;
      case 'speaker':
        return MatomeContactRole.speaker;
      case 'attendee':
      default:
        return MatomeContactRole.attendee;
    }
  }
}

/// RoleChip — a contact's role on a matome (DR-004), tinted by role.
///
/// A pill tinted at ~12% alpha by the role: organizer → `accentDark`, speaker
/// → `badgeIdeas`, attendee → `textSecondary`. The label comes from slang
/// (`t.matome.roleOrganizer/roleAttendee/roleSpeaker`).
///
/// Strictly presentational: takes a [MatomeContactRole] (parse strings via
/// [MatomeContactRole.fromString] at the call site), no callbacks, no
/// providers, no DB.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role});

  final MatomeContactRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final (Color color, String label) = switch (role) {
      MatomeContactRole.organizer => (
        colors.accentDark,
        t.matome.roleOrganizer,
      ),
      MatomeContactRole.speaker => (colors.badgeIdeas, t.matome.roleSpeaker),
      MatomeContactRole.attendee => (
        colors.textSecondary,
        t.matome.roleAttendee,
      ),
    };

    return Container(
      key: ValueKey('role-chip-${role.name}'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Text(
        label,
        style: typography.label.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}
