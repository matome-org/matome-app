import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/files/files_providers.dart';

import '../../support/item_fixtures.dart';

// ---------------------------------------------------------------------------
// filesForCurrentOwnerProvider — proves the provider returns the CURRENT
// owner's files (across matomes + unfiled) and never another owner's, and that
// a signed-out container (null owner) returns empty rather than the whole table
// (Omakiten #1461).
// ---------------------------------------------------------------------------

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seed(AppDatabase db) async {
  await db.matomesDao.create(
    MatomesCompanion.insert(
      id: 'm_a',
      title: 'A matome',
      happenedAt: 1000,
      createdAt: 1000,
    ),
  );
  // owner A: filed + unfiled. owner B: one file that must never leak.
  await insertTestFileItem(
    db,
    id: 'a_filed',
    title: 'A filed',
    createdAt: 100,
    ownerId: '1',
    matomeId: 'm_a',
  );
  await insertTestFileItem(
    db,
    id: 'a_loose',
    title: 'A loose',
    createdAt: 200,
    ownerId: '1',
  );
  await insertTestFileItem(
    db,
    id: 'b_loose',
    title: 'B loose',
    createdAt: 300,
    ownerId: '2',
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = _memDb());
  tearDown(() => db.close());

  ProviderContainer containerFor(String? ownerId) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue(ownerId),
      ],
    );
  }

  test('returns the current owner files across matomes + unfiled', () async {
    await _seed(db);
    final container = containerFor('1');
    addTearDown(container.dispose);

    final files = await container.read(filesForCurrentOwnerProvider.future);

    expect(files.map((f) => f.id), ['a_loose', 'a_filed']); // newest first
    expect(files.any((f) => f.id == 'b_loose'), isFalse); // B never leaks
  });

  test('signed out (null owner) returns empty, not the whole table', () async {
    await _seed(db);
    final container = containerFor(null);
    addTearDown(container.dispose);

    final files = await container.read(filesForCurrentOwnerProvider.future);

    expect(files, isEmpty);
  });
}
