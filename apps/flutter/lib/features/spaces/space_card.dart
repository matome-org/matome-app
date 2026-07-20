/// UI-facing space type, ported from the RN `SpaceCard`
/// (apps/mobile/processes/spacesData.ts).
///
/// A space (workspace) plus the count of recordings currently assigned to it.
class SpaceCard {
  const SpaceCard({
    required this.id,
    required this.name,
    required this.count,
    this.isLocal = false,
  });

  final String id;
  final String name;

  /// Number of recordings whose `workspaceId == id`.
  final int count;

  /// Local-first-spaces (#102): whether this space is local-only (never syncs
  /// until promoted) vs cloud. Sourced from `workspaces.is_local`. Drives the
  /// [SpaceSyncTile] sync chip + the promote affordance on the Spaces master.
  final bool isLocal;
}
