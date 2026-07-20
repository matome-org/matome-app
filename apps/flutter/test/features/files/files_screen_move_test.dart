import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/core/vault/vault_export_service.dart';
import 'package:matome_flutter/features/files/files_screen.dart';
import 'package:matome_flutter/features/files/widgets/files_grid.dart';
import 'package:matome_flutter/features/files/widgets/files_table.dart';
import 'package:matome_flutter/features/files/widgets/files_view_shared.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import '../../support/item_fixtures.dart';
import '../../support/fake_media_blob_store.dart';

// ---------------------------------------------------------------------------
// Files view — move-to-matome interaction tests (#1473). Per Maes: real
// interaction/widget tests (open the picker, tap a target, assert the DB +
// provider reflect it, Undo restores), not goldens. The owner is overridden via
// [currentOwnerIdProvider] so the owner-scoped query/picker resolve in-test.
// ---------------------------------------------------------------------------

const String _owner = '1';
const String _otherOwner = '2';

/// The on-screen grid↔table toggle was removed (#1474) — Settings is the single
/// control. Tests that need a specific layout seed the persisted preference via
/// the [SettingsStore] so the screen comes up already showing that view. The
/// move/selection tests default to the table (deterministic checkbox-per-row).
Widget _app(
  AppDatabase db, {
  String? owner = _owner,
  String view = 'table',
  VaultExportService? exporter,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentOwnerIdProvider.overrideWithValue(owner),
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore({'matome.files_view': view}),
      ),
      if (exporter != null)
        vaultExportServiceProvider.overrideWithValue(exporter),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildLightTheme(), home: const FilesScreen()),
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

Future<void> _seedFile(
  AppDatabase db, {
  required String id,
  required String ownerId,
  String title = 'File',
  String? matomeId,
  int createdAt = 1000,
}) => insertTestFileItem(
  db,
  id: id,
  ownerId: ownerId,
  title: title,
  matomeId: matomeId,
  createdAt: createdAt,
);

