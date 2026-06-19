import 'dart:math';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'workspaces_dao.g.dart';

/// DAO for `workspaces`, porting workspaceService.ts.
@DriftAccessor(tables: [Workspaces, Recordings])
class WorkspacesDao extends DatabaseAccessor<AppDatabase>
    with _$WorkspacesDaoMixin {
  WorkspacesDao(super.db);

  static final _rng = Random();

  /// All workspaces, oldest first. Mirrors `getWorkspaces`.
  Future<List<WorkspaceRow>> getWorkspaces() {
    return (select(workspaces)
          ..orderBy([(w) => OrderingTerm.asc(w.createdAt)]))
        .get();
  }

  Future<WorkspaceRow?> getWorkspaceById(String id) {
    return (select(workspaces)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
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

  /// Delete a workspace. Its recordings are returned to the Inbox
  /// (`workspaceId = NULL`) first, then the workspace row is removed. Mirrors
  /// `deleteWorkspace`. Wrapped in a transaction so the two writes are atomic.
  Future<void> deleteWorkspace(String id) {
    return transaction(() async {
      await (update(recordings)..where((r) => r.workspaceId.equals(id)))
          .write(const RecordingsCompanion(workspaceId: Value(null)));
      await (delete(workspaces)..where((w) => w.id.equals(id))).go();
    });
  }
}
