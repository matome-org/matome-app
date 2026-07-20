/// Sync-state vocabulary for the **local-first spaces** model (plan #102, W0).
///
/// In that model sync is gated by the *space*, not by whether something is
/// organized: a space (or an item via its effective space) is either **local**
/// (client-only, never syncs — the deliberate offline-staging state), being
/// **promoted** to the cloud, or fully **cloud** (synced). This is distinct from
/// the existing [MatomeSyncChip]/[StatusBadge.sync] rollup, whose `onDevice`
/// means "in the sync domain but not yet uploaded" — here `local` means "by
/// design will never upload unless promoted".
///
/// Purely presentational; lives in `lib/ui` so the catalog and (later) the live
/// screens render the same chip. NOT wired into any screen yet (W0 is the
/// widgetbook-only approval gate).
library;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../i18n/strings.g.dart';

/// The sync state of a space — or of an item, resolved through its effective
/// space. Exhaustive on purpose (a `switch` with no default) so every reader
/// must handle the new [local] state the compiler can find.
enum SpaceSyncState {
  /// Local-only: client-only, never syncs by design (inbox / a local space).
  local,

  /// Being promoted local→cloud: its contents are uploading.
  promoting,

  /// Cloud: filed into a cloud space and reconciled.
  cloud,
}

/// A small pill expressing a [SpaceSyncState] — the local-first analogue of
/// [MatomeSyncChip]. `local` is the new, first-class "never syncs" state
/// (cloud-off glyph, muted), separate from a pending upload.
class SpaceSyncChip extends StatelessWidget {
  const SpaceSyncChip({super.key, required this.state, this.compact = false});

  final SpaceSyncState state;

  /// When true, render the glyph only (no label) — for dense rows / grids.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    final (IconData icon, String label, Color color) = switch (state) {
      SpaceSyncState.local => (
        Icons.cloud_off_outlined,
        t.cardStatus.local,
        colors.textMuted,
      ),
      SpaceSyncState.promoting => (
        Icons.cloud_sync_outlined,
        t.cardStatus.syncing,
        colors.textSecondary,
      ),
      SpaceSyncState.cloud => (
        Icons.cloud_done_outlined,
        t.cardStatus.cloud,
        colors.badgePersonal,
      ),
    };

    if (compact) {
      return Semantics(
        label: label,
        child: Icon(icon, size: spacing.md, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: spacing.md, color: color),
          SizedBox(width: spacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
