// Drift `workspaces` row → [SpaceRef] VALUE OBJECT adapter (local-first-spaces
// #102 W4 / #1498). Kept SEPARATE from the pure, DB-free resolver
// (effective_space.dart) so the resolver stays free of any Drift dependency.
//
// This is the SINGLE place a `WorkspaceRow` becomes the resolver's value
// object. It maps the persisted columns to the two orthogonal axes
// (.docs/internal/architecture.md §5 / spec R2.2):
//   * Axis A (sync)    — `is_local` (m017): 1 ⇒ local, 0 ⇒ cloud.
//   * Axis B (tenancy) — `space_type` (m006): personal | shared | org.
//
// Doing the mapping in one place means the upload-queue drain, the moveToSpace
// PATCH gate, and any future caller all feed the resolver/SyncPolicy the SAME
// VALUE OBJECT — there is no second `is_local` read anywhere (spec R1.2).

import '../../core/db/app_database.dart';
import 'effective_space.dart';

/// Map a persisted [WorkspaceRow] to the resolver's [SpaceRef] value object.
///
/// `is_local == 1` ⇒ [SpaceSyncMode.local]; otherwise [SpaceSyncMode.cloud]
/// (the m017 column is NOT NULL default-local). `space_type` maps to
/// [SpaceTenancy] (reserved/unenforced in #102 — constant `personal` in
/// practice). `owner_id` carries through (nullable, reserved).
SpaceRef spaceRefFromRow(WorkspaceRow row) => SpaceRef(
  id: row.id,
  syncMode: row.isLocal == 1 ? SpaceSyncMode.local : SpaceSyncMode.cloud,
  tenancy: _tenancyOf(row.spaceType),
  ownerId: row.ownerId,
);

SpaceTenancy _tenancyOf(String spaceType) => switch (spaceType) {
  'org' => SpaceTenancy.org,
  'shared' => SpaceTenancy.shared,
  _ => SpaceTenancy.personal,
};
