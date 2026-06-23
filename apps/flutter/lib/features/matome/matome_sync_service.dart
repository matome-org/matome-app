import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../contacts/contacts_repository.dart';
import '../recordings/recordings_repository.dart';
import 'matome.dart';
import 'matome_sync.dart';
import 'matomes_repository.dart';

/// Space-scoped Matome + Contact sync (ADR-0004, task #1377), mirroring the
/// recordings sync in `inbox_controller` / `inbox_sync`.
///
/// Cohesive, single-entry orchestration (no scheduler): [sync] PUSHES filed
/// Matomes (and their contacts + child recordings) then PULLS the user's
/// triaged Matomes/Contacts and upserts them into Drift with merge-guards. The
/// display layer keeps reading from Drift; this only reconciles.
///
/// Enforced invariants:
///   * SPACE-SCOPED — only a Matome with `space_id != null` is ever pushed.
///     Inbox Matomes (`space_id == null`) stay local-only (see [pushFiled]).
///   * CHILD-BEFORE-PARENT (council P0) — a recording's remote `matome_id` is
///     its Matome's `core_id`, so a Matome is pushed (and reconciles its
///     `core_id`) BEFORE any of its recordings send `matome_id`. A recording
///     whose Matome still has no `core_id` does NOT send one (see [_pushChildren]).
///   * RECONCILE BY core_id — never a PK remap; first push fills the local
///     `core_id` from the created remote id.
class MatomeSyncService {
  MatomeSyncService(this._ref);

  final Ref _ref;

  MatomesDao get _matomesDao => _ref.read(matomesDaoProvider);
  ContactsDao get _contactsDao => _ref.read(contactsDaoProvider);
  RecordingsDao get _recordingsDao => _ref.read(recordingsDaoProvider);
  MatomesRepository get _matomesRepo => _ref.read(matomesRepositoryProvider);
  ContactsRepository get _contactsRepo => _ref.read(contactsRepositoryProvider);
  RecordingsRepository get _recordingsRepo =>
      _ref.read(recordingsRepositoryProvider);

  /// One full reconcile pass: push local filed state up, then pull remote state
  /// down. Best-effort — network/auth failures are logged (non-offline) and
  /// swallowed so the local store keeps rendering.
  Future<void> sync() async {
    AppLog.event(LogCat.sync, 'sync: start');
    try {
      await pushFiled();
      await pull();
      AppLog.event(LogCat.sync, 'sync: done');
    } on ApiException catch (error, stack) {
      if (error.isUnauthorized || error.statusCode != null) {
        developer.log('Matome sync failed (not offline)',
            name: 'matome.sync', error: error);
        AppLog.error(
            LogCat.sync, 'sync: failed (not offline)', error, stack);
      }
    } catch (error, stack) {
      developer.log('Matome sync write failed',
          name: 'matome.sync', error: error, stackTrace: stack);
      AppLog.error(LogCat.sync, 'sync: write failed', error, stack);
    }
  }

  // ---------------------------------------------------------------------------
  // EDIT — local-first rename / re-date (task #1408).
  // ---------------------------------------------------------------------------

