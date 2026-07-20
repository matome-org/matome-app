// ---------------------------------------------------------------------------
// effectiveSpace / isCloudSynced — the ONE authoritative sync-eligibility
// resolver (local-first-spaces #102 W1, .docs/internal/architecture.md §5, sync gate §5 R1/R2).
//
// This file is the SPINE of plan #102. It owns the single precedence rule
// `effectiveSpaceId = matome.space_id ?? recording.workspace_id` (matome WINS)
// and the single sync predicate `SYNC ⟺ effective space is a CLOUD space`.
//
// > **R1.2 — One resolver, both tiers.** `effectiveSpace` is owned by this one
// > resolver and is the SOLE sync-eligibility authority for the whole program.
// > Neither the client nor Core may invent a second predicate, a shortcut
// > column, or an inline `if (workspaceId != null)`. A second recompute leaks
// > private data (Olivier) — that is the failure this file prevents.
//
// FORWARD-COMPAT seams this file LOCKS IN (.docs/internal/architecture.md §5 / spec R1.4, R2.1):
//   * The resolver consumes a Space VALUE OBJECT [SpaceRef] carrying
//     { id, syncMode, tenancy, ownerId }. `tenancy` is CONSTANT `personal` and
//     `ownerId` is the current user TODAY, but both are PRESENT IN THE SIGNATURE
//     so org-spaces later add ONE branch, not a rewrite.
//   * The sync-status type [SyncStatus] is a SEALED hierarchy with NO catch-all:
//     a future case (`orgManaged` / `policyBlocked`) is a COMPILE ERROR at every
//     exhaustive `switch`. No `default:` arm silently swallows new states.
//   * NO fixed `callerRole` enum is introduced here. Authorization stays
//     OPERATION-KEYED at one decision point (#1498, W4). The resolver / VO is an
//     INPUT to a future PDP `can(caller, operation, space)`, never the authority
//     itself. Roles/operations are future DATA (deferred authz plan, #future-plan
//     project comment #74119), not enums frozen here.
// ---------------------------------------------------------------------------

/// Axis A — the sync mode of a Space (`workspaces.is_local`, m017).
///
/// ORTHOGONAL to tenancy ([SpaceTenancy], Axis B) — the two are NEVER collapsed
/// (.docs/internal/architecture.md §5 / spec R2.2). Sync keys off this axis ONLY.
enum SpaceSyncMode {
  /// `is_local = true` — client-only; its items NEVER reach Core.
  local,

  /// `is_local = false` — its items sync to Core.
  cloud,
}

/// Axis B — the tenancy / ownership of a Space (`workspaces.space_type`, m006).
///
/// RESERVED / UNENFORCED in #102: today every space is [personal]. Present so
/// the deferred orgs/RBAC work adds a branch, not a rewrite. ORTHOGONAL to
/// [SpaceSyncMode] (Axis A). Invariants couple them without merging:
/// `local ⟹ personal`, `org ⟹ cloud`; `personal` may be local OR cloud.
enum SpaceTenancy { personal, shared, org }

/// The Space VALUE OBJECT the resolver consumes (.docs/internal/architecture.md §5 seam 1 / spec
/// R1.4). Carries exactly what a sync-eligibility decision needs, decoupled
/// from the Drift row so the resolver is pure and DB-free.
///
/// [tenancy] is CONSTANT `personal` and [ownerId] is the current user in #102,
/// but both are FIRST-CLASS FIELDS so org-spaces add one branch later. Do NOT
/// remove them to "simplify" — they are the locked forward-compat seam.
class SpaceRef {
  const SpaceRef({
    required this.id,
    required this.syncMode,
    this.tenancy = SpaceTenancy.personal,
    this.ownerId,
  });

  /// The Space id (the `workspaces.id`, a stored space the item resolves to).
  final String id;

  /// Axis A — does this space sync? Derived from `workspaces.is_local`.
  final SpaceSyncMode syncMode;

  /// Axis B — who owns it? Constant `personal` in #102 (reserved seam).
  final SpaceTenancy tenancy;

  /// The owning user's STABLE id (not an email — SSO-ready, .docs/internal/architecture.md §5).
  /// Constant "current user" in #102; an INPUT to the future PDP, never the
  /// authority. Nullable because the reserved m006 `owner_id` may be unset.
  final String? ownerId;

  @override
  bool operator ==(Object other) =>
      other is SpaceRef &&
      other.id == id &&
      other.syncMode == syncMode &&
      other.tenancy == tenancy &&
      other.ownerId == ownerId;

  @override
  int get hashCode => Object.hash(id, syncMode, tenancy, ownerId);

  @override
  String toString() =>
      'SpaceRef(id: $id, syncMode: $syncMode, tenancy: $tenancy, '
      'ownerId: $ownerId)';
}

/// The minimal item membership facts the resolver needs (the `recordings` row,
/// projected). Pure data — no Drift dependency.
///
/// [matomeSpaceId] is the space of the matome this item is IN (already
/// resolved by the caller from `matome.space_id`); NULL when the item is loose,
/// or in a DRAFT matome (a matome with no space). [workspaceId] is the item's
/// OWN directly-filed space (`recording.workspace_id`); it is SHADOWED — never
/// authoritative — whenever the item is in a matome (.docs/internal/architecture.md §5).
class ItemMembership {
  const ItemMembership({this.matomeSpaceId, this.workspaceId});

