import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/widgets/matome_table.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

const _rows = <MatomeTableRow>[
  MatomeTableRow(
    id: 'r1',
    title: 'Client X — weekly sync',
    summary: 'Q3 budget approved.',
    when: '2h',
    whenSort: 100,
    audio: 2,
    image: 1,
    doc: 1,
    people: 2,
    space: 'Marketing',
    rollup: MatomeSyncRollup.cloud,
  ),
  MatomeTableRow(
    id: 'r2',
    title: 'Apple design review',
    summary: 'Onboarding screens.',
    when: '4h',
    whenSort: 90,
    audio: 1,
    image: 0,
    doc: 0,
    people: 1,
    space: null,
    rollup: MatomeSyncRollup.partial,
  ),
  MatomeTableRow(
    id: 'r3',
    title: 'Zebra voice memo',
    summary: '',
    when: '5h',
    whenSort: 80,
    audio: 1,
    image: 0,
    doc: 0,
    people: 0,
    space: null,
    rollup: MatomeSyncRollup.onDevice,
  ),
];

/// Pumps [MatomeTable] inside a themed + localized harness wide enough for the
/// full desktop layout (>= the compact breakpoint) unless [width] is overridden.
Future<void> _pump(
  WidgetTester tester, {
  List<MatomeTableRow> rows = _rows,
  Set<String> initialSelection = const {},
  double width = 920,
  ValueChanged<String>? onOpen,
  void Function(MatomeTableSort, bool)? onSort,
  ValueChanged<Set<String>>? onSelectionChanged,
  void Function(MatomeTableAction, Set<String>)? onBulk,
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
                child: MatomeTable(
                  rows: rows,
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

  group('MatomeTable structure', () {
    testWidgets('renders a sortable header with all column labels',
        (tester) async {
      await _pump(tester);
      expect(find.text(t.matome.table.colTitle.toUpperCase()), findsOneWidget);
      expect(find.text(t.matome.table.colWhen.toUpperCase()), findsOneWidget);
      expect(find.text(t.matome.table.colItems.toUpperCase()), findsOneWidget);
      expect(find.text(t.matome.table.colPeople.toUpperCase()), findsOneWidget);
      expect(find.text(t.matome.table.colSpace.toUpperCase()), findsOneWidget);
      expect(find.text(t.matome.table.colSync.toUpperCase()), findsOneWidget);
    });

    testWidgets('empty rows render the empty state', (tester) async {
      await _pump(tester, rows: const []);
      expect(find.text(t.matome.table.emptyTitle), findsOneWidget);
      expect(find.text(t.matome.table.emptyBody), findsOneWidget);
    });

    testWidgets('renders the muted no-summary placeholder for empty summaries',
        (tester) async {
      await _pump(tester);
      expect(find.text(t.matome.table.noSummary), findsOneWidget);
    });

    testWidgets('compact layout below the breakpoint shows the sort selector',
        (tester) async {
      await _pump(tester, width: 380);
      // The compact sort bar carries the "Sort" caption; the desktop header
      // does not.
      expect(find.text(t.matome.table.sortBy.toUpperCase()), findsOneWidget);
      expect(
        find.text(t.matome.table.colTitle.toUpperCase()),
        findsNothing,
        reason: 'No desktop column header below the compact breakpoint.',
      );
    });
  });

  group('Sorting', () {
    testWidgets('tapping a column header sorts and emits onSort',
        (tester) async {
      MatomeTableSort? sortKey;
      bool? ascending;
      await _pump(
        tester,
        onSort: (k, a) {
          sortKey = k;
          ascending = a;
        },
      );

      await tester.tap(find.text(t.matome.table.colTitle.toUpperCase()));
      await tester.pumpAndSettle();

      expect(sortKey, MatomeTableSort.title);
      expect(ascending, isTrue, reason: 'Title sorts A→Z first.');
    });
  });

  group('Selection → bulk bar', () {
    testWidgets('selecting a row reveals the bulk bar and emits the selection',
        (tester) async {
      Set<String>? selection;
      await _pump(tester, onSelectionChanged: (s) => selection = s);

      expect(find.byKey(const ValueKey('matome-table-bulk-bar')), findsNothing);

      await tester.tap(find.byType(Checkbox).at(1)); // first data row checkbox
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('matome-table-bulk-bar')),
        findsOneWidget,
      );
      expect(selection, isNotNull);
      expect(selection!.length, 1);
    });

    testWidgets('select-all header checkbox selects every row',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(Checkbox).first); // header tristate
      await tester.pumpAndSettle();
      expect(find.text(t.matome.table.selected(n: _rows.length)),
          findsOneWidget);
    });
  });

  group('Destructive ops: confirm + undo', () {
    testWidgets('bulk delete confirms, removes rows, then offers undo',
        (tester) async {
      MatomeTableAction? bulkAction;
      Set<String>? bulkIds;
      await _pump(
        tester,
        initialSelection: const {'r1'},
        onBulk: (a, ids) {
          bulkAction = a;
          bulkIds = ids;
        },
      );

      // Bulk bar visible from the initial selection.
      expect(
        find.byKey(const ValueKey('matome-table-bulk-bar')),
        findsOneWidget,
      );

      // Tap the bulk Delete action → a confirm dialog appears.
      await tester.tap(find.text(t.matome.table.delete).first);
      await tester.pumpAndSettle();
      expect(find.text(t.matome.table.deleteTitle), findsOneWidget);

      // Confirm.
      await tester
          .tap(find.byKey(const ValueKey('matome-table-delete-confirm')));
      await tester.pumpAndSettle();

      // Row removed from the table and the bulk callback fired.
      expect(find.text('Client X — weekly sync'), findsNothing);
      expect(bulkAction, MatomeTableAction.delete);
      expect(bulkIds, {'r1'});

      // The in-table undo affordance is shown and restores the row.
      expect(
        find.byKey(const ValueKey('matome-table-undo-bar')),
        findsOneWidget,
      );
      await tester.tap(find.text(t.matome.table.undo));
      await tester.pumpAndSettle();
      expect(find.text('Client X — weekly sync'), findsOneWidget);
    });

    testWidgets('bulk archive removes immediately (no confirm) and offers undo',
        (tester) async {
      await _pump(tester, initialSelection: const {'r2'});

      await tester.tap(find.text(t.matome.table.archive).first);
      await tester.pumpAndSettle();

      // No confirm dialog for archive; the row is gone and undo is offered.
      expect(find.text(t.matome.table.deleteTitle), findsNothing);
      expect(find.text('Apple design review'), findsNothing);
      expect(
        find.byKey(const ValueKey('matome-table-undo-bar')),
        findsOneWidget,
      );
    });
  });

  group('Open', () {
    testWidgets('tapping a row emits onOpen with the row id', (tester) async {
      String? opened;
      await _pump(tester, onOpen: (id) => opened = id);
      await tester.tap(find.text('Client X — weekly sync'));
      await tester.pumpAndSettle();
      expect(opened, 'r1');
    });
  });
}
