import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/spaces/spaces_controller.dart';

/// Unit tests for the Spaces controller (S5, #784): recording counts per space
/// (mirrors processes/spacesData), create adds, delete removes AND returns the
/// space's recordings to the Inbox (workspaceId NULL), mirroring
/// services/workspaceService.deleteWorkspace.

Future<void> _seedRecording(
  AppDatabase db, {
  required String id,
  String? workspaceId,
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: Value(id),
      title: Value('rec $id'),
      timestamp: const Value(''),
      duration: const Value(''),
      badge: const Value('Inbox'),
      isProcessing: const Value(0),
      audioFilePath: const Value(''),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      mediaType: const Value('audio'),
      processingStatus: const Value('done'),
      workspaceId: Value(workspaceId),
    ),
  );
}

ProviderContainer _container(AppDatabase db) {
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
}

Future<List<dynamic>> _awaitCards(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    final s = container.read(spacesControllerProvider);
    if (s.hasValue) return s.requireValue;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container.read(spacesControllerProvider).requireValue;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // The DB is seeded with the default "Pessoal" workspace (migration 002,
  // mirrored by AppDatabase.forTesting). It appears in the list like any other
  // workspace (mobile `getWorkspaces` returns it too) — tests account for it.
  const defaultName = 'Pessoal';

  test('lists spaces with per-space recording counts', () async {
    final work = await db.workspacesDao.createWorkspace('Work');
    final ideas = await db.workspacesDao.createWorkspace('Ideas');
    await _seedRecording(db, id: 'a', workspaceId: work.id);
    await _seedRecording(db, id: 'b', workspaceId: work.id);
    await _seedRecording(db, id: 'c', workspaceId: ideas.id);
    await _seedRecording(db, id: 'd'); // inbox — counted nowhere

    final container = _container(db);
    addTearDown(container.dispose);

    final cards = await _awaitCards(container);
    final byName = {for (final c in cards) c.name: c.count};
    expect(byName['Work'], 2);
    expect(byName['Ideas'], 1);
    expect(byName[defaultName], 0); // default workspace, no recordings
  });

  test('createSpace adds a space and it shows up in the list', () async {
    final container = _container(db);
    addTearDown(container.dispose);
    final controller = container.read(spacesControllerProvider.notifier);

    await controller.load();
    // Only the seeded default initially.
    expect((await _awaitCards(container)).map((c) => c.name), [defaultName]);

    await controller.createSpace('Engineering');
    final cards = await _awaitCards(container);
    expect(cards.map((c) => c.name), containsAll([defaultName, 'Engineering']));
    expect(cards.firstWhere((c) => c.name == 'Engineering').count, 0);
  });

  test('createSpace ignores a blank name', () async {
    final container = _container(db);
    addTearDown(container.dispose);
    final controller = container.read(spacesControllerProvider.notifier);

    await controller.createSpace('   ');
    // No new workspace added beyond the seeded default.
    expect((await _awaitCards(container)).map((c) => c.name), [defaultName]);
  });

  test('deleteSpace removes the space and returns its recordings to the Inbox',
      () async {
    final work = await db.workspacesDao.createWorkspace('Work');
    await _seedRecording(db, id: 'a', workspaceId: work.id);
    await _seedRecording(db, id: 'b', workspaceId: work.id);

    final container = _container(db);
    addTearDown(container.dispose);
    final controller = container.read(spacesControllerProvider.notifier);

    await controller.load();
    expect(
      (await _awaitCards(container)).firstWhere((c) => c.name == 'Work').count,
      2,
    );

    await controller.deleteSpace(work.id);

    // Space gone from the list (only the seeded default remains).
    expect(
      (await _awaitCards(container)).map((c) => c.name),
      isNot(contains('Work')),
    );
    expect(await db.workspacesDao.getWorkspaceById(work.id), isNull);

    // Recordings returned to the Inbox (workspaceId NULL).
    final inbox = await db.recordingsDao.getInboxRecordings();
    expect(inbox.map((r) => r.id), containsAll(<String>['a', 'b']));
    for (final r in inbox) {
      expect(r.workspaceId, isNull);
    }
  });
}
