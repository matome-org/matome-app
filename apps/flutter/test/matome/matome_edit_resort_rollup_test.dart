import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/matome/matome_sync_service.dart';

import 'matome_sync_service_test.dart' show FakeMatomesRepository;
import '../support/item_fixtures.dart';

/// Regression guard for #1411 / W5: editing a Matome's `happened_at` must
/// re-sort the list (newest-first by happenedAt) AND must NOT corrupt its
/// `syncRollup`. The rollup is derived from the child Items' on-cloud state and
/// the Matome's own coreId — never from `happened_at` — so a re-date moves the
/// row in the ordering while leaving the sync pill exactly where it was.

Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  required DateTime happenedAt,
  int? coreId,
}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: Value('Matome $id'),
      coreId: Value(coreId),
      happenedAt: Value(happenedAt.millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 1).millisecondsSinceEpoch),
    ),
  );
}

/// Seed a reconciled (coreId set), uploaded child so the parent Matome rolls up
/// to `cloud` — a non-trivial rollup that the re-date must leave untouched.
Future<void> _seedCloudChild(
  AppDatabase db, {
  required String id,
  required String matomeId,
  required int coreId,
}) async {
  await insertTestFileItem(
    db,
    id: id,
    title: 'Child $id',
    localPath: '/tmp/$id.m4a',
    createdAt: DateTime(2026, 6, 1).millisecondsSinceEpoch,
    coreId: coreId,
    matomeId: matomeId,
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('editing happenedAt re-sorts the list newest-first AND leaves syncRollup '
      'unchanged for the edited matome', () async {
    // Two matomes: "older" happened on the 1st, "newer" on the 10th.
    // "older" is fully synced (cloud child) so its rollup is `cloud`.
    await _seedMatome(
      db,
      id: 'older',
      happenedAt: DateTime(2026, 6, 1),
      coreId: 100,
    );
    await _seedMatome(
      db,
      id: 'newer',
      happenedAt: DateTime(2026, 6, 10),
      coreId: 200,
    );
    await _seedCloudChild(db, id: 'rec_older', matomeId: 'older', coreId: 7);
    await _seedCloudChild(db, id: 'rec_newer', matomeId: 'newer', coreId: 8);

    // BEFORE: list is [newer, older] (newest-first by happenedAt).
    final before = await db.matomesDao.listMatomes();
    expect(before.map((m) => m.id).toList(), ['newer', 'older']);

    // The edited matome's rollup BEFORE the edit (cloud — its child is synced).
    final olderBefore = await db.matomesDao.getMatomeWithItems('older', '1');
    expect(olderBefore!.syncRollup, MatomeSyncRollup.cloud);

    // Edit "older" to happen on the 20th — now the newest. Local-first edit via
    // the real sync service (inbox/local path: a fake repo absorbs the leg).
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        matomesRepositoryProvider.overrideWithValue(FakeMatomesRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(matomeSyncServiceProvider)
        .editMatome('older', happenedAt: DateTime(2026, 6, 20));

    // AFTER (re-sort): "older" moved to the front — list is [older, newer].
    final after = await db.matomesDao.listMatomes();
    expect(after.map((m) => m.id).toList(), ['older', 'newer']);

    // AFTER (rollup stability): the edited matome's syncRollup is UNCHANGED —
    // the re-date touched only happened_at, not the cloud/coreId state.
    final olderAfter = await db.matomesDao.getMatomeWithItems('older', '1');
    expect(olderAfter!.syncRollup, MatomeSyncRollup.cloud);
    expect(
      olderAfter.coreId,
      100,
    ); // coreId preserved (no PK/rollup corruption)
    expect(DateTime.fromMillisecondsSinceEpoch(olderAfter.happenedAt).day, 20);
  });
}
