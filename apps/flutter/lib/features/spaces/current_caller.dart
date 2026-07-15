// ---------------------------------------------------------------------------
// currentCaller(Ref) — the ONE caller-resolution helper for the sync gate
// (local-first-spaces #102 W6 / W4-audit #74801 P3). Previously the same
// try/catch over `currentOwnerIdProvider` was triplicated across
// inbox_controller / upload_queue / space_promotion (and W6 adds a fourth call
// site in matome_sync_service). Extracting it keeps the BEST-EFFORT, fail-closed
// resolution semantics identical at every gate call site.
//
// BEST-EFFORT: an unresolved auth chain (e.g. secure-storage platform channels
// unavailable in a headless test, or a signed-out session) yields
// [Caller.anonymous] rather than throwing. This never WIDENS access: the
// `spaceSync` decision gates only on the space being cloud (a null user id is
// carried for the future PDP but not consulted), and the `spacePromote`
// owner-scope gate DENIES an anonymous caller (fail-closed — no signed-out
// promotion). So routing every gate decision through this one helper keeps the
// whole egress surface fail-closed with a single, audited resolution path.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/current_owner.dart' show currentOwnerIdProvider;
import 'sync_policy.dart';

/// Resolve the acting [Caller] (the future-PDP input) BEST-EFFORT from the
/// authenticated session owner id. An unresolved/throwing auth chain yields
/// [Caller.anonymous] — fail-closed, never a throw out of a gate decision.
Caller currentCaller(Ref ref) {
  try {
    return Caller(userId: ref.read(currentOwnerIdProvider));
  } catch (_) {
    return Caller.anonymous;
  }
}
