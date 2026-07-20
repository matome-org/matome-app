import 'dart:math';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'workspaces_dao.g.dart';

/// DAO for `workspaces`, porting workspaceService.ts.
@DriftAccessor(tables: [Workspaces, Items, Matomes])
class WorkspacesDao extends DatabaseAccessor<AppDatabase>
    with _$WorkspacesDaoMixin {
  WorkspacesDao(super.db);

  static final _rng = Random();

  /// All workspaces, oldest first. Mirrors `getWorkspaces`.
  Future<List<WorkspaceRow>> getWorkspaces() {
    return (select(
      workspaces,
    )..orderBy([(w) => OrderingTerm.asc(w.createdAt)])).get();
  }

  Future<WorkspaceRow?> getWorkspaceById(String id) {
    return (select(
      workspaces,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  /// Create a non-default workspace with a generated id. Mirrors
  /// `createWorkspace` (`ws_<epoch>_<rand>`, isDefault 0).
  Future<WorkspaceRow> createWorkspace(String name) async {
    final trimmed = name.trim();
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final suffix = _rng.nextInt(1 << 30).toRadixString(36);
    final id = 'ws_${createdAt}_$suffix';

    final companion = WorkspacesCompanion.insert(
      id: id,
      name: trimmed,
      isDefault: const Value(0),
      createdAt: createdAt,
    );
    await into(workspaces).insert(companion);

    // Read back so the returned row reflects column defaults (e.g. m006's
    // `space_type` 'personal' / `owner_id` NULL) without re-hardcoding them.
    return (select(workspaces)..where((w) => w.id.equals(id))).getSingle();
  }

  /// Re-key a LOCAL space to its newly-minted Core numeric id and flip it to
  /// CLOUD, atomically re-pointing every item that referenced the old id (plan
  /// #102 W4 / #1499, spec R3.4).
  ///
  /// Local spaces use a `ws_<...>` id with no Core counterpart; a CLOUD space's
  /// local id IS the stringified Core numeric id (the `coreWorkspaceIdToLocal`
  /// convention) so the existing space-scoped sync (`int.tryParse(spaceId)`)
  /// can push its items. Promotion therefore RE-KEYS the row: it inserts a
  /// cloud row at `newId` (carrying the old row's name/owner/type), re-points
  /// the matomes (`space_id`) and directly-filed recordings (`workspace_id`)
  /// from [oldId] to [newId], then drops the old `ws_<...>` row — all in ONE
  /// transaction so an item is never momentarily orphaned and the flip is
  /// atomic (the state machine's `promoting → cloud` boundary).
  ///
  /// IDEMPOTENT: if [oldId] no longer exists (the re-key already committed on a
  /// prior attempt) this is a no-op, so a crashed/retried promotion does not
  /// duplicate the row or re-point twice. Returns true when it performed the
  /// re-key, false when it was already done.
  Future<bool> promoteToCloud({required String oldId, required String newId}) {
    return transaction(() async {
      final old = await (select(
        workspaces,
      )..where((w) => w.id.equals(oldId))).getSingleOrNull();
      if (old == null) return false; // already promoted — idempotent no-op.

      // Drop the old local row FIRST so the cloud row can reuse its UNIQUE name
      // (`workspaces.name` is unique). The child rows still carry the old
      // `ws_<...>` id string here; they are re-pointed below. (SQLite checks an
      // FK on the CHILD write, not on a parent delete, so dropping the parent
      // before re-pointing is safe within this single transaction.)
      await (delete(workspaces)..where((w) => w.id.equals(oldId))).go();

      // Insert the cloud-labelled row at the Core numeric id, preserving the
      // user-facing identity (name/type/owner). is_local = 0 ⇒ CLOUD.
      await into(workspaces).insert(
        WorkspacesCompanion.insert(
          id: newId,
          name: old.name,
          isDefault: Value(old.isDefault),
          createdAt: old.createdAt,
          spaceType: Value(old.spaceType),
          ownerId: Value(old.ownerId),
          isLocal: const Value(0),
        ),
      );

      // Re-point every item from the old id to the new cloud id. Matomes via
      // `space_id`, directly-filed recordings via `workspace_id`. The FK is now
      // satisfied by the new row inserted above.
      await (update(matomes)..where((m) => m.spaceId.equals(oldId))).write(
        MatomesCompanion(spaceId: Value(newId)),
      );
      await (update(
        items,
      )..where((item) => item.workspaceId.equals(oldId))).write(
        ItemsCompanion(workspaceId: Value(newId), isDirty: const Value(true)),
      );
      return true;
    });
  }

  /// Delete a workspace. Its recordings are returned to the Inbox
  /// (`workspaceId = NULL`) first, then the workspace row is removed. Mirrors
  /// `deleteWorkspace`. Wrapped in a transaction so the two writes are atomic.
  Future<void> deleteWorkspace(String id) {
    return transaction(() async {
      await (update(items)..where((item) => item.workspaceId.equals(id))).write(
        const ItemsCompanion(workspaceId: Value(null), isDirty: Value(true)),
      );
      await (delete(workspaces)..where((w) => w.id.equals(id))).go();
    });
  }
}
