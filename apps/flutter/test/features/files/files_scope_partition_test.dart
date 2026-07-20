// W6 #1501 — the Files filter (All / Loose / In-space) partitions on the
// resolver-backed EFFECTIVE-space bit (plan #102, spec R1/R1.2): Loose ⟺
// effective space NULL, In-space ⟺ effective space non-null, with matome
// membership WINNING (R1.1). The partition reads `FileRow.effectiveInSpace`,
// which the DAO computed once via `EffectiveSpace.effectiveSpaceId` — NO inline
// recompute in the UI. This test drives `filesForOwner` (the real query/resolver
// path) and asserts each row lands in the right bucket.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/file_row.dart';

import '../../support/item_fixtures.dart';

const _owner = '1';

Future<void> _seedSpace(
  AppDatabase db,
  String id, {
  bool isLocal = false,
}) async {
  await db
      .into(db.workspaces)
      .insert(
        WorkspacesCompanion.insert(
          id: id,
          name: 'space-$id',
          createdAt: 1000,
          isLocal: Value(isLocal ? 1 : 0),
        ),
      );
}

Future<void> _seedMatome(AppDatabase db, String id, {String? spaceId}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      title: const Value('M'),
      happenedAt: const Value(1000),
      createdAt: const Value(1000),
    ),
  );
}

Future<String> _seedFile(
  AppDatabase db, {
  required String id,
  String? matomeId,
  String? workspaceId,
}) async {
  await insertTestFileItem(
    db,
    id: id,
    title: id,
    ownerId: _owner,
    matomeId: matomeId,
    workspaceId: workspaceId,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
  return id;
}

List<FileRow> _loose(List<FileRow> files) =>
    files.where((f) => f.loose).toList();
List<FileRow> _inSpace(List<FileRow> files) =>
    files.where((f) => f.effectiveInSpace).toList();

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'All / Loose / In-space partition on the resolver-backed effective space',
    () async {
      await _seedSpace(db, 'ws_cloud');
      await _seedSpace(db, 'ws_local', isLocal: true);
      await _seedMatome(db, 'mat_in_space', spaceId: 'ws_cloud');
      await _seedMatome(db, 'mat_draft', spaceId: null);

      // (a) loose: no matome, no space → effective NULL → Loose.
      final loose = await _seedFile(db, id: 'rec_loose');
      // (b) draft matome (no space), no direct space → effective NULL → Loose.
      final draft = await _seedFile(db, id: 'rec_draft', matomeId: 'mat_draft');
      // (c) directly filed into a space (no matome) → effective non-null → In-space.
      final filed = await _seedFile(
        db,
        id: 'rec_filed',
        workspaceId: 'ws_local',
      );
      // (d) in a matome that is in a space → effective non-null → In-space.
      final viaMatome = await _seedFile(
        db,
        id: 'rec_via_matome',
        matomeId: 'mat_in_space',
      );

      final files = await db.itemsDao.filesForOwner(_owner);
      expect(files, hasLength(4), reason: 'All shows every owned file');

      final looseIds = _loose(files).map((f) => f.id).toSet();
      final inSpaceIds = _inSpace(files).map((f) => f.id).toSet();

      expect(looseIds, {loose, draft}, reason: 'Loose ⟺ effective space NULL');
      expect(inSpaceIds, {
        filed,
        viaMatome,
      }, reason: 'In-space ⟺ effective space non-null');
      // The two partitions are disjoint and cover All (no double-count, no gap).
      expect(looseIds.intersection(inSpaceIds), isEmpty);
      expect(looseIds.union(inSpaceIds).length, files.length);
    },
  );

  test(
    'matome WINS (R1.1): the matome\'s space is authoritative — a row in a '
    'matome-with-a-space is In-space even when its own workspace_id is NULL',
    () async {
      await _seedSpace(db, 'ws_cloud');
      await _seedMatome(db, 'mat_in_space', spaceId: 'ws_cloud');

      // No direct workspace_id, but the matome IS in a space → effective non-null
      // because the resolver reads matome.space_id FIRST (matome wins, R1.1).
      final viaMatome = await _seedFile(
        db,
        id: 'rec_via_matome_only',
        matomeId: 'mat_in_space',
      );

      final files = await db.itemsDao.filesForOwner(_owner);
      final row = files.firstWhere((f) => f.id == viaMatome);
      expect(
        row.effectiveInSpace,
        isTrue,
        reason:
            'the matome\'s space resolves the effective space (matome WINS)',
      );
      expect(row.loose, isFalse);
    },
  );
}
