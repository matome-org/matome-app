// ---------------------------------------------------------------------------
// SyncPolicy — the ONE operation-keyed decision point for sync/data-egress
// (local-first-spaces #102 W4 / #1498, ADR-0006 H4 seam 2, sync-gate spec R2.1).
//
// This is the client mirror of a future Core Bodyguard seam. EVERY data-egress
// decision (the upload-queue drain, the moveToSpace Core PATCH, later promotion)
// routes through `SyncPolicy.can(caller, operation, space)` — never an inline
// `if (isCloudSynced)` and never a role check.
//
// > **R2.1 — one operation-keyed gate.** The drain decision flows through ONE
// > decision point and that gate is OPERATION-KEYED, not role-keyed:
// >
// >     SyncPolicy.can(caller, Operation.spaceSync, space)
// >
// > Today this returns `isCloudSynced(space)` (owner ⇒ allow) by delegating to
// > the ONE resolver [EffectiveSpace]. Later a PDP resolves
// > caller → groups → (custom) roles → operations from DATA, behind THIS SAME
// > call site with ZERO call-site changes — that is the whole point of keying on
// > a stable OPERATION catalog key instead of a frozen role enum.
//
// LOCKED forward-compat seams (do NOT "simplify" away):
//   * NO fixed `owner | admin | member | viewer` role enum anywhere. Roles are
//     future DATA (deferred authz plan, project comment #74119), not enums.
//   * The OPERATION catalog ([Operation]) starts minimal (spaceRead / spaceWrite
//     / spaceSync). A new operation is added to the catalog, not as a new gate.
//   * [Caller] carries the current user id — the future-PDP input. Constant
//     "current user" today, but present in the signature so the PDP adds inputs,
//     not a rewrite.
//   * Sync-eligibility is NOT recomputed here. `spaceSync` delegates to the SOLE
//     authority [EffectiveSpace.spaceIsCloud]. A second predicate here would be
//     exactly the data leak the resolver spine exists to prevent (spec R1.2).
// ---------------------------------------------------------------------------

import 'effective_space.dart';

/// The minimal, STABLE operation catalog the gate keys on (ADR-0006 H4 seam 2 /
/// spec R2.1). Adding `orgManaged` etc. later is a catalog entry, NOT a new
/// call site. Deliberately NOT a role enum — roles are future DATA.
enum Operation {
  /// Read a space's items (view). Reserved seam — no caller gates on it yet.
  spaceRead,

  /// Write/file into a space (organize). Filing is ALLOWED for any space
  /// (including local) — filing ≠ sync (spec R2: "filing is not the sync
  /// trigger"). Reserved seam; the gate returns true for it today.
  spaceWrite,

  /// Sync a space's items OUT to Core — the data-egress operation. Permitted
  /// IFF the effective space is a CLOUD space (today: owner ⇒ allow). This is
  /// the gate the upload-queue drain and the moveToSpace Core PATCH consult.
  spaceSync,

  /// Promote a LOCAL space to cloud — the data-egress *authorization* gate for
  /// promotion (plan #102 W4 / #1499 / spec R3.6). UNLIKE [spaceSync], this is
  /// keyed on OWNER-SCOPE, NOT on the space being cloud — the whole point is to
  /// promote a space that is STILL local. Permitted IFF the caller OWNS the
  /// space (today: a resolved caller whose id matches `space.ownerId`, OR — when
  /// `ownerId` is the reserved/unset m006 NULL — a resolved caller, since every
  /// #102 personal space is the current user's). A non-owner (a future
  /// shared/org case) is DENIED at this one gate (spec R3.6), so promotion's
  /// Core writes never run for a space the caller does not own. No new role enum
  /// is introduced — the deferred PDP governs this key later with zero call-site
  /// change.
  spacePromote,
}

/// The PRINCIPAL a [SyncPolicy] decision is made FOR — the future-PDP input
/// (ADR-0006 H4). Carries the current user's STABLE id (SSO-ready; not an
/// email). Constant "current user" in #102; an INPUT to the future PDP, never
/// the authority. Present in the signature so the PDP adds resolution
/// (caller → groups → roles → operations) without a call-site rewrite.
class Caller {
  const Caller({this.userId});

