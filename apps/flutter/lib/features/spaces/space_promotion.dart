// ---------------------------------------------------------------------------
// Space promotion — local → cloud (v1), the DATA-EGRESS path (plan #102 W4 /
// #1499, spec §3 "Promotion runbook"). Promoting a local space is the moment
// its previously client-only items LEAVE THE DEVICE, so idempotency and
// partial-failure correctness are the whole point of this file.
//
// REUSES THE GATE (does NOT build a parallel uploader). Promotion flips a LOCAL
// space to CLOUD by RE-KEYING it to its minted Core id (WorkspacesDao
// .promoteToCloud); after that the items' effective space is a cloud space, so
// the EXISTING sync drain (MatomeSyncService.pushFiled + the upload queue)
// naturally pushes them — keyed on the items' stable/Core ids, never
// re-creating an item that already has one. This service ORCHESTRATES the
// state machine and the consented Core-space create; it does not re-implement
// item upload.
//
// ─── STATE MACHINE (spec R3.4) ─────────────────────────────────────────────
//
//        consent granted            every item acked (has Core id)
//   local ───────────────► promoting ───────────────► cloud
//                             │
//                             │ ≥1 item failed to reach Core
//                             ▼
//                           failed ──── (resume) ──► promoting
//
// The state is held in this TRANSIENT controller, NOT in a new schema column
// (spec §3 "state lives in a controller/transient" — pinned). The DURABLE
// progress is already encoded by `workspaces.is_local` (flipped by the re-key)
// and each item's `coreId` (set on first successful push); the controller's
// state is re-derivable from those on resume, so no extra column is needed
// (in-scope decision — a promotion-state column would be OUT of scope here).
//
//   * `promoting → cloud` is NOT collapsed until EVERY item whose effective
//     space is this space has a Core row. A partial failure lands `failed`
//     (resumable), NEVER a half-cloud space that merely looks done.
//   * The promotion-state type [PromotionState] is SEALED/exhaustive — a future
//     state is a compile error at every switch, no silent default arm (mirrors
//     the resolver's [SyncStatus]).
//
// ─── IDEMPOTENCY (spec R3.3) ───────────────────────────────────────────────
//
// Keyed on each item's STABLE/Core id. The batch drain is the existing
// MatomeSyncService.pushFiled / upload queue, both of which SKIP an item that
// already carries a `coreId` (never re-create). So:
//   * double-tap / retry / crash-mid-batch ⇒ already-pushed items are no-ops;
//   * resume completes only the remainder;
//   * the duplicate-coreId tolerance (commit d8cc85d) keeps a corrupted dup
//     from crashing the drain.
// The space-level Core create (POST /api/spaces) is made idempotent by the
// re-key: once the local `ws_<...>` row has been re-keyed to its numeric Core
// id, a resume sees the space is already cloud and SKIPS the create (no second
// Core space). The only non-idempotent window is a crash strictly between the
// Core `POST /api/spaces` returning and the local re-key transaction
// committing; that can orphan ONE empty Core space on retry, but NEVER
// duplicates an ITEM (the data-egress guarantee) — documented + accepted for v1.
//
// ─── PROMOTE-WHILE-DRAINING CONTRACT (pinned BEFORE coding) ────────────────
//
// NEXT-DRAIN semantics. Flipping the space to cloud is a single atomic Drift
// transaction (the re-key). The promotion's own drain, and every subsequent
// trigger (app-start / connectivity / finish), reads the items FRESH, so the
// NEXT drain pass after the flip picks up the full item set — there is no
// snapshot taken at consent time that could go stale.
//   * IN-FLIGHT item: an item already mid-upload in the upload queue is guarded
//     by that queue's per-id single-flight (`_inFlight`); promotion never
//     interrupts or double-sends it — the in-flight attempt runs to completion
//     and promotion's drain simply sees it already has (or gets) its Core id.
//   * NEW item filed into the space AFTER the flip: it lands in a now-cloud
//     space, so it syncs normally via the R2 gate on the next drain — it is not
//     special-cased by promotion.
//   * An item MOVED OUT of the space mid-promotion (its effective space is no
//     longer this space) is correctly NOT required for this space to reach
//     `cloud` — the completion check re-resolves the live item set each pass.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/items_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/workspaces_dao.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../matome/matome_sync_service.dart';
import '../recordings/upload_queue.dart';
import 'current_caller.dart';
import 'space_ref_mapping.dart';
import 'spaces_repository.dart';
import 'sync_policy.dart';

