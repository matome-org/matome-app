import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/file_row.dart';
import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/files/widgets/files_table.dart';
import 'package:matome_flutter/features/files/widgets/files_view_shared.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

// Sample rows exercising the THREE independent relations + their absences
// (DR-003): f1 fully filed; f3 BOTH Unfiled (matome null) AND Inbox (space
// null); f5 Unfiled-but-in-a-space (space ≠ matome).
const _files = <FileRow>[
  FileRow(
    id: 'f1',
    name: 'Q3 roadmap.pdf',
    kind: FileKind.document,
    ext: 'pdf',
    when: '2h',
    whenSort: 100,
    matome: 'Client X — weekly sync',
    space: 'Marketing',
    contacts: ['Ana', 'Ken'],
    rollup: MatomeSyncRollup.cloud,
  ),
  FileRow(
    id: 'f3',
    name: 'whiteboard.jpg',
    kind: FileKind.image,
    ext: 'jpg',
    when: '5h',
    whenSort: 80,
    matome: null, // Unfiled
    space: null, // Inbox
    rollup: MatomeSyncRollup.onDevice,
  ),
  FileRow(
    id: 'f5',
    name: 'voice-memo.m4a',
    kind: FileKind.audio,
    ext: 'm4a',
    when: '1d',
    whenSort: 49,
    matome: null, // Unfiled
    space: 'Personal', // but filed into a space
    rollup: MatomeSyncRollup.onDevice,
    duration: '00:48',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<FileRow> files = _files,
  Set<String> initialSelection = const {},
  double width = 960,
  FileOpenCallback? onOpen,
  FileSortCallback? onSort,
  FileSelectionCallback? onSelectionChanged,
  FileBulkCallback? onBulk,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: TranslationProvider(
          child: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: FilesTable(
                  files: files,
                  initialSelection: initialSelection,
                  onOpen: onOpen,
                  onSort: onSort,
                  onSelectionChanged: onSelectionChanged,
                  onBulk: onBulk,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('FilesTable structure', () {
    testWidgets('renders a header with all column labels', (tester) async {
      await _pump(tester);
      expect(find.text(t.files.colName.toUpperCase()), findsOneWidget);
      expect(find.text(t.files.colMatome.toUpperCase()), findsOneWidget);
      expect(find.text(t.files.colSpace.toUpperCase()), findsOneWidget);
      expect(find.text(t.files.colPeople.toUpperCase()), findsOneWidget);
      expect(find.text(t.files.colWhen.toUpperCase()), findsOneWidget);
      expect(find.text(t.files.colSize.toUpperCase()), findsOneWidget);
      expect(find.text(t.files.colSync.toUpperCase()), findsOneWidget);
    });

    testWidgets('empty files render the empty state', (tester) async {
      await _pump(tester, files: const []);
      expect(find.text(t.files.emptyTitle), findsOneWidget);
      expect(find.text(t.files.emptyBody), findsOneWidget);
    });

    testWidgets('size is never fabricated — absent size shows a dash',
        (tester) async {
      await _pump(tester, files: [_files[0]]);
      // f1 has a null sizeLabel (#1461 schema gap) and tagged contacts, so the
      // only dash on screen is the Size cell — never a fabricated size.
      expect(find.text(t.files.noSize), findsOneWidget);
    });

    testWidgets('compact layout below the breakpoint shows the sort selector',
        (tester) async {
      await _pump(tester, width: 380);
      expect(find.text(t.files.sortBy.toUpperCase()), findsOneWidget);
      expect(
        find.text(t.files.colName.toUpperCase()),
        findsNothing,
        reason: 'No desktop column header below the compact breakpoint.',
      );
    });
  });

  group('Unfiled / Inbox states (DR-003)', () {
    testWidgets('a fully-filed file shows its matome + space names',
        (tester) async {
      await _pump(tester, files: [_files[0]]);
      expect(find.text('Client X — weekly sync'), findsOneWidget);
      expect(find.text('Marketing'), findsOneWidget);
    });

    testWidgets('a matome-less, space-less file shows BOTH Unfiled and Inbox',
        (tester) async {
      await _pump(tester, files: [_files[1]]);
      expect(find.text(t.files.unfiled), findsOneWidget);
      expect(find.text(t.matome.placeInbox), findsOneWidget);
    });

    testWidgets('Unfiled but in a space: Unfiled chip + the space name (not Inbox)',
        (tester) async {
      await _pump(tester, files: [_files[2]]);
      expect(find.text(t.files.unfiled), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text(t.matome.placeInbox), findsNothing);
    });
  });

  group('Sorting', () {
    testWidgets('tapping the Name header sorts A→Z and emits onSort',
        (tester) async {
      FileSortKey? sortKey;
      bool? ascending;
      await _pump(tester, onSort: (k, a) {
        sortKey = k;
        ascending = a;
      });
      await tester.tap(find.text(t.files.colName.toUpperCase()));
      await tester.pumpAndSettle();
      expect(sortKey, FileSortKey.name);
      expect(ascending, isTrue, reason: 'Name sorts A→Z first.');
    });
  });

  group('Selection → bulk bar', () {
    testWidgets('selecting a row reveals the bulk bar and emits the selection',
        (tester) async {
      Set<String>? selection;
      await _pump(tester, onSelectionChanged: (s) => selection = s);

      expect(find.byKey(const ValueKey('files-bulk-bar')), findsNothing);
      await tester.tap(find.byType(Checkbox).at(1)); // first data row checkbox
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('files-bulk-bar')), findsOneWidget);
      expect(selection, isNotNull);
      expect(selection!.length, 1);
    });

    testWidgets('select-all header checkbox selects every file', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(Checkbox).first); // header tristate
      await tester.pumpAndSettle();
      expect(
          find.text(t.files.selected(n: _files.length)), findsOneWidget);
    });
  });

  group('Destructive ops: confirm + undo', () {
    testWidgets('bulk delete confirms, removes the file, then offers undo',
        (tester) async {
      FileAction? bulkAction;
      Set<String>? bulkIds;
      await _pump(
        tester,
        initialSelection: const {'f1'},
        onBulk: (a, ids) {
          bulkAction = a;
          bulkIds = ids;
        },
      );

      expect(find.byKey(const ValueKey('files-bulk-bar')), findsOneWidget);

      await tester.tap(find.text(t.files.delete).first);
      await tester.pumpAndSettle();
      expect(find.text(t.files.deleteTitle), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('files-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Q3 roadmap.pdf'), findsNothing);
      expect(bulkAction, FileAction.delete);
      expect(bulkIds, {'f1'});

      expect(find.byKey(const ValueKey('files-undo-bar')), findsOneWidget);
      await tester.tap(find.text(t.files.undo));
      await tester.pumpAndSettle();
      expect(find.text('Q3 roadmap.pdf'), findsOneWidget);
    });
  });

  group('Open', () {
    testWidgets('tapping a row emits onOpen with the file id', (tester) async {
      String? opened;
      await _pump(tester, onOpen: (id) => opened = id);
      await tester.tap(find.text('Q3 roadmap.pdf'));
      await tester.pumpAndSettle();
      expect(opened, 'f1');
    });
  });
}
