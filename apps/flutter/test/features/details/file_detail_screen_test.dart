import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/audio_player_bar.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/file_type_chip.dart';

import '../../support/item_fixtures.dart';

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

    final video = RecordingItem(
      id: 'rec_v',
      title: 'Demo clip',
      timestamp: '9:00 AM',
      duration: '0:30',
      badge: 'Inbox',
      isProcessing: false,
      mediaType: 'video/mp4',
      processingStatus: 'done',
    );
    expect(FileDetailScreen.mediaKindOf(video), FileMediaKind.video);
  });

  test('item-driven file detail dispatch is pinned to MatomeItemType.file', () {
    final item = RecordingItem(
      id: 'file-1',
      title: 'Photo',
      timestamp: 'Now',
      duration: '',
      badge: 'Inbox',
      isProcessing: false,
      mediaType: 'image',
      processingStatus: 'done',
      itemType: MatomeItemType.file,
    );

    expect(item.itemType, MatomeItemType.file);
    expect(FileDetailScreen.mediaKindOf(item), FileMediaKind.image);
  });

  // ── Document host (#1450): row-only load, NEVER the audio host ──────────────
  group('FileDetailScreen.documentById (document host)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> seedDoc(String id) => insertTestFileItem(
      db,
      id: id,
      title: 'Quarterly report',
      localPath: '/tmp/report.pdf',
      filename: 'report.pdf',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      mediaType: 'document',
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

  group('FileDetailScreen.videoById (video host)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> seedVideo(String id) => insertTestFileItem(
      db,
      id: id,
      title: 'Launch clip',
      localPath: '/tmp/launch.mp4',
      filename: 'launch.mp4',
      durationSeconds: 5,
      createdAt: DateTime(2026, 7, 2).millisecondsSinceEpoch,
      mediaType: 'video',
    );

    Widget app(String id) => UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: buildLightTheme(),
          home: FileDetailScreen.videoById(id: id),
        ),
      ),
    );

    testWidgets('loads the row and renders video without the audio host', (
      tester,
    ) async {
      await seedVideo('rec_video');
      await tester.pumpWidget(app('rec_video'));
      await tester.pumpAndSettle();

      expect(find.byType(FileView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('file-detail-video-header')),
        findsOneWidget,
      );
      expect(find.text('Video', skipOffstage: false), findsWidgets);
      expect(find.byType(AudioPlayerBar), findsNothing);
      expect(find.text('Launch clip'), findsWidgets);
    });
  });

  // ── Document Contents: the LIVE state machine (#1454) ───────────────────────
  // The doc host must derive Contents from the row's OWN fields — NOT a hardcoded
  // empty. Before #1454 it forced `ContentsState.empty`, so the stub summary
  // never rendered and the doc processing/failed strings were dead. These tests
  // pin all four live states AND that each surfaces the locale's doc string
  // (en + ja), proving the `contentsStatus.doc.*` i18n is wired to real states.
  group('FileDetailScreen.documentById — live Contents state (en + ja)', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
      );
      LocaleSettings.setLocaleSync(AppLocale.en);
    });

    tearDown(() async {
      LocaleSettings.setLocaleSync(AppLocale.en);
      container.dispose();
      await db.close();
    });

    // Seeds a document row in a given pipeline state. `transcript` is the
    // machine-owned column the AI-stub summary lands in (the doc Contents reads
    // it as the READY body).
    Future<void> seedDocState(
      String id, {
      String? transcript,
      bool isProcessing = false,
      String processingStatus = 'done',
    }) => insertTestFileItem(
      db,
      id: id,
      title: 'Quarterly report',
      localPath: '/tmp/report.pdf',
      filename: 'report.pdf',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      mediaType: 'document',
      transcript: transcript,
      processingStatus: isProcessing ? 'processing' : processingStatus,
    );

    Widget app(String id) => UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          locale: LocaleSettings.currentLocale.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildLightTheme(),
          home: FileDetailScreen.documentById(id: id),
        ),
      ),
    );

    for (final locale in [AppLocale.en, AppLocale.ja]) {
      final lc = locale.languageCode;
      final docStrings = locale.translations.fileView.contentsStatus.doc;

      testWidgets('READY: the stub summary renders as the contents — $lc', (
        tester,
      ) async {
        LocaleSettings.setLocaleSync(locale);
        await seedDocState(
          'rec_doc',
          transcript: 'AI stub summary for the document.',
        );
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('file-view-contents-ready')),
          findsOneWidget,
          reason: 'a document with a machine summary is in the READY state',
        );
        expect(
          find.text('AI stub summary for the document.'),
          findsOneWidget,
          reason: 'the doc Contents renders the machine summary text',
        );
        expect(
          find.byKey(const ValueKey('file-view-contents-empty')),
          findsNothing,
        );
      });

      testWidgets('PROCESSING: doc.processing string shows — $lc', (
        tester,
      ) async {
        LocaleSettings.setLocaleSync(locale);
        await seedDocState(
          'rec_doc',
          isProcessing: true,
          processingStatus: 'processing',
        );
        await tester.pumpWidget(app('rec_doc'));
        // The row future resolves on the first microtask; pump fixed frames
        // (NOT pumpAndSettle — the processing body's LoadingIndicator animates
        // forever, so the tree never "settles").
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byKey(const ValueKey('file-view-contents-processing')),
          findsOneWidget,
        );
        expect(
          find.text(docStrings.processing),
          findsOneWidget,
          reason: 'the $lc doc processing string is wired to the live state',
        );
      });

      testWidgets('FAILED: doc.failed string shows — $lc', (tester) async {
        LocaleSettings.setLocaleSync(locale);
        await seedDocState('rec_doc', processingStatus: 'failed');
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('file-view-contents-failed')),
          findsOneWidget,
        );
        expect(
          find.text(docStrings.failed),
          findsOneWidget,
          reason: 'the $lc doc failed string is wired to the live state',
        );
      });

      testWidgets('EMPTY: doc.empty string shows when no summary yet — $lc', (
        tester,
      ) async {
        LocaleSettings.setLocaleSync(locale);
        // done, no transcript → honest empty terminal.
        await seedDocState('rec_doc');
        await tester.pumpWidget(app('rec_doc'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('file-view-contents-empty')),
          findsOneWidget,
        );
        expect(
          find.text(docStrings.empty),
          findsOneWidget,
          reason: 'the $lc doc empty string is wired to the live state',
        );
      });
    }
  });
}
