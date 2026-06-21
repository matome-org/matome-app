import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Pumps a [FileView] inside a themed + localized harness so the presentational
/// widget can be asserted in isolation (no DB / provider / navigation).
Future<void> _pump(
  WidgetTester tester,
  FileViewData data, {
  TextEditingController? notesController,
  ValueChanged<String>? onNotesChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: TranslationProvider(
          child: FileView(
            data: data,
            notesController: notesController,
            onNotesChanged: onNotesChanged,
          ),
        ),
      ),
    ),
  );
}

FileViewData _data({
  String title = 'Weekly sync',
  String? place = 'Tokyo HQ',
  int? coreId,
  String? processingStatus,
  FileMediaKind mediaKind = FileMediaKind.audio,
  Widget? mediaHeader = const SizedBox.shrink(),
  String contentsTag = 'Transcript',
  String? contentsText = 'Machine transcript line.',
  ContentsState? contentsState,
  VoidCallback? onContentsRetry,
  String? notesText = 'My own note.',
}) {
  return FileViewData(
    title: title,
    place: place,
    syncCoreId: coreId,
    processingStatus: processingStatus,
    mediaKind: mediaKind,
    mediaHeader: mediaHeader,
    contentsTag: contentsTag,
    contentsText: contentsText,
    contentsState: contentsState,
    onContentsRetry: onContentsRetry,
    notesText: notesText,
  );
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('renders header title, place and contents/notes sections', (
    tester,
  ) async {
    await _pump(tester, _data());

    expect(find.text('Weekly sync'), findsOneWidget);
    expect(find.text('Tokyo HQ'), findsOneWidget);
    // Umbrella "Contents" label + per-type tag.
    expect(find.byKey(const ValueKey('file-view-contents')), findsOneWidget);
    expect(find.text('Transcript'), findsOneWidget);
    expect(find.text('Machine transcript line.'), findsOneWidget);
    // Notes section is present and editable.
    expect(find.byKey(const ValueKey('file-view-notes')), findsOneWidget);
  });

  testWidgets('audio media header slot is rendered', (tester) async {
    const marker = Key('audio-marker');
    await _pump(
      tester,
      _data(
        mediaKind: FileMediaKind.audio,
        mediaHeader: const SizedBox(key: marker),
      ),
    );

    expect(find.byKey(marker), findsOneWidget);
  });

  testWidgets('image media header slot is rendered', (tester) async {
    const marker = Key('image-marker');
    await _pump(
      tester,
      _data(
        mediaKind: FileMediaKind.image,
        contentsTag: 'Description',
        mediaHeader: const SizedBox(key: marker),
      ),
    );

    expect(find.byKey(marker), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
  });

  testWidgets('contents is read-only (no editable field in contents)', (
    tester,
  ) async {
    await _pump(tester, _data());

    final contents = find.byKey(const ValueKey('file-view-contents'));
    expect(
      find.descendant(of: contents, matching: find.byType(EditableText)),
      findsNothing,
    );
  });

  testWidgets('notes section drives the provided controller', (tester) async {
    final controller = TextEditingController(text: 'seed');
    var lastChange = '';
    await _pump(
      tester,
      _data(notesText: 'seed'),
      notesController: controller,
      onNotesChanged: (value) => lastChange = value,
    );

    final field = find.descendant(
      of: find.byKey(const ValueKey('file-view-notes')),
      matching: find.byType(EditableText),
    );
    expect(field, findsOneWidget);

    await tester.enterText(field, 'edited note');
    await tester.pump();

    expect(controller.text, 'edited note');
    expect(lastChange, 'edited note');
  });

  testWidgets('empty contents shows a placeholder, not a crash', (tester) async {
    await _pump(tester, _data(contentsText: null));

    expect(find.byKey(const ValueKey('file-view-contents')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('file-view-contents-empty')),
      findsOneWidget,
    );
  });

  // ─── Contents state machine (#1440) ────────────────────────────────────────
  //
  // Per (type × state) the read-only Contents body renders an honest state
  // driven by the recording's own fields — never a fake "transcribing".

  group('contents state machine — audio', () {
    testWidgets('processing → "Transcribing…"', (tester) async {
      await _pump(
        tester,
        _data(
          mediaKind: FileMediaKind.audio,
          contentsTag: 'Transcript',
          contentsText: null,
          contentsState: ContentsState.processing,
        ),
      );

      expect(
        find.byKey(const ValueKey('file-view-contents-processing')),
        findsOneWidget,
      );
      expect(find.text('Transcribing…'), findsOneWidget);
    });

    testWidgets('ready → transcript text', (tester) async {
      await _pump(
        tester,
        _data(
          mediaKind: FileMediaKind.audio,
          contentsTag: 'Transcript',
          contentsText: 'Machine transcript line.',
          contentsState: ContentsState.ready,
        ),
      );

      expect(
        find.byKey(const ValueKey('file-view-contents-ready')),
        findsOneWidget,
      );
      expect(find.text('Machine transcript line.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('file-view-contents-processing')),
        findsNothing,
      );
    });

    testWidgets('failed → message + Retry affordance', (tester) async {
      var retried = false;
      await _pump(
        tester,
        _data(
          mediaKind: FileMediaKind.audio,
          contentsTag: 'Transcript',
          contentsText: null,
          contentsState: ContentsState.failed,
          onContentsRetry: () => retried = true,
        ),
      );

      expect(
        find.byKey(const ValueKey('file-view-contents-failed')),
        findsOneWidget,
      );
      final retry = find.byKey(const ValueKey('file-view-contents-retry'));
      expect(retry, findsOneWidget);

      await tester.tap(retry);
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('empty → "No transcript yet"', (tester) async {
      await _pump(
        tester,
        _data(
          mediaKind: FileMediaKind.audio,
          contentsTag: 'Transcript',
          contentsText: null,
          contentsState: ContentsState.empty,
        ),
      );

      expect(
        find.byKey(const ValueKey('file-view-contents-empty')),
        findsOneWidget,
      );
      expect(find.text('No transcript yet'), findsOneWidget);
    });
  });

  group('contents state machine — image', () {
    testWidgets(
      'empty → "No description yet", never a fake "Transcribing…"',
      (tester) async {
        await _pump(
          tester,
          _data(
            mediaKind: FileMediaKind.image,
            contentsTag: 'Description',
            contentsText: null,
            contentsState: ContentsState.empty,
          ),
        );

        expect(
          find.byKey(const ValueKey('file-view-contents-empty')),
          findsOneWidget,
        );
        expect(find.text('No description yet'), findsOneWidget);
        expect(find.text('Transcribing…'), findsNothing);
        expect(find.text('Describing…'), findsNothing);
      },
    );

    testWidgets('processing → "Describing…"', (tester) async {
      await _pump(
        tester,
        _data(
          mediaKind: FileMediaKind.image,
          contentsTag: 'Description',
          contentsText: null,
          contentsState: ContentsState.processing,
        ),
      );

      expect(
        find.byKey(const ValueKey('file-view-contents-processing')),
        findsOneWidget,
      );
      expect(find.text('Describing…'), findsOneWidget);
    });

    testWidgets('ready → description text', (tester) async {
      await _pump(
        tester,
        _data(
          mediaKind: FileMediaKind.image,
          contentsTag: 'Description',
          contentsText: 'A framed photo of the team.',
          contentsState: ContentsState.ready,
        ),
      );

      expect(find.text('A framed photo of the team.'), findsOneWidget);
    });
  });

  testWidgets('state defaults from text: text present → ready', (tester) async {
    await _pump(
      tester,
      _data(contentsText: 'Some transcript.'),
    );

    expect(
      find.byKey(const ValueKey('file-view-contents-ready')),
      findsOneWidget,
    );
  });

  testWidgets('state defaults from text: no text → empty', (tester) async {
    await _pump(tester, _data(contentsText: null));

    expect(
      find.byKey(const ValueKey('file-view-contents-empty')),
      findsOneWidget,
    );
  });
}
