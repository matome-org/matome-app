/// UI-facing space type, ported from the RN `SpaceCard`
/// (apps/mobile/processes/spacesData.ts).
///
/// A space (workspace) plus the count of recordings currently assigned to it.
class SpaceCard {
  const SpaceCard({
    required this.id,
    required this.name,
    required this.count,
  });

  final String id;
  final String name;

  /// Number of recordings whose `workspaceId == id`.
  final int count;
}
