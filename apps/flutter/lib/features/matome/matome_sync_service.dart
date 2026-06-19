import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart';
import '../../core/db/daos/matomes_dao.dart';
import '../../core/db/daos/recordings_dao.dart';
import '../../core/http/api_exception.dart';
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
    try {
      await pushFiled();
      await pull();
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.statusCode != null) {
        developer.log('Matome sync failed (not offline)',
            name: 'matome.sync', error: error);
      }
    } catch (error, stack) {
      developer.log('Matome sync write failed',
          name: 'matome.sync', error: error, stackTrace: stack);
    }
  }

  // ---------------------------------------------------------------------------
  // PUSH — only filed Matomes (space-scoped rule).
  // ---------------------------------------------------------------------------

  /// Push every FILED Matome (`space_id != null`) to Core, then its contacts and
  /// child recordings (child-before-parent). Inbox Matomes are never pushed.
  Future<void> pushFiled() async {
    final filed = await _matomesDao.listFiledMatomes();
    for (final matome in filed) {
      // Space-scoped guard (defensive — the query already filters): an untriaged
      // Matome must never reach Core.
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
    }
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