  /// The acting user's stable id, or null when signed out / unresolved.
  /// fail-closed semantics live at the gate, not here.
  final String? userId;

  /// A caller with no resolved user. Useful as a default; today `spaceSync`
  /// still gates only on the space being cloud (owner ⇒ allow), so the user id
  /// is carried for the future PDP, not yet consulted.
  static const Caller anonymous = Caller();

  @override
  bool operator ==(Object other) => other is Caller && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'Caller(userId: $userId)';
}

/// The ONE operation-keyed decision point (#1498). Pure, DB-free: it consumes a
/// [SpaceRef] VALUE OBJECT (the caller does the row → VO mapping) and the
/// resolver's space-level predicate. No second sync predicate is invented here.
abstract final class SyncPolicy {
  SyncPolicy._();

  /// Whether [caller] may perform [op] on [space].
  ///
  /// - [Operation.spaceSync] — the data-egress gate. Permitted IFF the effective
  ///   [space] is a CLOUD space (`is_local == false`), via the SOLE authority
  ///   [EffectiveSpace.spaceIsCloud]. A NULL space (Inbox) or a LOCAL space is
  ///   DENIED — fail-closed, never egressed. Today owner ⇒ allow; [caller] is
  ///   carried for the future PDP but not yet consulted (every #102 caller owns
  ///   its personal space).
  /// - [Operation.spaceWrite] — filing/organizing. ALLOWED for any resolvable
  ///   space (including LOCAL) — filing ≠ sync (spec R2). DENIED only for a NULL
  ///   space (nothing to file into).
  /// - [Operation.spaceRead] — reserved seam; ALLOWED for any resolvable space.
  ///
  /// A NULL [space] is always denied: the Inbox (effective space NULL) is never
  /// a sync/read/write target.
  static bool can(Caller caller, Operation op, SpaceRef? space) {
    if (space == null) return false;
    return switch (op) {
      // The data-egress gate: delegate to the ONE resolver. No recompute here.
      Operation.spaceSync => EffectiveSpace.spaceIsCloud(space),
      // Promotion authz (spec R3.6): OWNER-SCOPE, never `is_local` — a local
      // space is exactly what promotion turns cloud, so gating on cloudness here
      // would make promotion impossible. Permitted iff the caller owns the
      // space. When the space carries a concrete `ownerId` (future shared/org),
      // the caller's resolved id MUST match it — a non-owner is DENIED. When
      // `ownerId` is the reserved/unset m006 NULL (every #102 personal space),
      // any RESOLVED caller is the owner (their own personal space); an
      // unresolved/anonymous caller (null userId) is DENIED — fail-closed, no
      // signed-out promotion.
      Operation.spacePromote => _ownsSpace(caller, space),
      // Filing/organizing and reading are allowed for any resolvable space;
      // local spaces organize without syncing (the spaceSync gate enforces the
      // egress boundary, not the picker).
      Operation.spaceWrite || Operation.spaceRead => true,
    };
  }

  /// Owner-scope predicate for [Operation.spacePromote] (spec R3.6). A caller
  /// owns [space] iff:
  ///   * the space names an owner (`ownerId != null`) AND the caller's resolved
  ///     id equals it — a non-owner is rejected (the future shared/org case); or
  ///   * the space has no named owner (reserved/unset m006 NULL — every #102
  ///     personal space) AND the caller is RESOLVED (a non-null user id) — it is
  ///     the caller's own personal space.
  /// An anonymous/unresolved caller (null userId) never owns — fail-closed.
  static bool _ownsSpace(Caller caller, SpaceRef space) {
    final callerId = caller.userId;
    if (callerId == null) return false; // signed-out / unresolved — deny.
    final ownerId = space.ownerId;
    if (ownerId == null) return true; // unowned personal space ⇒ caller's own.
    return ownerId == callerId; // explicit owner ⇒ must match.
  }
}
