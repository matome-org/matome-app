import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart'
    show PickedUpload;
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart'
    show kProcessingStatusPendingUpload;
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// #1449 — generic `addFile`: dynamic mediaType (NOT hardcoded image), the
/// original extension persisted on the row, the client-side size guard, and the
/// flag-off path left unchanged. These exercise the controller against a real
/// in-memory Drift DB; the durable copy is stubbed to identity so the test stays
/// off-disk and deterministic.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  ProviderContainer containerFor(String matomeId, {UploadQueue? uploadQueue}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        if (uploadQueue != null)
          uploadQueueProvider.overrideWithValue(uploadQueue),
        // Identity durable copy — keep the test off-disk; the real copy is
        // covered by matome_add_photo_e2e_test.
        matomeDetailControllerProvider.overrideWith(
          (ref, id) => MatomeDetailController(
            ref,
            id,
            durableCopy: (PickedUpload p) async => p,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(matomeDetailControllerProvider(matomeId), (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  Future<void> seedMatome(String id) => db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: const Value('Standup'),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );

  Future<void> seedSyncedMatome(String id, int coreId) => db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      coreId: Value(coreId),
      title: const Value('Synced standup'),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );

  /// A real temp file with the given extension and a tiny payload.
  File tempFile(String name, {int bytes = 8}) {
    final f = File(
      '${Directory.systemTemp.path}/addfile_${DateTime.now().microsecondsSinceEpoch}_$name',
    )..writeAsBytesSync(List<int>.filled(bytes, 0));
    addTearDown(() {
      if (f.existsSync()) f.deleteSync();
    });
    return f;
  }

  test('addFile of a .pdf stores mediaType=document (NOT image) and persists '
      'the original extension, enqueued for upload', () async {
    await seedMatome('m_pdf');
    final c = containerFor('m_pdf');
    final controller = c.read(matomeDetailControllerProvider('m_pdf').notifier);
    await controller.load();

    final pdf = tempFile('report.pdf');
    await controller.addFile(file: pdf, name: 'report.pdf');

    final matome = await db.matomesDao.getMatomeWithItems('m_pdf', '1');
    final item = matome!.recordings.single;
    // mediaType is derived, NOT the old hardcoded 'image'.
    expect(item.mediaType, 'document');

    final row = await db.itemsDao.getById(item.id, '1');
    expect(row!.originalExtension, 'pdf');
    expect(row.title, 'report');
    // Enqueued for upload (local-first pending_upload, no Core id yet).
    expect(row.processingStatus, kProcessingStatusPendingUpload);
    expect(row.coreId, isNull);
  });

  test(
    'W5: adding then removing a file leaves NO orphaned items/file_blobs rows '
    '(the dead file-item mirror was dropped)',
    () async {
      await seedSyncedMatome('m_items', 77);
      final c = containerFor('m_items');
      final controller = c.read(
        matomeDetailControllerProvider('m_items').notifier,
      );
      await controller.load();

      await controller.addFile(
        file: tempFile('report.pdf'),
        name: 'report.pdf',
      );

      final inserted = await db.itemsDao.listForMatome('m_items', '1');
      expect(inserted, hasLength(1));
      expect(inserted.single.file, isNotNull);
      expect(await db.select(db.fileBlobs).get(), hasLength(1));

      // Remove the file and confirm nothing is left behind anywhere.
      final rec = (await db.matomesDao.getMatomeWithItems(
        'm_items',
        '1',
      ))!.recordings.single;
      await controller.removeItem(rec.id);

      expect(
        (await db.matomesDao.getMatomeWithItems('m_items', '1'))!.recordings,
        isEmpty,
      );
      expect(await db.itemsDao.listForMatome('m_items', '1'), isEmpty);
      expect(await db.select(db.fileBlobs).get(), isEmpty);
    },
  );

  test(
    'addTextNote on an unreconciled Matome stays local and queues work',
    () async {
      await seedMatome('m_local'); // no coreId
      final c = containerFor('m_local', uploadQueue: _NoopUploadQueue());
      final controller = c.read(
        matomeDetailControllerProvider('m_local').notifier,
      );
      await controller.load();

      final itemId = await controller.addTextNote('a note with no home yet');

      final rows = await db.itemsDao.listForMatome('m_local', '1');
      expect(rows, hasLength(1));
      expect(rows.single.id, itemId);
      expect(rows.single.text?.body, 'a note with no home yet');
      expect(rows.single.coreId, isNull);
      expect(await db.workQueueDao.listAll(), hasLength(1));
    },
  );

  test('addFile of a .png still stores mediaType=image (derivation, not a doc '
      'override) with the extension persisted', () async {
    await seedMatome('m_png');
    final c = containerFor('m_png');
    final controller = c.read(matomeDetailControllerProvider('m_png').notifier);
    await controller.load();

    await controller.addFile(file: tempFile('shot.png'), name: 'shot.png');

    final item = (await db.matomesDao.getMatomeWithItems(
      'm_png',
      '1',
    ))!.recordings.single;
    expect(item.mediaType, 'image');
    final row = await db.itemsDao.getById(item.id, '1');
    expect(row!.originalExtension, 'png');
  });

  test(
    'addPhoto still works and routes through addFile (a .jpg → image)',
    () async {
      await seedMatome('m_photo');
      final c = containerFor('m_photo');
      final controller = c.read(
        matomeDetailControllerProvider('m_photo').notifier,
      );
      await controller.load();

      await controller.addPhoto(file: tempFile('pic.jpg'), name: 'pic.jpg');

      final item = (await db.matomesDao.getMatomeWithItems(
        'm_photo',
        '1',
      ))!.recordings.single;
      expect(item.mediaType, 'image');
    },
  );

  test('the size guard rejects a file over the 25 MB ceiling and persists '
      'NOTHING', () async {
    await seedMatome('m_big');
    final c = containerFor('m_big');
    final controller = c.read(matomeDetailControllerProvider('m_big').notifier);
    await controller.load();

    // One byte over the cap.
    final big = tempFile('huge.pdf', bytes: kMaxImportFileBytes + 1);

    await expectLater(
      controller.addFile(file: big, name: 'huge.pdf'),
      throwsA(isA<FileTooLargeException>()),
    );

    final matome = await db.matomesDao.getMatomeWithItems('m_big', '1');
    expect(
      matome!.recordings,
      isEmpty,
      reason: 'an oversize file must not create a row',
    );
  });

  test('a file exactly AT the ceiling is accepted (boundary)', () async {
    await seedMatome('m_edge');
    final c = containerFor('m_edge');
    final controller = c.read(
      matomeDetailControllerProvider('m_edge').notifier,
    );
    await controller.load();

    final atCap = tempFile('cap.pdf', bytes: kMaxImportFileBytes);
    await controller.addFile(file: atCap, name: 'cap.pdf');

    expect(
      (await db.matomesDao.getMatomeWithItems('m_edge', '1'))!.recordings,
      hasLength(1),
    );
  });

  test(
    'the list mix counts a document Item in documentCount (not absorbed)',
    () async {
      await seedMatome('m_mix');
      final c = containerFor('m_mix');
      final controller = c.read(
        matomeDetailControllerProvider('m_mix').notifier,
      );
      await controller.load();
      await controller.addFile(file: tempFile('a.pdf'), name: 'a.pdf');

      final inboxCards = await db.matomesDao.listInboxMatomeItems('1');
      final card = inboxCards.firstWhere((m) => m.id == 'm_mix');
      expect(card.documentCount, 1);
      expect(card.imageCount, 0);
      expect(card.audioCount, 0);
    },
  );

  // ---------------------------------------------------------------------------
  // Flag-off path: the documents feature flag defaults OFF (no dart-define in
  // tests). The "Add file" affordance is the ONLY thing gated — Add photo stays.
  // ---------------------------------------------------------------------------
  testWidgets('with the documents flag OFF (test default) the Add-file entry '
      'is absent from the Add-item menu while Add-photo is present', (
    tester,
  ) async {
    // Guard the premise: if someone builds the test suite with the flag ON this
    // assertion would be inverted, so pin the expectation to the actual const.
    expect(
      FeatureFlags.documents,
      isFalse,
      reason:
          'tests run without --dart-define, so the flag is its OFF '
          'default; the gated affordance must not render',
    );

    await seedSyncedMatome('m_flag', 7001);
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_flag'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Reveal the "Show more" detail where the Items section (and its actions)
    // live.
    final toggle = find.byKey(const ValueKey('matome-show-more'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // "Add item" opens the unified "Add anything" picker; its create actions
    // live behind the header "+". Open it.
    final addItem = find.byKey(const ValueKey('matome-add-item'));
    await tester.ensureVisible(addItem);
    await tester.tap(addItem);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-create-menu')));
    await tester.pumpAndSettle();

    // Add photo is unconditional; Add file is dropped when the documents flag
    // is OFF.
    expect(
      find.byKey(const ValueKey('relationship-action-photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('relationship-action-file')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('relationship-action-text-note')),
      findsOneWidget,
      reason: 'text notes are available once the Matome has a Core id',
    );
  });

  testWidgets('Text note action is available for local-only matomes', (
    tester,
  ) async {
    await seedMatome('m_local_text');
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_local_text'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('matome-show-more'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final addItem = find.byKey(const ValueKey('matome-add-item'));
    await tester.ensureVisible(addItem);
    await tester.tap(addItem);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-create-menu')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('relationship-action-text-note')),
      findsOneWidget,
      reason:
          'durable parent reconciliation allows text creation before Core ids exist',
    );
  });
}

class _NoopUploadQueue extends UploadQueue {
  _NoopUploadQueue() : super(_NullRef());

  @override
  Future<void> drainRow(String localId) async {}
}

class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No provider reads are expected');
}