/// Select a table row by tapping its checkbox. The whole row is a
/// [GestureDetector]; walking up from the file name to that detector and back
/// down to the (single) row [Checkbox] is stable across layout tweaks and does
/// not collide with the header checkbox.
Future<void> _selectRow(WidgetTester tester, String fileName) async {
  final rowDetector = find
      .ancestor(of: find.text(fileName), matching: find.byType(GestureDetector))
      .first;
  final checkbox = find.descendant(
    of: rowDetector,
    matching: find.byType(Checkbox),
  );
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
      await _seedFile(
        db,
        id: 'r1',
        ownerId: _owner,
        title: 'Alpha',
        matomeId: 'm_src',
      );
      await _seedFile(
        db,
        id: 'r2',
        ownerId: _owner,
        title: 'Beta',
        matomeId: 'm_src',
        createdAt: 900,
      );
      // Dest already holds an owner file so it is a picker target (the picker
      // lists matomes the owner has recordings in — owner-scoped, #1473).
      await _seedFile(
        db,
        id: 'seed_dst',
        ownerId: _owner,
        title: 'Gamma',
        matomeId: 'm_dst',
        createdAt: 800,
      );

      await tester.pumpWidget(_app(db));
      await tester.pumpAndSettle();

      await _selectRow(tester, 'Alpha');
      await _selectRow(tester, 'Beta');

      // Bulk bar visible → tap Move.
      expect(find.byKey(const ValueKey('files-bulk-bar')), findsOneWidget);
      await tester.tap(find.text(t.files.moveToMatome).first);
      await tester.pumpAndSettle();

      // Picker is open (its Unfiled tile is unique) → pick Dest.
      expect(
        find.byKey(const ValueKey('files-move-target-unfiled')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('files-move-target-m_dst')));
      await tester.pumpAndSettle();

      // Persisted: both files now in Dest.
      var files = await db.itemsDao.filesForOwner(_owner);
      expect(files.firstWhere((f) => f.id == 'r1').matome, 'Dest');
      expect(files.firstWhere((f) => f.id == 'r2').matome, 'Dest');

      // Undo restores prior matome.
      expect(find.text(t.files.movedMsg(n: 2)), findsOneWidget);
      await tester.tap(find.text(t.files.undo));
      await tester.pumpAndSettle();

      files = await db.itemsDao.filesForOwner(_owner);
      expect(files.firstWhere((f) => f.id == 'r1').matome, 'Source');
      expect(files.firstWhere((f) => f.id == 'r2').matome, 'Source');
    },
  );

  testWidgets('per-row move: overflow menu → picker → reassigns one file', (
    tester,
  ) async {
    await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
    await db.matomesDao.create(_matome(id: 'm_dst', title: 'Dest'));
    await _seedFile(
      db,
      id: 'r1',
      ownerId: _owner,
      title: 'Alpha',
      matomeId: 'm_src',
    );
    await _seedFile(
      db,
      id: 'seed_dst',
      ownerId: _owner,
      title: 'Gamma',
      matomeId: 'm_dst',
      createdAt: 800,
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Open the Alpha row overflow menu, then Move to matome.
    final alphaRow = find
        .ancestor(
          of: find.text('Alpha'),
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.tap(
      find.descendant(of: alphaRow, matching: find.byIcon(Icons.more_horiz)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.files.moveToMatome).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('files-move-target-m_dst')));
    await tester.pumpAndSettle();

    final files = await db.itemsDao.filesForOwner(_owner);
    expect(files.firstWhere((f) => f.id == 'r1').matome, 'Dest');
  });

  testWidgets('move to Unfiled clears the matome', (tester) async {
    await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
    await _seedFile(
      db,
      id: 'r1',
      ownerId: _owner,
      title: 'Alpha',
      matomeId: 'm_src',
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await tester.tap(find.text(t.files.moveToMatome).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('files-move-target-unfiled')));
    await tester.pumpAndSettle();

    final files = await db.itemsDao.filesForOwner(_owner);
    expect(files.single.unfiled, isTrue);
  });

  testWidgets('cross-owner: picker offers ONLY the owner matomes', (
    tester,
  ) async {
    // Owner 1 owns a file in m_a; owner 2 owns one in m_b. The picker for owner 1
    // must list m_a (and Unfiled) but NOT m_b — a cross-owner target.
    await db.matomesDao.create(_matome(id: 'm_a', title: 'Mine'));
    await db.matomesDao.create(_matome(id: 'm_b', title: 'Theirs'));
    await _seedFile(
      db,
      id: 'r1',
      ownerId: _owner,
      title: 'Alpha',
      matomeId: 'm_a',
    );
    await _seedFile(
      db,
      id: 'r2',
      ownerId: _otherOwner,
      title: 'Beta',
      matomeId: 'm_b',
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await tester.tap(find.text(t.files.moveToMatome).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('files-move-target-m_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('files-move-target-m_b')), findsNothing);
    expect(find.text('Theirs'), findsNothing);
  });

  testWidgets('download explicitly exports outside Vault and warns the user', (
    tester,
  ) async {
    await db.matomesDao.create(_matome(id: 'm1', title: 'M1'));
    await _seedFile(
      db,
      id: 'r1',
      ownerId: _owner,
      title: 'Alpha',
      matomeId: 'm1',
    );

    final exports = <String>[];
    final exporter = VaultExportService(
      FakeMediaBlobStore(),
      override: ({required blobId, required suggestedFilename}) async {
        exports.add('$blobId:$suggestedFilename');
        return true;
      },
    );
    await tester.pumpWidget(_app(db, exporter: exporter));
    await tester.pumpAndSettle();

    await _selectRow(tester, 'Alpha');
    await tester.tap(find.text(t.files.download).first);
    await tester.pumpAndSettle();

    expect(exports, ['fixture-blob:Alpha']);
    expect(find.text(t.files.exportedOutsideVault(n: 1)), findsOneWidget);
    final files = await db.itemsDao.filesForOwner(_owner);
    expect(files.single.matome, 'M1'); // unchanged
  });

  testWidgets('FileAction enum exposes explicit download/export', (
    tester,
  ) async {
    expect(FileAction.values, contains(FileAction.download));
  });

  // The on-screen grid↔table toggle was removed (#1474): Settings is the single
  // control. The AppBar no longer carries the grid/table segments.
  testWidgets('no on-screen files view toggle in the AppBar', (tester) async {
    await db.matomesDao.create(_matome(id: 'm1', title: 'M1'));
    await _seedFile(
      db,
      id: 'r1',
      ownerId: _owner,
      title: 'Alpha',
      matomeId: 'm1',
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('files-view-grid')), findsNothing);
    expect(find.byKey(const ValueKey('files-view-table')), findsNothing);
  });

  // The screen still renders whatever view the provider holds: a stored "table"
  // preference shows the table, a stored "grid" preference shows the grid.
  testWidgets('renders the view the provider holds (no toggle to change it)', (
    tester,
  ) async {
    await db.matomesDao.create(_matome(id: 'm1', title: 'M1'));
    await _seedFile(
      db,
      id: 'r1',
      ownerId: _owner,
      title: 'Alpha',
      matomeId: 'm1',
    );

    await tester.pumpWidget(_app(db, view: 'table'));
    await tester.pumpAndSettle();
    expect(find.byType(FilesTable), findsOneWidget);
    expect(find.byType(FilesGrid), findsNothing);

    await tester.pumpWidget(_app(db, view: 'grid'));
    await tester.pumpAndSettle();
    expect(find.byType(FilesGrid), findsOneWidget);
    expect(find.byType(FilesTable), findsNothing);
  });
}
