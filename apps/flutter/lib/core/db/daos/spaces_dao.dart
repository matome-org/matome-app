import 'dart:math';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'spaces_dao.g.dart';

/// Canonical id of the seeded default personal Space (the default triage
/// destination — .docs/internal/architecture.md §11 (D4)). Kept in sync with `_seedDefaultWorkspace`.
const String kDefaultPersonalSpaceId = 'ws_default_personal';

/// DAO for the **Space** collaboration schema landed by m006 (.docs/internal/architecture.md §11 (D3)/(D4)).
///
/// The physical table is still `workspaces` (the rename is logical); this DAO
/// exposes the new `space_type`/`owner_id` reads plus reserved CRUD stubs for
/// [SpaceMembers] and [Organizations].
///
/// SCHEMA-READY, NOT ENFORCED: none of these methods apply ACL/permission
/// logic. They exercise the schema so the `matome-collaboration` plan can build
/// behaviour on top later. Do not gate any access on them today.
@DriftAccessor(tables: [Workspaces, SpaceMembers, Organizations])
class SpacesDao extends DatabaseAccessor<AppDatabase> with _$SpacesDaoMixin {
  SpacesDao(super.db);

  static final _rng = Random();

  String _mintId(String prefix) {
    final epoch = DateTime.now().millisecondsSinceEpoch;
    final suffix = _rng.nextInt(1 << 30).toRadixString(36);
    return '${prefix}_${epoch}_$suffix';
  }

  // ---------------------------------------------------------------------------
  // Space (workspaces) reads for the new m006 columns.
  // ---------------------------------------------------------------------------

  /// The `space_type` ∈ { personal | shared | org } of a Space, or null when
  /// the Space does not exist.
  Future<String?> getSpaceType(String spaceId) async {
    final row = await (select(workspaces)..where((w) => w.id.equals(spaceId)))
        .getSingleOrNull();
    return row?.spaceType;
  }

  /// The reserved (unenforced) `owner_id` of a Space, or null when unset or the
  /// Space does not exist.
  Future<String?> getOwnerId(String spaceId) async {
    final row = await (select(workspaces)..where((w) => w.id.equals(spaceId)))
        .getSingleOrNull();
    return row?.ownerId;
  }

  /// Ensures the seeded default personal Space exists and is typed 'personal'
  /// (the default triage destination — .docs/internal/architecture.md §11 (D4)). Idempotent: inserts the row
  /// if missing, otherwise normalises its `space_type` to 'personal'. Returns
  /// the (now-guaranteed) row.
  Future<WorkspaceRow> ensureDefaultPersonalSpace() async {
    await into(workspaces).insert(
      WorkspacesCompanion.insert(
        id: kDefaultPersonalSpaceId,
        name: 'Pessoal',
        isDefault: const Value(1),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        spaceType: const Value('personal'),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await (update(workspaces)
          ..where((w) => w.id.equals(kDefaultPersonalSpaceId)))
        .write(const WorkspacesCompanion(spaceType: Value('personal')));
    return (select(workspaces)
          ..where((w) => w.id.equals(kDefaultPersonalSpaceId)))
        .getSingle();
  }

  // ---------------------------------------------------------------------------
  // space_members — reserved CRUD stubs (UNENFORCED RBAC).
  // role ∈ { owner | admin | member | viewer }.
  // ---------------------------------------------------------------------------

  /// Adds a membership edge. Reserved/unenforced — does NOT grant access.
  Future<SpaceMemberRow> addSpaceMember({
    required String spaceId,
    required String userId,
    String role = 'member',
    String? id,
  }) async {
    final rowId = id ?? _mintId('sm');
    final companion = SpaceMembersCompanion.insert(
      id: rowId,
      spaceId: spaceId,
      userId: userId,
      role: Value(role),
    );
    await into(spaceMembers).insert(companion);
    return SpaceMemberRow(
      id: rowId,
      spaceId: spaceId,
      userId: userId,
      role: role,
    );
  }

  /// All membership rows of a Space.
  Future<List<SpaceMemberRow>> membersOfSpace(String spaceId) {
    return (select(spaceMembers)..where((m) => m.spaceId.equals(spaceId)))
        .get();
  }

  /// Removes a single membership edge by its id.
  Future<void> removeSpaceMember(String id) {
    return (delete(spaceMembers)..where((m) => m.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // organizations — reserved CRUD stubs (multi-tenant, UNENFORCED).
  // ---------------------------------------------------------------------------

  /// Creates an organization. Reserved — no org-owned-Space behaviour today.
  Future<OrganizationRow> createOrganization(String name, {String? id}) async {
    final rowId = id ?? _mintId('org');
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    await into(organizations).insert(
      OrganizationsCompanion.insert(
        id: rowId,
        name: name,
        createdAt: createdAt,
      ),
    );
    return OrganizationRow(id: rowId, name: name, createdAt: createdAt);
  }

  Future<OrganizationRow?> getOrganizationById(String id) {
    return (select(organizations)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<OrganizationRow>> getOrganizations() {
    return (select(organizations)
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
        .get();
  }

  Future<void> deleteOrganization(String id) {
    return (delete(organizations)..where((o) => o.id.equals(id))).go();
  }
}
