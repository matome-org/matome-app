import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/file_row.dart';
import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/files/widgets/files_grid.dart';
import 'package:matome_flutter/features/files/widgets/files_view_shared.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

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
  double width = 900,
  FileOpenCallback? onOpen,
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
                child: FilesGrid(
                  files: files,
                  initialSelection: initialSelection,
                  onOpen: onOpen,
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

  group('FilesGrid structure', () {
    testWidgets('renders a tile per file with its name', (tester) async {
      await _pump(tester);
      expect(find.text('Q3 roadmap.pdf'), findsOneWidget);
      expect(find.text('whiteboard.jpg'), findsOneWidget);
      expect(find.text('voice-memo.m4a'), findsOneWidget);
    });

    testWidgets('empty files render the empty state', (tester) async {
      await _pump(tester, files: const []);
      expect(find.text(t.files.emptyTitle), findsOneWidget);
      expect(find.text(t.files.emptyBody), findsOneWidget);
    });

    testWidgets('audio tile surfaces a duration tag', (tester) async {
      await _pump(tester, files: [_files[2]]);
      expect(find.text('00:48'), findsOneWidget);
    });

    testWidgets('size is never fabricated — absent size shows a dash', (
      tester,
    ) async {
      await _pump(tester, files: [_files[0]]);
      // The tile meta line is "<size> · <when>"; with no size the dash stands in.
      expect(find.text(t.files.noSize), findsOneWidget);
    });
  });

  group('Unfiled / Inbox states (DR-003)', () {
    testWidgets('a matome-less, space-less tile shows BOTH Unfiled and Inbox', (
      tester,
    ) async {
      await _pump(tester, files: [_files[1]]);
      expect(find.text(t.files.unfiled), findsOneWidget);
      expect(find.text(t.matome.placeInbox), findsOneWidget);
    });

    testWidgets(
      'Unfiled but in a space shows Unfiled + the space (not Inbox)',
      (tester) async {
        await _pump(tester, files: [_files[2]]);
        expect(find.text(t.files.unfiled), findsOneWidget);
        expect(find.text('Personal'), findsOneWidget);
        expect(find.text(t.matome.placeInbox), findsNothing);
      },
    );
  });

  group('Selection → bulk', () {
    testWidgets('a preselected tile shows the bulk bar', (tester) async {
      await _pump(tester, initialSelection: const {'f1'});
      expect(find.byKey(const ValueKey('files-bulk-bar')), findsOneWidget);
      expect(find.text(t.files.selected(n: 1)), findsOneWidget);
    });

    testWidgets('bulk delete confirms, removes the tile, then offers undo', (
      tester,
    ) async {
      FileAction? bulkAction;
      await _pump(
        tester,
        initialSelection: const {'f1'},
        onBulk: (a, ids) => bulkAction = a,
      );

      await tester.tap(find.text(t.files.delete).first);
      await tester.pumpAndSettle();
      expect(find.text(t.files.deleteTitle), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('files-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Q3 roadmap.pdf'), findsNothing);
      expect(bulkAction, FileAction.delete);

      expect(find.byKey(const ValueKey('files-undo-bar')), findsOneWidget);
      await tester.tap(find.text(t.files.undo));
      await tester.pumpAndSettle();
      expect(find.text('Q3 roadmap.pdf'), findsOneWidget);
    });
  });

  group('Open', () {
    testWidgets('tapping a tile emits onOpen with the file id', (tester) async {
      String? opened;
      await _pump(tester, onOpen: (id) => opened = id);
      await tester.tap(find.text('Q3 roadmap.pdf'));
      await tester.pumpAndSettle();
      expect(opened, 'f1');
    });
  });
}
