import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/spaces_dao.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';

/// Triage flow tests (#1372): file an Inbox Matome into a Space, default target
/// is the personal Space, notes edits persist, and importing a photo adds an
/// image Item under the Matome.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seedInboxMatome(String id, {String title = 'Standup'}) {
    return db.matomesDao.create(
      MatomesCompanion(
        id: Value(id),
        spaceId: const Value(null),
        title: Value(title),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );
  }

  ProviderContainer container({bool stubDurableCopy = false}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        if (stubDurableCopy)
          // path_provider has no platform channel under flutter test, so the
          // photo import injects a no-op durable copy that returns the file
          // unchanged (mirrors the WEB cloud-direct path).
          matomeDetailControllerProvider.overrideWith(
            (ref, id) => MatomeDetailController(
              ref,
              id,
              durableCopy: (picked) async => picked,
            ),
          ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  MatomeDetailController controllerFor(ProviderContainer c, String id) =>
      c.read(matomeDetailControllerProvider(id).notifier);

  test('filing an inbox matome into a space sets its spaceId and it leaves '
      'the inbox list', () async {
    await seedInboxMatome('m1');
    final c = container();
    final personal = await c
        .read(spacesDaoProvider)
        .ensureDefaultPersonalSpace();
    final space = await c.read(workspacesDaoProvider).createWorkspace('Work');

    // Sanity: starts in the inbox.
    final inboxBefore = await db.matomesDao.listInboxMatomes();
    expect(inboxBefore.map((m) => m.id), contains('m1'));

    final controller = controllerFor(c, 'm1');
    await controller.fileIntoSpace(space.id);

    final row = await db.matomesDao.getById('m1');
    expect(row!.spaceId, space.id);

    // Left the inbox.
    final inboxAfter = await db.matomesDao.listInboxMatomes();
    expect(inboxAfter.map((m) => m.id), isNot(contains('m1')));
    // And is listed under its new Space (not the personal one).
    final inSpace = await db.matomesDao.listMatomesInSpace(space.id);
    expect(inSpace.map((m) => m.id), contains('m1'));
    expect(personal.id, isNot(space.id));
  });

  test('default file target is the personal space (ordered first, flagged '
      'default)', () async {
    await seedInboxMatome('m2');
    final c = container();
    // A non-personal space exists too, to prove ordering.
    await c.read(workspacesDaoProvider).createWorkspace('Work');

    final controller = controllerFor(c, 'm2');
    await controller.load();

    final spaces = c.read(matomeDetailControllerProvider('m2')).spaces;
    expect(spaces, isNotEmpty);
    // The default personal space is the first (most-prominent) option.
    expect(spaces.first.id, kDefaultPersonalSpaceId);

    // Filing into the default personal space sets spaceId accordingly.
    await controller.fileIntoSpace(kDefaultPersonalSpaceId);
    final row = await db.matomesDao.getById('m2');
    expect(row!.spaceId, kDefaultPersonalSpaceId);
    expect(await db.matomesDao.listInboxMatomes(), isEmpty);
  });

  test('notes edit persists (and marks the summary stale on change)', () async {
    await seedInboxMatome('m3');
    // Seed a non-stale summary so we can observe it flipping stale.
    await db.matomesDao.setAggregatedSummary('m3', 'Existing summary');

    final c = container();
    final controller = controllerFor(c, 'm3');
    await controller.load();

    await controller.saveNotes('Follow up with design about the new flow.');

    final row = await db.matomesDao.getById('m3');
    expect(row!.description, 'Follow up with design about the new flow.');
    expect(row.summaryStale, isTrue);

    // Clearing the notes persists null.
    await controller.saveNotes('   ');
    final cleared = await db.matomesDao.getById('m3');
    expect(cleared!.description, isNull);
  });

  test('importing a photo adds an image Item under the matome and keeps its '
      'triage state', () async {
    await seedInboxMatome('m4');
    final c = container(stubDurableCopy: true);
    final controller = controllerFor(c, 'm4');
    await controller.load();

    // A throwaway image file for the import (durable copy is stubbed no-op).
    final tmp = File(
      '${Directory.systemTemp.path}/matome_photo_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47]);
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync();
    });

    await controller.addPhoto(file: tmp, name: 'whiteboard.png');

    final matome = await db.matomesDao.getMatomeWithItems('m4', '1');
    expect(matome!.recordings, hasLength(1));
    final item = matome.recordings.single;
    expect(item.mediaType, 'image');
    expect(item.title, 'whiteboard');

    // The controller STATE (what the hub watches) must reflect the new photo —
    // addPhoto reloads after persisting, so the user actually sees it. Guards
    // the "added a photo but don't see it" regression.
    expect(
      controller.state.matome?.recordings,
      hasLength(1),
      reason: 'hub state refreshes to show the imported photo',
    );

    // The photo Item is an Item of THIS matome.
    final row = await db.itemsDao.getById(item.id, '1');
    expect(row!.matomeId, 'm4');

    // Triage state untouched — still an Inbox Matome.
    expect(matome.spaceId, isNull);
    expect(matome.isInbox, isTrue);
    expect(await db.matomesDao.listInboxMatomes(), hasLength(1));
  });

  test('removing an item deletes its row, its on-device file, marks the '
      'summary stale and refreshes the hub state', () async {
    await seedInboxMatome('m5');
    final c = container(stubDurableCopy: true);
    // Pin the autoDispose provider so reading `controller.state` after the
    // remove's async gaps (DB delete + file delete + reload) is safe — without
    // a listener it would be disposed out from under us.
    final sub = c.listen(matomeDetailControllerProvider('m5'), (_, _) {});
    addTearDown(sub.close);
    final controller = controllerFor(c, 'm5');
    await controller.load();

    // Import a real throwaway file so we can assert it is deleted on remove.
    final tmp = File(
      '${Directory.systemTemp.path}/matome_rm_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47]);
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync();
    });
    await controller.addPhoto(file: tmp, name: 'whiteboard.png');

    final item = (await db.matomesDao.getMatomeWithItems(
      'm5',
      '1',
    ))!.recordings.single;
    expect(tmp.existsSync(), isTrue);

    await controller.removeItem(item.id, filePath: tmp.path);

    // Row gone, on-device file deleted, summary marked stale, hub refreshed.
    expect(await db.itemsDao.getById(item.id, '1'), isNull);
    expect(tmp.existsSync(), isFalse);
    expect((await db.matomesDao.getById('m5'))!.summaryStale, isTrue);
    expect(controller.state.matome?.recordings, isEmpty);
  });
}