  /// Edit a Matome's [title] and/or [happenedAt] LOCAL-FIRST: write the patch to
  /// Drift first (so the UI reflects it immediately, offline-safe), then PATCH
  /// Core when the Matome is already reconciled (`core_id != null`). Reconcile is
  /// by `core_id` — the local PK is never remapped.
  ///
  /// An un-reconciled Matome (`core_id == null`, e.g. an Inbox/local-only one)
  /// only gets the Drift write; its edits ride to Core later via the normal push
  /// path once it is filed and created. Only non-null fields are written/sent.
  Future<void> editMatome(
    String id, {
    String? title,
    DateTime? happenedAt,
  }) async {
    final trimmedTitle = title?.trim();

    // LOCAL-FIRST: write Drift before any network call.
    final patch = MatomesCompanion(
      title: (trimmedTitle == null || trimmedTitle.isEmpty)
          ? const Value.absent()
          : Value(trimmedTitle),
      happenedAt: happenedAt == null
          ? const Value.absent()
          : Value(happenedAt.millisecondsSinceEpoch),
    );
    await _matomesDao.updateMatome(id, patch);

    // SYNC: only a reconciled Matome (has a Core id) can be PATCHed.
    final row = await _matomesDao.getById(id);
    final coreId = row?.coreId;
    if (coreId == null) return;

    await _matomesRepo.updateMatome(
      coreId,
      title: (trimmedTitle == null || trimmedTitle.isEmpty) ? null : trimmedTitle,
      happenedAt: happenedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // ARCHIVE / RESTORE — local-first soft-delete (task #1409).
  // ---------------------------------------------------------------------------

  /// Archive (soft-delete) a Matome LOCAL-FIRST and OFFLINE-FIRST (#1431/W-1):
  /// stamp `archived_at` in Drift first (so it leaves every local list
  /// immediately, offline-safe), then POST Core when the Matome is already
  /// reconciled (`core_id != null`). The local archive is AUTHORITATIVE — the
  /// Core POST is best-effort and may throw (offline / server error); callers do
  /// NOT roll the local archive back.
  ///
  /// CONVERGENCE (#1431, audit #70912): a Core leg that does not land does NOT
  /// silently revert. Two cooperating mechanisms make the two ends converge to
  /// ARCHIVED on the next sync:
  ///   * the archive-adopt guard in `matomeToCompanion` (`_mergeArchivedAt`)
  ///     prevents a pull — where Core, whose default list excludes archived,
  ///     returns the row as active (`archived_at = null`) — from clobbering the
  ///     local archive; and
  ///   * [pushArchives] (run from [pushFiled]) re-POSTs the archive for every
  ///     locally-archived reconciled row, so Core actually converges to archived
  ///     (it is NOT merely "reconciled on pull").
  /// An un-reconciled (Inbox/local-only) Matome only gets the Drift write — it
  /// was never on Core to archive. The row and its child recordings are RETAINED
  /// (recoverable via [restoreMatome]); reconcile is by `core_id`, never a PK
  /// remap.
  Future<void> archiveMatome(String id) async {
    // LOCAL-FIRST: write Drift before any network call.
    await _matomesDao.archive(id);

    // SYNC: only a reconciled Matome (has a Core id) can be archived on Core.
    final row = await _matomesDao.getById(id);
    final coreId = row?.coreId;
    if (coreId == null) return;

    // BEST-EFFORT: a throw here is intentionally left to the caller — the local
    // archive stays put and the next [pull] reconciles by `core_id`.
    await _matomesRepo.archiveMatome(coreId);
  }

  /// Restore (un-archive) a Matome LOCAL-FIRST and OFFLINE-FIRST (#1431/W-2):
  /// clear `archived_at` in Drift first (so it returns to the lists immediately,
  /// offline-safe), then POST Core when the Matome is reconciled
  /// (`core_id != null`). The local restore is AUTHORITATIVE — the Core POST is
  /// best-effort and may throw; callers do NOT roll the local restore back.
  ///
  /// A locally-restored row is ACTIVE (`archived_at = null`), so the archive-
  /// adopt guard in `matomeToCompanion` does NOT engage for it: the next [pull]
  /// adopts Core's archived/active state by `core_id` (merge-guarded) normally.
  /// If the restore POST failed to reach Core, the local row is still active and
  /// — because it is no longer in the archived-reconciled push set — is not
  /// re-archived; a subsequent edit/push or a Core-side change reconciles it.
  /// Reconcile is by `core_id`, never a PK remap.
  Future<void> restoreMatome(String id) async {
    // LOCAL-FIRST: write Drift before any network call.
    await _matomesDao.restore(id);

    final row = await _matomesDao.getById(id);
    final coreId = row?.coreId;
    if (coreId == null) return;

    // BEST-EFFORT: a throw here is left to the caller — the local restore stays
    // put and the next [pull] reconciles by `core_id` (see docstring above).
    await _matomesRepo.restoreMatome(coreId);
  }

  // ---------------------------------------------------------------------------
  // PUSH — only filed Matomes (space-scoped rule).
  // ---------------------------------------------------------------------------

  /// Push every FILED Matome (`space_id != null`) to Core, then its contacts and
  /// child recordings (child-before-parent). Inbox Matomes are never pushed.
  Future<void> pushFiled() async {
    final filed = await _matomesDao.listFiledMatomes();
    AppLog.event(LogCat.sync, 'pushFiled: ${filed.length} filed matomes');
    var pushed = 0;
    for (final matome in filed) {
      // Space-scoped guard (defensive — the query already filters): an untriaged
      // Matome must never reach Core.
      //
      // INLINE SYNC-ELIGIBILITY CHECK (pre-#102). This is the live drain gate
      // today (`space_id != null` ⇒ push). Plan #102 W1 #1493 introduced the ONE
      // authoritative resolver `EffectiveSpace.isCloudSynced` (lib/features/
      // spaces/effective_space.dart) — the SOLE sync-eligibility authority. This
      // site is DEFERRED to W4 #1498, which routes the drain through the single
      // operation-keyed gate that consults the resolver (so local spaces stop
      // draining), behind the `localFirstSpaces` flag. Until then this check is
      // unchanged so #1493 ships dark and changes no live sync behaviour. Do NOT
      // add a second `is_local` predicate here — that recompute is exactly what
      // the resolver exists to prevent (ADR-0006 §2 / spec R1.2).
      if (matome.spaceId == null) continue;

      // The Space must be Core-backed (a numeric workspace id) to file the
      // Matome under it. A locally-created `ws_<...>` Space has no Core
      // counterpart, so its Matomes can't be pushed yet — left local-only.
      final coreWorkspaceId = int.tryParse(matome.spaceId!);
      if (coreWorkspaceId == null) continue;

      var coreId = matome.coreId;
      if (coreId == null) {
        // FIRST push: create remote, reconcile the local `core_id` (no PK remap).
        final created = await _matomesRepo.createMatome(
          title: matome.title,
          workspaceId: coreWorkspaceId,
          happenedAt: DateTime.fromMillisecondsSinceEpoch(matome.happenedAt),
          description: matome.description,
          aggregatedSummary: matome.aggregatedSummary,
        );
        coreId = created.id;
        await _matomesDao.updateMatome(
          matome.id,
          MatomesCompanion(coreId: Value(coreId)),
        );
      }

      await _pushContacts(matome.id, coreId);
      await _pushChildren(matome.id, coreId);
      pushed++;
    }
    AppLog.event(LogCat.sync, 'pushFiled: pushed $pushed');

    // ARCHIVE-INTENT RE-PUSH (#1431, audit #70912): a separate pass so an
    // archive POST that fails (offline) cannot abort the active-matome push.
    await pushArchives();
  }

  /// Converge Core to ARCHIVED for every locally-archived, reconciled Matome
  /// (#1431, audit #70912). A Matome archived locally while its Core POST failed
  /// (the offline-archive window) is still active on Core; [pull] keeps the
  /// local archive (the archive-adopt guard in `matomeToCompanion`), and THIS
  /// pass re-POSTs the archive so the two ends genuinely converge to archived.
  ///
  /// Best-effort and idempotent: re-archiving on Core just refreshes the stamp,
  /// and a throw on one row (offline / server error) is caught so it neither
  /// aborts the pass nor the surrounding push — the row is simply retried on the
  /// next sync. Once Core confirms the archive it stops listing the row, so the
  /// guard and this re-push stop firing for it.
  Future<void> pushArchives() async {
    final archived = await _matomesDao.listArchivedReconciledMatomes();
    var converged = 0;
    for (final matome in archived) {
      final coreId = matome.coreId;
      if (coreId == null) continue; // defensive — the query already filters.
      try {
        await _matomesRepo.archiveMatome(coreId);
        converged++;
      } on ApiException catch (error, stack) {
        // Offline / server error — leave it for the next sync to retry.
        AppLog.error(
            LogCat.sync, 'pushArchives: archive re-push failed', error, stack);
      }
    }
    AppLog.event(LogCat.sync, 'pushArchives: converged $converged');
  }

  /// Push the Matome's local contact edges: ensure each tagged Contact has a
  /// `core_id` (create it on Core if not), then attach the edge. Attach is
  /// idempotent on Core (a re-attach is a no-op), mirroring the local set-merge
  /// rule.
  Future<void> _pushContacts(String matomeId, int matomeCoreId) async {
    final entries = await _contactsDao.listContactsForMatome(matomeId);
    for (final entry in entries) {
      final contact = entry.contact;
      var contactCoreId = contact.coreId;
      if (contactCoreId == null) {
        final created = await _contactsRepo.createContact(
          displayName: contact.displayName,
          metadata: contact.metadata,
          linkedUserId: contact.linkedUserId,
        );
        contactCoreId = created.id;
        await _contactsDao.updateContact(
          contact.id,
          ContactsCompanion(coreId: Value(contactCoreId)),
        );
      }
      await _matomesRepo.attachContact(
        matomeId: matomeCoreId,
        contactId: contactCoreId,
        role: entry.role,
      );
    }
  }

  /// CHILD-BEFORE-PARENT: now that the Matome has [matomeCoreId], stamp it onto
  /// each child recording that itself already has a `core_id` (is reconciled
  /// with Core). A recording with no `core_id` yet is skipped — it carries its
  /// `matome_id` once it reconciles, never before (so Core never sees a dangling
  /// matome reference).
  Future<void> _pushChildren(String matomeId, int matomeCoreId) async {
    final children = await _recordingsDao.recordingsForMatome(matomeId);
    for (final rec in children) {
      final recCoreId = rec.coreId;
      if (recCoreId == null) continue; // not reconciled — do not send matome_id
      await _recordingsRepo.updateRecording(
        recCoreId,
        matomeId: matomeCoreId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PULL — the user's triaged Matomes + Contacts, merge-guarded upsert.
  // ---------------------------------------------------------------------------

  /// Pull Contacts FIRST (so a Matome's pulled contact edges can resolve their
  /// local contact by `core_id`), then Matomes + their edge sets.
  Future<void> pull() async {
    await pullContacts();
    await pullMatomes();
  }

  /// Pull Contacts and upsert by `core_id` (no duplicate on re-sync). A sparse
  /// metadata payload is merge-guarded by [contactToCompanion].
  Future<void> pullContacts() async {
    final remote = await _contactsRepo.fetchContacts();
    for (final contact in remote) {
      final existing = await _contactsDao.contactByCoreId(contact.id) ??
          await _contactsDao.getById(coreIdToLocalId(contact.id));
      await _contactsDao.upsert(contactToCompanion(contact, existing: existing));
    }
    AppLog.event(LogCat.sync, 'pullContacts: upserted ${remote.length}');
  }

  /// Pull Matomes and upsert by `core_id`, then reconcile each Matome's contact
  /// edge SET. Merge-survival (set-merge rule): a pulled edge is idempotently
  /// ADDED (never re-keyed), and a local edge Core simply did not return is NOT
  /// dropped — removal is explicit-only.
  Future<void> pullMatomes() async {
    final remote = await _matomesRepo.fetchMatomes();
    for (final matome in remote) {
      final existing = await _matomesDao.matomeByCoreId(matome.id) ??
          await _matomesDao.getById(coreIdToLocalId(matome.id));
      await _matomesDao.upsert(matomeToCompanion(matome, existing: existing));

      // The local PK the edges hang off (existing UUID, else stringified Core id).
      final localMatomeId = existing?.id ?? coreIdToLocalId(matome.id);
      await _reconcileContactEdges(localMatomeId, matome.contacts);
    }
    AppLog.event(LogCat.sync, 'pullMatomes: upserted ${remote.length}');
  }

  /// Merge the pulled `matome_contacts` edge set onto the local Matome. Each
  /// pulled edge's remote `contact_id` is mapped to a local Contact by `core_id`
  /// (skipped if that Contact hasn't been pulled yet) and idempotently added —
  /// the UNIQUE(matome_id, contact_id) makes a re-add a no-op. A local edge Core
  /// omitted is left intact (set-merge survival; no implicit removal).
  Future<void> _reconcileContactEdges(
    String localMatomeId,
    List<MatomeContactEdge> edges,
  ) async {
    for (final edge in edges) {
      final contact = await _contactsDao.contactByCoreId(edge.contactId);
      if (contact == null) continue; // contact not local yet — pull will fill it
      await _contactsDao.addContactToMatome(
        matomeId: localMatomeId,
        contactId: contact.id,
        role: edge.role,
      );
    }
  }
}

/// The space-scoped Matome/Contact sync service.
final matomeSyncServiceProvider = Provider<MatomeSyncService>((ref) {
  return MatomeSyncService(ref);
});