  /// `matome.space_id` for the matome this item is in; NULL if the item is not
  /// in a matome, or its matome is a draft (no space).
  final String? matomeSpaceId;

  /// `recording.workspace_id` — the item's own directly-filed space. SHADOWED
  /// by [matomeSpaceId] under the precedence rule (matome WINS); never cleared.
  final String? workspaceId;
}

/// SEALED, EXHAUSTIVE sync-status of an item (.docs/internal/architecture.md §5 / spec R2.1).
///
/// Adding a future case (`orgManaged` / `policyBlocked`) is a COMPILE ERROR at
/// every exhaustive `switch` over this type — there is NO catch-all `default:`
/// arm anywhere that could silently swallow a new state. Switch over the
/// subtypes (Dart sealed-class exhaustiveness) and the analyzer flags every
/// site that has not handled a newly-added subtype.
sealed class SyncStatus {
  const SyncStatus();
}

/// The item's effective space is NULL (loose item, or a draft matome) — it is
/// in the Inbox and NEVER syncs. INBOX ⟺ effectiveSpace == NULL (a VIEW; spec
/// R1.3). There is no stored `is_inbox` — this state IS the Inbox.
final class SyncInbox extends SyncStatus {
  const SyncInbox();
}

/// The item's effective space exists but is a LOCAL space (`is_local = true`)
/// — the NEW local-only state. Organized, but client-only: no Core row, no
/// upload, ever, while it stays in a local space (spec R2).
final class SyncLocalOnly extends SyncStatus {
  const SyncLocalOnly({required this.space});

  /// The local space the item effectively belongs to.
  final SpaceRef space;
}

/// The item's effective space is a CLOUD space (`is_local = false`) — it syncs
/// to Core (spec R2). This is the ONLY status for which sync is eligible.
final class SyncCloud extends SyncStatus {
  const SyncCloud({required this.space});

  /// The cloud space the item effectively belongs to.
  final SpaceRef space;
}

/// The ONE authoritative sync-eligibility resolver (#1493). Every
/// sync-eligibility decision in the program routes through here — no second
/// computation anywhere (.docs/internal/architecture.md §5 / spec R1.2).
abstract final class EffectiveSpace {
  EffectiveSpace._();

  /// **R1 — the effectiveSpace rule.** Resolve the space an item EFFECTIVELY
  /// belongs to:
  ///
  /// ```
  /// effectiveSpaceId = matome.space_id ?? recording.workspace_id
  /// ```
  ///
  /// Matome membership WINS (R1.1): if the item is in a matome, the matome's
  /// space is authoritative and the item's own `workspace_id` is SHADOWED. NULL
  /// ⇒ Inbox (loose item, or draft matome). Returns the effective space id, or
  /// NULL for the Inbox.
  static String? effectiveSpaceId(ItemMembership item) =>
      item.matomeSpaceId ?? item.workspaceId;

  /// **R2 — the sync gate, as a sealed status.** Resolve the item's
  /// [SyncStatus] from its membership and the effective space's VALUE OBJECT.
  ///
  /// [resolveSpace] looks up the [SpaceRef] for a given space id (the caller
  /// supplies the `workspaces` row → VO mapping). It MUST return NULL for an
  /// unknown / missing space id (treated as Inbox — fail-closed, never synced).
  ///
  /// - effective space NULL ⇒ [SyncInbox]
  /// - effective space is LOCAL ⇒ [SyncLocalOnly]
  /// - effective space is CLOUD ⇒ [SyncCloud]
  static SyncStatus statusOf(
    ItemMembership item, {
    required SpaceRef? Function(String spaceId) resolveSpace,
  }) {
    final spaceId = effectiveSpaceId(item);
    if (spaceId == null) return const SyncInbox();

    final space = resolveSpace(spaceId);
    // Fail-closed: an effective space id that resolves to no known space is
    // treated as Inbox (never synced), not silently uploaded.
    if (space == null) return const SyncInbox();

    return switch (space.syncMode) {
      SpaceSyncMode.local => SyncLocalOnly(space: space),
      SpaceSyncMode.cloud => SyncCloud(space: space),
    };
  }

  /// **R2 — `isCloudSynced`.** Whether an item is eligible to sync to Core:
  /// its effective space exists AND is a CLOUD space (`is_local == false`).
  /// Derived from the [SyncStatus] / VALUE OBJECT — the single predicate every
  /// drain decision (#1498) consults.
  static bool isCloudSynced(
    ItemMembership item, {
    required SpaceRef? Function(String spaceId) resolveSpace,
  }) => statusOf(item, resolveSpace: resolveSpace) is SyncCloud;

  /// Whether a given space VALUE OBJECT is a cloud space (`is_local == false`).
  /// The space-level half of the predicate (R2), used by the operation-keyed
  /// gate (#1498) once it consults the resolver. Returns false for a NULL space
  /// (no space ⇒ Inbox ⇒ never synced — fail-closed).
  static bool spaceIsCloud(SpaceRef? space) =>
      space != null && space.syncMode == SpaceSyncMode.cloud;
}
