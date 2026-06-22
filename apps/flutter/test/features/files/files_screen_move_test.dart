import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/files/files_screen.dart';
import 'package:matome_flutter/features/files/widgets/files_view_shared.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

// ---------------------------------------------------------------------------
// Files view — move-to-matome interaction tests (#1473). Per Maes: real
// interaction/widget tests (open the picker, tap a target, assert the DB +
// provider reflect it, Undo restores), not goldens. The owner is overridden via
// [currentOwnerIdProvider] so the owner-scoped query/picker resolve in-test.
// ---------------------------------------------------------------------------

const String _owner = '1';
const String _otherOwner = '2';

Widget _app(AppDatabase db, {String? owner = _owner}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentOwnerIdProvider.overrideWithValue(owner),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const FilesScreen(),
      ),
    ),
  );
}

MatomesCompanion _matome({required String id, required String title}) =>
    MatomesCompanion.insert(
      id: id,
      title: title,
      happenedAt: 1000,
      createdAt: 1000,
    );

RecordingsCompanion _rec({
  required String id,
  required String ownerId,
  String title = 'File',
  String? matomeId,
  int createdAt = 1000,
}) =>
    RecordingsCompanion.insert(
      id: id,
      title: title,
      timestamp: '9:00 AM',
      duration: '0:30',
      audioFilePath: '/tmp/$id.m4a',
      createdAt: createdAt,
      ownerId: Value(ownerId),
      matomeId: Value(matomeId),
      mediaType: const Value('audio'),
      processingStatus: const Value('done'),
    );

/// Select a table row by tapping its checkbox. The whole row is a
/// [GestureDetector]; walking up from the file name to that detector and back
/// down to the (single) row [Checkbox] is stable across layout tweaks and does
/// not collide with the header checkbox.
Future<void> _selectRow(WidgetTester tester, String fileName) async {
  final rowDetector = find
      .ancestor(
        of: find.text(fileName),
        matching: find.byType(GestureDetector),
      )
      .first;
  final checkbox =
      find.descendant(of: rowDetector, matching: find.byType(Checkbox));
  await tester.tap(checkbox.first);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets(
      'bulk move: select files → picker → reassignment persists; Undo restores',
      (tester) async {
    await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
    await db.matomesDao.create(_matome(id: 'm_dst', title: 'Dest'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r1', ownerId: _owner, title: 'Alpha', matomeId: 'm_src'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r2', ownerId: _owner, title: 'Beta', matomeId: 'm_src', createdAt: 900));
    // Dest already holds an owner file so it is a picker target (the picker
    // lists matomes the owner has recordings in — owner-scoped, #1473).
    await db.recordingsDao
        .insertRecording(_rec(id: 'seed_dst', ownerId: _owner, title: 'Gamma', matomeId: 'm_dst', createdAt: 800));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Switch to the table view (deterministic checkbox-per-row selection).
    await tester.tap(find.byKey(const ValueKey('files-view-table')));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await _selectRow(tester, 'Beta');

    // Bulk bar visible → tap Move.
    expect(find.byKey(const ValueKey('files-bulk-bar')), findsOneWidget);
    await tester.tap(find.text(t.files.moveToMatome).first);
    await tester.pumpAndSettle();

    // Picker is open (its Unfiled tile is unique) → pick Dest.
    expect(
        find.byKey(const ValueKey('files-move-target-unfiled')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('files-move-target-m_dst')));
    await tester.pumpAndSettle();

    // Persisted: both files now in Dest.
    var files = await db.recordingsDao.filesForOwner(_owner);
    expect(files.firstWhere((f) => f.id == 'r1').matome, 'Dest');
    expect(files.firstWhere((f) => f.id == 'r2').matome, 'Dest');

    // Undo restores prior matome.
    expect(find.text(t.files.movedMsg(n: 2)), findsOneWidget);
    await tester.tap(find.text(t.files.undo));
    await tester.pumpAndSettle();

    files = await db.recordingsDao.filesForOwner(_owner);
    expect(files.firstWhere((f) => f.id == 'r1').matome, 'Source');
    expect(files.firstWhere((f) => f.id == 'r2').matome, 'Source');
  });

  testWidgets('per-row move: overflow menu → picker → reassigns one file',
      (tester) async {
    await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
    await db.matomesDao.create(_matome(id: 'm_dst', title: 'Dest'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r1', ownerId: _owner, title: 'Alpha', matomeId: 'm_src'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'seed_dst', ownerId: _owner, title: 'Gamma', matomeId: 'm_dst', createdAt: 800));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('files-view-table')));
    await tester.pumpAndSettle();

    // Open the Alpha row overflow menu, then Move to matome.
    final alphaRow = find
        .ancestor(of: find.text('Alpha'), matching: find.byType(GestureDetector))
        .first;
    await tester.tap(
        find.descendant(of: alphaRow, matching: find.byIcon(Icons.more_horiz)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.files.moveToMatome).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('files-move-target-m_dst')));
    await tester.pumpAndSettle();

    final files = await db.recordingsDao.filesForOwner(_owner);
    expect(files.firstWhere((f) => f.id == 'r1').matome, 'Dest');
  });

  testWidgets('move to Unfiled clears the matome', (tester) async {
    await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r1', ownerId: _owner, title: 'Alpha', matomeId: 'm_src'));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('files-view-table')));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await tester.tap(find.text(t.files.moveToMatome).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('files-move-target-unfiled')));
    await tester.pumpAndSettle();

    final files = await db.recordingsDao.filesForOwner(_owner);
    expect(files.single.unfiled, isTrue);
  });

  testWidgets('cross-owner: picker offers ONLY the owner matomes', (tester) async {
    // Owner 1 owns a file in m_a; owner 2 owns one in m_b. The picker for owner 1
    // must list m_a (and Unfiled) but NOT m_b — a cross-owner target.
    await db.matomesDao.create(_matome(id: 'm_a', title: 'Mine'));
    await db.matomesDao.create(_matome(id: 'm_b', title: 'Theirs'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r1', ownerId: _owner, title: 'Alpha', matomeId: 'm_a'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r2', ownerId: _otherOwner, title: 'Beta', matomeId: 'm_b'));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('files-view-table')));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await tester.tap(find.text(t.files.moveToMatome).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('files-move-target-m_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('files-move-target-m_b')), findsNothing);
    expect(find.text('Theirs'), findsNothing);
  });

  testWidgets('download remains the unchanged stub (not available notice)',
      (tester) async {
    await db.matomesDao.create(_matome(id: 'm1', title: 'M1'));
    await db.recordingsDao
        .insertRecording(_rec(id: 'r1', ownerId: _owner, title: 'Alpha', matomeId: 'm1'));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('files-view-table')));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await tester.tap(find.text(t.files.download).first);
    await tester.pumpAndSettle();

    // Still the stub: surfaces the "not available" notice, no DB mutation.
    expect(find.text(t.files.downloadUnavailable), findsOneWidget);
    final files = await db.recordingsDao.filesForOwner(_owner);
    expect(files.single.matome, 'M1'); // unchanged
  });

  testWidgets('FileAction enum still exposes the download stub action',
      (tester) async {
    // Belt-and-suspenders: the download affordance is still wired (not removed).
    expect(FileAction.values, contains(FileAction.download));
  });
}
