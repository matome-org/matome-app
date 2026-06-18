import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';

/// Where a recording physically lives: on the device only, or also in the cloud
/// (plan #45, W2). This is a PEER badge to the folder/space badge — it answers
/// "is my recording safely backed up?", not "which space is it in?".
///
/// Semantics are derived from the #43 `coreId` column (+ processing status):
///   * `coreId == null` (or a `pending_upload` / `failed` row) → [onDevice].
///     The recording exists only on this phone; nothing has reconciled a Core
///     id yet. `failed` keeps its own W5 failure treatment AND this badge —
///     the bytes ARE still local.
///   * `coreId != null` → [cloud]. The recording reconciled with Core and is
///     backed up.
///
/// Accessible by construction: every variant pairs an icon with a text label
/// (never colour alone), and the whole pill exposes a single Semantics label
/// so a screen reader announces e.g. "Sync state: Cloud" (feeds W3).
enum SyncState { onDevice, cloud }

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.coreId, this.processingStatus});

  /// The reconciled Core id, or null while the recording is still local-only.
  final int? coreId;

  /// The persisted lifecycle status. A `pending_upload` / `failed` row is
  /// always [onDevice] regardless of a stale [coreId], so a recording that
  /// hasn't successfully uploaded never mis-reads as backed-up.
  final String? processingStatus;

  SyncState get state {
    final status = processingStatus;
    if (status == 'pending_upload' || status == 'failed') {
      return SyncState.onDevice;
    }
    return coreId != null ? SyncState.cloud : SyncState.onDevice;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    final (IconData icon, String label, Color color) = switch (state) {
      SyncState.cloud => (
        Icons.cloud_done_outlined,
        t.cardStatus.cloud,
        colors.badgePersonal,
      ),
      SyncState.onDevice => (
        Icons.smartphone_outlined,
        t.cardStatus.onDevice,
        // textSecondary (not textMuted): clears WCAG AA 4.5:1 as TEXT over
        // its own 12% tint (plan #45, W3), whereas textMuted only clears it
        // on a plain white surface.
        colors.textSecondary,
      ),
    };

    return Semantics(
      label: '${t.cardStatus.syncState}: $label',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('sync-badge-${state.name}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
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
        ),
      ),
    );
  }
}