/// The itemized consent surface input (spec R3.2): the count of items that will
/// LEAVE THE DEVICE when this local space is promoted — items whose EFFECTIVE
/// space is this space and that have NO Core row yet. Split by item kind so the
/// consent copy can say "N recordings, M files will leave this device".
class PromotionConsent {
  const PromotionConsent({
    required this.spaceId,
    required this.spaceName,
    required this.recordingCount,
    required this.matomeCount,
  });

  final String spaceId;
  final String spaceName;

  /// Recordings (audio/file items) whose effective space is this space and that
  /// have no Core row yet — the ones that will egress.
  final int recordingCount;

  /// Matomes filed into this space that have no Core row yet.
  final int matomeCount;

  /// Total items that will leave the device. The consent prompt states this N.
  int get totalCount => recordingCount + matomeCount;
}

/// SEALED, EXHAUSTIVE promotion state (spec R3.4). A future state is a COMPILE
/// ERROR at every exhaustive switch over this type — no catch-all `default:`
/// arm anywhere (mirrors the resolver's sealed `SyncStatus`).
sealed class PromotionState {
  const PromotionState();
}

/// `is_local == true`; the space and its items are local-only. Out-edge:
/// → [PromotionInProgress] on consent.
final class PromotionLocal extends PromotionState {
  const PromotionLocal();
}

/// Consent granted; the Core space exists / is being created and per-item
/// pushes are in flight. Out-edges: → [PromotionCloud] (all items acked) ·
/// → [PromotionFailed] (≥1 item failed).
final class PromotionInProgress extends PromotionState {
  const PromotionInProgress();
}

/// Terminal SUCCESS: `is_local == false` AND every item whose effective space
/// is this space has a Core row. New items sync normally via R2. Terminal — no
/// demote in v1 (spec R3.1).
final class PromotionCloud extends PromotionState {
  const PromotionCloud();
}

/// ≥1 item did not reach Core; promotion is incomplete and RESUMABLE. The space
/// may already be re-keyed to cloud (so its successful items kept their Core
/// rows — no rollback, spec R3.5), but it is NOT reported `cloud` until the
/// remainder drains. Out-edge: → [PromotionInProgress] on resume.
final class PromotionFailed extends PromotionState {
  const PromotionFailed({required this.remaining});

  /// How many items still lack a Core row (still on device).
  final int remaining;
}

/// Orchestrates local→cloud promotion (spec §3). Pure orchestration over the
/// daos, the Core `/spaces` create, and the EXISTING item drain — it does not
/// re-implement item upload.
class SpacePromotionService {
  SpacePromotionService(this._ref);

