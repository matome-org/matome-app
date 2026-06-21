import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/audio_player_bar.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/file_type_chip.dart';

/// Builds an image [RecordingItem]. The path points at a non-existent file on
/// purpose: `Image.file` falls back to its `errorBuilder` in the test
/// environment, which is fine — these tests assert structure/navigation, not
/// pixel decoding.
RecordingItem _imageItem({
  String id = 'rec_img',
  String title = 'Beach sunset',
  String? notes,
  String? workspaceName,
  String? filePath = '/tmp/does-not-exist.jpg',
}) {
  return RecordingItem(
    id: id,
    title: title,
    timestamp: '9:00 AM',
    duration: '0:00',
    badge: 'Inbox',
    isProcessing: false,
    mediaType: 'image/jpeg',
    processingStatus: 'done',
    notes: notes,
    workspaceName: workspaceName,
    filePath: filePath,
  );
}

Future<void> _pump(WidgetTester tester, RecordingItem item) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: TranslationProvider(child: FileDetailScreen(item: item)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets(
    'image host renders FileView with an image media header + Contents + Notes',
    (tester) async {
      await _pump(tester, _imageItem(notes: 'My own note.'));

      // The presentational FileView is the body of the host.
      expect(find.byType(FileView), findsOneWidget);
      // Image media header (the inline framed preview) is present.
      expect(
        find.byKey(const ValueKey('file-detail-image-header')),
        findsOneWidget,
      );
      // Contents section is shown (image → "Description"), honest-empty for now.
      // It can sit below the fold under the framed media header — the ListView
      // builds all children eagerly, so assert structure regardless of offstage.
      expect(
        find.byKey(const ValueKey('file-view-contents'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Description', skipOffstage: false), findsOneWidget);
      // Notes section is present and seeded.
      expect(
        find.byKey(const ValueKey('file-view-notes'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('My own note.', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'image host Contents converges on EMPTY ("No description yet"), never a '
    'fake "Describing…" — the description producer is deferred (#1440/#1445)',
    (tester) async {
      await _pump(tester, _imageItem());

      // The honest terminal empty state, NOT a processing claim.
      expect(
        find.byKey(
          const ValueKey('file-view-contents-empty'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text('No description yet', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Describing…', skipOffstage: false), findsNothing);
      expect(find.text('Transcribing…', skipOffstage: false), findsNothing);
      // No producer → no processing spinner / retry inside Contents.
      expect(
        find.byKey(
          const ValueKey('file-view-contents-processing'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('tapping the media header opens the fullscreen viewer', (
    tester,
  ) async {
    await _pump(tester, _imageItem());

    // Not on screen until the header is tapped.
    expect(
      find.byKey(const ValueKey('file-detail-fullscreen-viewer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('file-detail-image-header')));
    await tester.pumpAndSettle();

    // The relocated lightbox: a fullscreen InteractiveViewer reached FROM the
    // media header (not the whole experience).
    expect(
      find.byKey(const ValueKey('file-detail-fullscreen-viewer')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('media header has no tap action when the file path is missing', (
    tester,
  ) async {
    await _pump(tester, _imageItem(filePath: null));

    await tester.tap(find.byKey(const ValueKey('file-detail-image-header')));
    await tester.pumpAndSettle();

    // No viewer is pushed for a path-less Item — it just shows the placeholder.
    expect(
      find.byKey(const ValueKey('file-detail-fullscreen-viewer')),
      findsNothing,
    );
  });

  test('mediaKindOf maps media types to the right FileMediaKind', () {
    expect(FileDetailScreen.mediaKindOf(_imageItem()), FileMediaKind.image);

    final audio = RecordingItem(
      id: 'rec_a',
      title: 'Standup',
      timestamp: '9:00 AM',
      duration: '0:30',
      badge: 'Inbox',
      isProcessing: false,
      mediaType: 'audio/m4a',
      processingStatus: 'done',
    );
    expect(FileDetailScreen.mediaKindOf(audio), FileMediaKind.audio);
  });

  // ── Document host (#1450): row-only load, NEVER the audio host ──────────────
  group('FileDetailScreen.documentById (document host)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> seedDoc(String id) => db.recordingsDao.insertRecording(
          RecordingsCompanion(
            id: Value(id),
            title: const Value('Quarterly report'),
            timestamp: const Value('9:00 AM'),
            duration: const Value(''),
            badge: const Value('Inbox'),
            isProcessing: const Value(0),
            audioFilePath: const Value('/tmp/report.pdf'),
            createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
            // The picker (#1449) stores documents as mediaType='document'.
            mediaType: const Value('document'),
            originalExtension: const Value('pdf'),
            processingStatus: const Value('done'),
          ),
        );

    Widget app(String id) => UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildLightTheme(),
              home: FileDetailScreen.documentById(id: id),
            ),
          ),
        );

    testWidgets(
      'loads the row and renders the FileView document host (NOT the audio '
      'host: no AudioPlayerBar, no audio downloadUrl awaited)',
      (tester) async {
        await seedDoc('rec_doc');
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();

        // The presentational FileView is the body of the host.
        expect(find.byType(FileView), findsOneWidget);
        // It is the DOCUMENT host: the Contents tag is "Document" (the doc
        // kind's default tag), NOT "Transcript" (audio) or "Description" (image).
        expect(find.text('Document', skipOffstage: false), findsOneWidget);
        expect(find.text('Transcript', skipOffstage: false), findsNothing);
        // The audio host's player bar must NEVER appear for a document.
        expect(find.byType(AudioPlayerBar), findsNothing);
        // Title from the loaded row.
        expect(find.text('Quarterly report'), findsWidgets);
      },
    );

    testWidgets(
      'renders the FileTypeChip media header: type icon from the persisted '
      'original_extension (.pdf) + file name + DISABLED "Open" labelled "soon"',
      (tester) async {
        await seedDoc('rec_doc');
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();

        // The doc media header is the FileTypeChip (not an image/audio header).
        expect(
          find.byKey(const ValueKey('file-type-chip'), skipOffstage: false),
          findsOneWidget,
        );
        // Type icon resolves from the persisted `original_extension` ('pdf').
        expect(
          find.byIcon(FileTypeChip.iconForExtension('pdf')),
          findsOneWidget,
        );
        // The chip shows the file name.
        expect(
          find.byKey(
            const ValueKey('file-type-chip-name'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        // The Open affordance is present, labelled, and DISABLED ("soon").
        expect(find.text(t.fileView.fileChip.open), findsOneWidget);
        expect(find.text(t.fileView.fileChip.soon), findsOneWidget);
        final open = tester.widget<TextButton>(
          find.byKey(const ValueKey('file-type-chip-open')),
        );
        expect(open.onPressed, isNull);
      },
    );

    testWidgets(
      'survives a go_router-style rebuild (id is in the constructor, no '
      '`state.extra!` null-check crash)',
      (tester) async {
        await seedDoc('rec_doc');
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();
        expect(find.byType(FileView), findsOneWidget);

        // Force a full rebuild of the route subtree — the failure mode the image
        // route already fixed was `state.extra!` throwing after a rebuild drops
        // `extra`. The id lives in the constructor (from the path param), so the
        // host re-resolves the row cleanly.
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();

        expect(find.byType(FileView), findsOneWidget);
        expect(find.text('Document', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('missing row renders an honest fallback, not a crash', (
      tester,
    ) async {
      await tester.pumpWidget(app('does_not_exist'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AudioPlayerBar), findsNothing);
    });
  });
}
