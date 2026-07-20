import 'package:drift/drift.dart';

import '../app_database.dart';
import 'items_dao.dart';
import '../tables.dart';

part 'contacts_dao.g.dart';

/// CRUD + edge DAO for **Contacts** and their join tables (.docs/internal/architecture.md §11 (D4) — identity
/// & contacts, m008).
///
/// SCHEMA-READY, NOT ENFORCED: none of these methods apply ACL / permission /
/// profile / sharing logic. They exercise the contacts schema so the
/// `matome-collaboration` plan can build behaviour on top later. Do not gate
/// any access on them today.
///
/// Deletion-cascade contract (.docs/internal/architecture.md §11 (D4)): cascade is done by EXPLICIT DAO
/// DELETES inside a transaction — NOT by an on-disk FK `onDelete` clause. This
/// project's drift build does not emit REFERENCES DDL (the `.references(...)`
/// hints are relation/query metadata only; the generated DDL carries no FK), so
/// a runtime `PRAGMA foreign_keys` cascade would silently not fire. The explicit
/// deletes here are the authoritative mechanism:
///   * [deleteContact] drops the Contact's `matome_contacts` / `space_contacts`
///     edges, but NOT the Matomes or Spaces it was tagged in;
///   * [deleteMatomeEdges] drops a Matome's `matome_contacts` / `matome_shares`
///     edges, but NOT the Contacts themselves — called by `MatomesDao.delete
///     Matome` so deleting a Matome cleans up its edges.
/// `matome_shares` shares with a raw user id (no Contact FK), so it is cleared
/// on Matome delete only, never on Contact delete.
///
/// Set-merge rule (M:N edge-conflict): every `add*` is IDEMPOTENT — the UNIQUE
/// constraint on (matome_id, contact_id) / (space_id, contact_id) means a
/// re-sync that re-adds an already-present edge is a no-op (`insertOnConflict
/// Ignore`). Removal is therefore EXPLICIT-ONLY: a partial "re-sync" set that
/// omits an existing member never drops that member's row. Membership is a
/// union (merge), never a replace.
@DriftAccessor(
  tables: [
    Contacts,
    MatomeContacts,
    SpaceContacts,
    MatomeShares,
    Matomes,
    Workspaces,
    Items,
    ItemContacts,
  ],
)
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  // ---------------------------------------------------------------------------
  // contacts — CRUD
  // ---------------------------------------------------------------------------

  /// Insert a new Contact.
  Future<void> create(ContactsCompanion entry) {
    return into(contacts).insert(entry);
  }

  /// Insert-or-replace (upsert) by primary key — used by the Core reconcile
  /// path (mirrors matomes' `upsert`).
  Future<void> upsert(ContactsCompanion entry) {
    return into(contacts).insertOnConflictUpdate(entry);
  }

  Future<ContactRow?> getById(String id) {
    return (select(contacts)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Local row whose reconciled Core id is [coreId], or null if none has been
  /// reconciled yet.
  Future<ContactRow?> contactByCoreId(int coreId) {
    return (select(
      contacts,
    )..where((c) => c.coreId.equals(coreId))).getSingleOrNull();
  }

  /// All Contacts owned by [ownerId], display-name ascending.
  Future<List<ContactRow>> listContactsForOwner(String ownerId) {
    return (select(contacts)
          ..where((c) => c.ownerId.equals(ownerId))
          ..orderBy([(c) => OrderingTerm.asc(c.displayName)]))
        .get();
  }

  /// Every Contact, display-name ascending.
  Future<List<ContactRow>> listContacts() {
    return (select(
      contacts,
    )..orderBy([(c) => OrderingTerm.asc(c.displayName)])).get();
  }

  /// Partial update — only the provided companion fields are written. Named
  /// `updateContact` so it does not shadow the inherited [update] builder.
  Future<int> updateContact(String id, ContactsCompanion patch) {
    return (update(contacts)..where((c) => c.id.equals(id))).write(patch);
  }

  /// Delete a Contact by id, EXPLICITLY cascading its `matome_contacts` /
  /// `space_contacts` edges (set-merge: only this contact's edges, never the
  /// Matomes/Spaces it was tagged in). `matome_shares` is by user id, so it is
  /// untouched. Runs in a transaction so the contact and its edges go atomically.
  /// Named `deleteContact` so it does not shadow the inherited [delete] builder.
  /// Returns rows deleted from the `contacts` table.
  Future<int> deleteContact(String id) {
    return transaction(() async {
      await (delete(matomeContacts)..where((e) => e.contactId.equals(id))).go();
      await (delete(spaceContacts)..where((e) => e.contactId.equals(id))).go();
      await (delete(itemContacts)..where((e) => e.contactId.equals(id))).go();
      return (delete(contacts)..where((c) => c.id.equals(id))).go();
    });
  }

  /// Cascade-delete a Matome's edges: its `matome_contacts` and `matome_shares`
  /// rows (NOT the Contacts themselves). Called by `MatomesDao.deleteMatome` so
  /// deleting a Matome cleans up its edges. Returns the total edge rows deleted.
  Future<int> deleteMatomeEdges(String matomeId) {
    return transaction(() async {
      final a = await (delete(
        matomeContacts,
      )..where((e) => e.matomeId.equals(matomeId))).go();
      final b = await (delete(
        matomeShares,
      )..where((e) => e.matomeId.equals(matomeId))).go();
      return a + b;
    });
  }

  // ---------------------------------------------------------------------------
  // matome_contacts — tag a Contact in a Matome (role-bearing edge).
  // role ∈ { organizer | attendee | speaker }.
  // ---------------------------------------------------------------------------

  /// Idempotently tag [contactId] in [matomeId] with [role]. The UNIQUE
  /// (matome_id, contact_id) constraint makes a re-add a NO-OP (set-merge rule):
  /// `insertOnConflictIgnore` swallows the duplicate without touching other
  /// members' rows. NOTE: because conflicts are ignored, a re-add does NOT
  /// rewrite an existing edge's `role`; use [setMatomeContactRole] for that.
  Future<void> addContactToMatome({
    required String matomeId,
    required String contactId,
    String role = 'attendee',
    String? id,
  }) {
    return into(matomeContacts).insert(
      MatomeContactsCompanion.insert(
        id: id ?? _mintEdgeId('mc', matomeId, contactId),
        matomeId: matomeId,
        contactId: contactId,
        role: Value(role),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Update the `role` of an existing (matome, contact) edge. Returns rows
  /// updated (0 if the edge does not exist).
  Future<int> setMatomeContactRole({
    required String matomeId,
    required String contactId,
    required String role,
  }) {
    return (update(matomeContacts)..where(
          (e) => e.matomeId.equals(matomeId) & e.contactId.equals(contactId),
        ))
        .write(MatomeContactsCompanion(role: Value(role)));
  }

  /// Remove a single (matome, contact) edge. EXPLICIT-ONLY removal (set-merge
  /// rule): membership is never trimmed implicitly by a partial re-sync.
  Future<int> removeContactFromMatome({
    required String matomeId,
    required String contactId,
  }) {
    return (delete(matomeContacts)..where(
          (e) => e.matomeId.equals(matomeId) & e.contactId.equals(contactId),
        ))
        .go();
  }

  /// The Contacts tagged in [matomeId], paired with their edge `role`,
  /// display-name ascending.
  Future<List<MatomeContactEntry>> listContactsForMatome(String matomeId) {
    final query =
        select(matomeContacts).join([
            innerJoin(
              contacts,
              contacts.id.equalsExp(matomeContacts.contactId),
            ),
          ])
          ..where(matomeContacts.matomeId.equals(matomeId))
          ..orderBy([OrderingTerm.asc(contacts.displayName)]);
    return query.map((row) {
      return MatomeContactEntry(
        contact: row.readTable(contacts),
        role: row.readTable(matomeContacts).role,
      );
    }).get();
  }

  // ---------------------------------------------------------------------------
  // space_contacts — Contact as a Space member.
  // ---------------------------------------------------------------------------

  /// Idempotently add [contactId] to [spaceId]. UNIQUE(space_id, contact_id)
  /// makes a re-add a no-op (set-merge rule).
  Future<void> addContactToSpace({
    required String spaceId,
    required String contactId,
    String? id,
  }) {
    return into(spaceContacts).insert(
      SpaceContactsCompanion.insert(
        id: id ?? _mintEdgeId('sc', spaceId, contactId),
        spaceId: spaceId,
        contactId: contactId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Remove a single (space, contact) edge. EXPLICIT-ONLY removal.
  Future<int> removeContactFromSpace({
    required String spaceId,
    required String contactId,
  }) {
    return (delete(spaceContacts)..where(
          (e) => e.spaceId.equals(spaceId) & e.contactId.equals(contactId),
        ))
        .go();
  }

  /// The Contacts that are members of [spaceId], display-name ascending.
  Future<List<ContactRow>> listContactsForSpace(String spaceId) {
    final query =
        select(spaceContacts).join([
            innerJoin(contacts, contacts.id.equalsExp(spaceContacts.contactId)),
          ])
          ..where(spaceContacts.spaceId.equals(spaceId))
          ..orderBy([OrderingTerm.asc(contacts.displayName)]);
    return query.map((row) => row.readTable(contacts)).get();
  }

  // ---------------------------------------------------------------------------
  // item_contacts — the device-side DIRECT file↔contact edge.
  //
  // The source of truth for which contacts a file (recording) is about. Mirrors
  // The canonical `item_contacts` and the matome/space edge DAOs above: add is
  // idempotent (insertOrIgnore on UNIQUE(recording_id, contact_id)), removal is
  // EXPLICIT-ONLY (set-merge rule). Owner-scoping is the CALLER's contract — as
  // with every edge DAO here, callers pass ids of rows the session owner owns
  // (the Files view + Contact detail only ever resolve owned ids); Core enforces
  // both-endpoints owner-scoping server-side (Content.link_contact_to_recording).
  // ---------------------------------------------------------------------------

  /// Idempotently link [contactId] DIRECTLY to [recordingId]. UNIQUE
  /// (recording_id, contact_id) makes a re-add a no-op (set-merge rule).
  Future<void> linkContactToItem({
    required String itemId,
    required String contactId,
    String? id,
  }) {
    return into(itemContacts).insert(
      ItemContactsCompanion.insert(
        id: id ?? _mintEdgeId('ic', itemId, contactId),
        itemId: itemId,
        contactId: contactId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Remove a single (recording, contact) direct edge. EXPLICIT-ONLY removal.
  /// Returns rows deleted.
  Future<int> unlinkContactFromItem({
    required String itemId,
    required String contactId,
  }) {
    return (delete(itemContacts)..where(
          (e) => e.itemId.equals(itemId) & e.contactId.equals(contactId),
        ))
        .go();
  }

  /// The Contacts linked DIRECTLY to [itemId] (via `item_contacts`),
  /// display-name ascending.
  Future<List<ContactRow>> listContactsForFile(String itemId, String ownerId) {
    final query =
        select(itemContacts).join([
            innerJoin(contacts, contacts.id.equalsExp(itemContacts.contactId)),
            innerJoin(items, items.id.equalsExp(itemContacts.itemId)),
          ])
          ..where(
            itemContacts.itemId.equals(itemId) &
                items.ownerId.equals(ownerId) &
                contacts.ownerId.equals(ownerId),
          )
          ..orderBy([OrderingTerm.asc(contacts.displayName)]);
    return query.map((row) => row.readTable(contacts)).get();
  }

  /// The Files (recordings) linked DIRECTLY to [contactId] (via
  /// `item_contacts`), newest first.
  Future<List<ItemWithPayload>> listFilesForContact(
    String contactId,
    String ownerId,
  ) async {
    final edges = await (select(
      itemContacts,
    )..where((edge) => edge.contactId.equals(contactId))).get();
    final ids = edges.map((edge) => edge.itemId).toSet();
    if (ids.isEmpty) return const [];
    final rows = await attachedDatabase.itemsDao.listAll(ownerId);
    return rows
        .where((row) => ids.contains(row.id) && row.file != null)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Contact-side relationship reads (DR-004 / #1464 — the Contact detail view).
  // These mirror the matome/space-side reads above, but from the CONTACT end.
  // ---------------------------------------------------------------------------

  /// The Matomes that [contactId] is tagged in, each paired with the contact's
  /// `matome_contacts.role` on that Matome, newest happening first. Archived
  /// Matomes (`archived_at IS NOT NULL`) are excluded so the detail mirrors the
  /// active list surfaces.
  Future<List<ContactMatomeEntry>> listMatomesForContact(String contactId) {
    final query =
        select(matomeContacts).join([
            innerJoin(matomes, matomes.id.equalsExp(matomeContacts.matomeId)),
          ])
          ..where(
            matomeContacts.contactId.equals(contactId) &
                matomes.archivedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(matomes.happenedAt)]);
    return query.map((row) {
      return ContactMatomeEntry(
        matome: row.readTable(matomes),
        role: row.readTable(matomeContacts).role,
      );
    }).get();
  }

  /// The Spaces (workspaces) [contactId] is a member of (`space_contacts`),
  /// name-ascending.
  Future<List<WorkspaceRow>> listSpacesForContact(String contactId) {
    final query =
        select(spaceContacts).join([
            innerJoin(
              workspaces,
              workspaces.id.equalsExp(spaceContacts.spaceId),
            ),
          ])
          ..where(spaceContacts.contactId.equals(contactId))
          ..orderBy([OrderingTerm.asc(workspaces.name)]);
    return query.map((row) => row.readTable(workspaces)).get();
  }

  /// Files (recordings) reachable from [contactId] — MATOME-MEDIATED (#1461):
  /// there is NO direct contact↔file edge today, so this returns the recordings
  /// of every Matome the contact is tagged in (via `matome_contacts`), newest
  /// first, de-duplicated. Returns an empty list when the contact has no matomes
  /// (or those matomes have no recordings).
  Future<List<ItemWithPayload>> listFilesForContactViaMatomes(
    String contactId,
    String ownerId,
  ) async {
    final matomeRows = await listMatomesForContact(contactId);
    final matomeIds = matomeRows.map((e) => e.matome.id).toList();
    if (matomeIds.isEmpty) return const [];
    final rows = await attachedDatabase.itemsDao.listAll(ownerId);
    return rows
        .where(
          (row) => row.file != null && matomeIds.contains(row.item.matomeId),
        )
        .toList(growable: false);
  }

  /// Files reachable from [contactId] — the DIRECT edge (`item_contacts`,
  /// #1472) UNIONed with the MATOME-MEDIATED set (`listFilesForContactViaMatomes`,
  /// #1464), de-duplicated by recording id (direct wins on a tie), newest first.
  ///
  /// DR-003 decision: the direct edge is the source of truth, but the
  /// matome-mediated set is kept as an additional UNION so a file the contact is
  /// reachable from via its matome still surfaces. De-duplication by id means a
  /// file linked BOTH directly and via its matome is counted exactly once (no
  /// double-count). Returns newest-first.
  Future<List<ItemWithPayload>> listFilesForContactUnion(
    String contactId,
    String ownerId,
  ) async {
    final direct = await listFilesForContact(contactId, ownerId);
    final viaMatomes = await listFilesForContactViaMatomes(contactId, ownerId);

    final byId = <String, ItemWithPayload>{};
    for (final row in direct) {
      byId[row.id] = row;
    }
    for (final row in viaMatomes) {
      byId.putIfAbsent(row.id, () => row);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  // ---------------------------------------------------------------------------
  // matome_shares — RESERVED: share a Matome with a user. BEHAVIOUR deferred.
  // ---------------------------------------------------------------------------

  /// Record a share of [matomeId] with [sharedWithUserId] at [permission]
  /// (default 'read'). RESERVED — persists intent only; no sharing behaviour
  /// reads this today.
  Future<MatomeShareRow> addMatomeShare({
    required String matomeId,
    required String sharedWithUserId,
    String permission = 'read',
    String? id,
  }) async {
    final rowId = id ?? _mintEdgeId('ms', matomeId, sharedWithUserId);
    final companion = MatomeSharesCompanion.insert(
      id: rowId,
      matomeId: matomeId,
      sharedWithUserId: sharedWithUserId,
      permission: Value(permission),
    );
    await into(matomeShares).insert(companion);
    return MatomeShareRow(
      id: rowId,
      matomeId: matomeId,
      sharedWithUserId: sharedWithUserId,
      permission: permission,
    );
  }

  /// Remove a share edge by its id. Returns rows deleted.
  Future<int> removeMatomeShare(String id) {
    return (delete(matomeShares)..where((s) => s.id.equals(id))).go();
  }

  /// All share edges of [matomeId].
  Future<List<MatomeShareRow>> listSharesForMatome(String matomeId) {
    return (select(
      matomeShares,
    )..where((s) => s.matomeId.equals(matomeId))).get();
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------

  /// Deterministic edge id from its endpoints. The id is incidental — the
  /// (left,right) UNIQUE constraint is what enforces single-membership; deriving
  /// the id from the pair keeps a re-add stable rather than minting a fresh
  /// (constraint-violating) random id each time.
  String _mintEdgeId(String prefix, String left, String right) =>
      '${prefix}_${left}__$right';
}

/// A Contact paired with its `matome_contacts.role` for a given Matome.
class MatomeContactEntry {
  const MatomeContactEntry({required this.contact, required this.role});

  final ContactRow contact;
  final String role;
}

/// A Matome paired with a Contact's `matome_contacts.role` on it — the
/// contact-side of [MatomeContactEntry], used by the Contact detail view.
class ContactMatomeEntry {
  const ContactMatomeEntry({required this.matome, required this.role});

  final MatomeRow matome;
  final String role;
}