  final Ref _ref;

  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);
  MatomesDao get _matomesDao => _ref.read(matomesDaoProvider);
  ItemsDao get _itemsDao => _ref.read(itemsDaoProvider);
  SpacesRepository get _repo => _ref.read(spacesRepositoryProvider);
  MatomeSyncService get _matomeSync => _ref.read(matomeSyncServiceProvider);
  UploadQueue get _uploadQueue => _ref.read(uploadQueueProvider);

  /// The acting [Caller] — the future-PDP input. Best-effort owner id; an
  /// unresolved auth chain yields an anonymous caller (which the owner-scope
  /// gate then DENIES — fail-closed, no signed-out promotion). Routed through
  /// the ONE shared resolver [currentCaller] (W4-audit #74801 P3).
  Caller _caller() => currentCaller(_ref);

  /// Compute the ITEMIZED CONSENT (spec R3.2) for promoting [spaceId]: the count
  /// of items whose EFFECTIVE space is this space and that have NO Core row yet
  /// (the ones that will egress). Matome-membership precedence (R1.1) is honored
  /// because the recording count is taken from each matome's children (items
  /// shadowed INTO the space via their matome) PLUS directly-filed loose
  /// recordings, and a recording wrapped in a matome is counted under the matome
  /// (not double-counted) — its egress rides its matome.
  Future<PromotionConsent> consentFor(String spaceId) async {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) {
      return PromotionConsent(
        spaceId: spaceId,
        spaceName: '',
        recordingCount: 0,
        matomeCount: 0,
      );
    }
    final space = await _workspacesDao.getWorkspaceById(spaceId);
    final matomes = await _matomesDao.listMatomesInSpace(spaceId);

    // Matomes filed into the space that have no Core row yet.
    final pendingMatomes = matomes
        .where((m) => m.coreId == null)
        .toList(growable: false);

    // Recordings that will egress:
    //   * children of the (still-uncreated) matomes in this space, and
    //   * recordings filed DIRECTLY into the space (no matome wrapper),
    // each only when they lack a Core row.
    final pendingMatomeIds = matomes
        .map((m) => m.id)
        .toSet(); // membership shadow check
    var pendingRecordings = 0;

    for (final m in matomes) {
      final children = await _itemsDao.listForMatome(m.id, ownerId);
      pendingRecordings += children.where((r) => r.coreId == null).length;
    }

    final directlyFiled = await _itemsDao.listForSpace(spaceId, ownerId);
    for (final r in directlyFiled) {
      // matome WINS (R1.1): a recording wrapped in one of this space's matomes
      // is already counted under that matome — do not double-count it here.
      if (r.matomeId != null && pendingMatomeIds.contains(r.matomeId)) continue;
      if (r.coreId == null) pendingRecordings += 1;
    }

    return PromotionConsent(
      spaceId: spaceId,
      spaceName: space?.name ?? '',
      recordingCount: pendingRecordings,
      matomeCount: pendingMatomes.length,
    );
  }

  /// Promote [spaceId] local→cloud, ON AFFIRMATIVE CONSENT ONLY (the caller
  /// gates the consent UI; this is the affirmative-consent entry point).
  ///
  /// Returns the resulting [PromotionState]: [PromotionCloud] when every item
  /// reached Core, else [PromotionFailed] (resumable). Throws ONLY for the
  /// owner-scope authz denial (a programming/permission error the UI must
  /// surface), never for a transient item/network failure (those land `failed`).
  ///
  /// Safe to call repeatedly (resume): idempotent at both the space level
  /// (re-key skipped once cloud) and the item level (coreId-keyed pushes).
  Future<PromotionState> promote(String spaceId) async {
    final space = await _workspacesDao.getWorkspaceById(spaceId);
    if (space == null) {
      AppLog.event(LogCat.action, 'promote: space gone $spaceId');
      return const PromotionCloud(); // nothing to promote; treat as done.
    }

    // OWNER-SCOPE AUTHZ (spec R3.6) — the SAME operation-keyed gate, keyed on
    // `Operation.spacePromote` (owner-scope, NOT cloudness). A non-owner caller
    // is rejected HERE, at this one gate, before any Core write.
    final spaceRef = spaceRefFromRow(space);
    if (!SyncPolicy.can(_caller(), Operation.spacePromote, spaceRef)) {
      AppLog.event(LogCat.action, 'promote: DENIED (not owner) $spaceId');
      throw const PromotionNotAuthorized();
    }

    // ── local → promoting ───────────────────────────────────────────────────
    // Ensure the space is re-keyed to cloud. Idempotent: if it is already cloud
    // (re-key committed on a prior attempt) we skip the Core create entirely.
    var cloudSpaceId = spaceId;
    if (space.isLocal == 1) {
      final core = await _repo.createSpace(name: space.name);
      cloudSpaceId = core.id.toString();
      AppLog.event(
        LogCat.action,
        'promote: created Core space ${core.id} for $spaceId',
      );
      // Atomic flip (the `promoting` re-key). Idempotent no-op if already done.
      await _workspacesDao.promoteToCloud(oldId: spaceId, newId: cloudSpaceId);
    } else {
      // Already cloud (resume): its local id IS the numeric Core id.
      cloudSpaceId = spaceId;
    }

    // ── drain the items (reuse the existing gate-respecting drain) ───────────
    // The items' effective space is now a CLOUD space, so the EXISTING sync
    // pushes them — keyed on stable/Core ids, never re-creating one that already
    // has a coreId (idempotent resume). Best-effort: a throw is swallowed by the
    // services; the completion check below is the source of truth, never the
    // drain's own return.
    await _drainSpace();

    // ── promoting → cloud | failed ───────────────────────────────────────────
    // Collapse to `cloud` ONLY when EVERY item now has a Core row; otherwise
    // `failed`/resumable. Re-resolve the LIVE item set (promote-while-draining:
    // items moved out are not required; items still here must be acked).
    final remaining = await _remainingItemCount(cloudSpaceId);
    if (remaining == 0) {
      AppLog.event(LogCat.action, 'promote: $spaceId → cloud (all acked)');
      return const PromotionCloud();
    }
    AppLog.event(
      LogCat.action,
      'promote: $spaceId → failed ($remaining item(s) still on device)',
    );
    return PromotionFailed(remaining: remaining);
  }

  /// Run the existing item drain once. Matomes (and their children) push via
  /// [MatomeSyncService.pushFiled]; loose directly-filed recordings push via the
  /// [UploadQueue]. Both are coreId-keyed/idempotent. Never throws out of here
  /// (the completion check is authoritative, not this best-effort pass).
  Future<void> _drainSpace() async {
    try {
      await _matomeSync.pushFiled();
    } catch (e, st) {
      AppLog.error(LogCat.sync, 'promote: matome push pass failed', e, st);
    }
    try {
      await _uploadQueue.drain();
    } catch (e, st) {
      AppLog.error(LogCat.sync, 'promote: upload drain pass failed', e, st);
    }
  }

  /// Count items whose EFFECTIVE space is [cloudSpaceId] that still lack a Core
  /// row (still on device). Re-resolved LIVE each call so resume/promote-while-
  /// draining are honest. A matome counts as remaining if IT lacks a coreId;
  /// each of its children counts if the child lacks one; directly-filed loose
  /// recordings count likewise (matome children are not double-counted).
  Future<int> _remainingItemCount(String cloudSpaceId) async {
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) return 0;
    final matomes = await _matomesDao.listMatomesInSpace(cloudSpaceId);
    final matomeIds = matomes.map((m) => m.id).toSet();
    var remaining = 0;

    for (final m in matomes) {
      if (m.coreId == null) remaining += 1;
      final children = await _itemsDao.listForMatome(m.id, ownerId);
      remaining += children.where((r) => r.coreId == null).length;
    }

    final directlyFiled = await _itemsDao.listForSpace(cloudSpaceId, ownerId);
    for (final r in directlyFiled) {
      if (r.matomeId != null && matomeIds.contains(r.matomeId)) continue;
      if (r.coreId == null) remaining += 1;
    }
    return remaining;
  }
}

/// Thrown by [SpacePromotionService.promote] when the owner-scope gate
/// (`Operation.spacePromote`, spec R3.6) denies the caller — a non-owner cannot
/// promote/assign. Distinct from a transient item failure (which lands
/// `failed`, never throws).
class PromotionNotAuthorized implements Exception {
  const PromotionNotAuthorized();
  @override
  String toString() => 'PromotionNotAuthorized: caller does not own the space';
}

/// The promotion service. Overridable in tests.
final spacePromotionServiceProvider = Provider<SpacePromotionService>(
  (ref) => SpacePromotionService(ref),
);

/// The ITEMIZED CONSENT (spec R3.2) for promoting a given local space, computed
/// from the resolver (items whose effective space is this space with no Core
/// row yet). The W0 promote-consent surface reads this to render the real
/// "N recordings, M files will leave this device" count instead of a mock —
/// keyed by the space id (family).
final promotionConsentProvider = FutureProvider.autoDispose
    .family<PromotionConsent, String>((ref, spaceId) {
      return ref.read(spacePromotionServiceProvider).consentFor(spaceId);
    });
