import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_card.dart';

/// The reworked Matome list row (#1412 / W6): compact, no left avatar, no right
/// chevron. Title full-width, a one-line summary peek, a dense meta strip
/// (time · item mix · people · place · sync chip), and a dense actions menu at
/// the right edge.
MatomeItem _matome({
  String id = 'm1',
  String title = 'Client X — weekly sync',
  String? summary = 'Q3 budget approved.',
  String? spaceId,
  String? spaceName,
  int audioCount = 0,
  int imageCount = 0,
  int documentCount = 0,
  int peopleCount = 0,
  int? coreId,
}) {
  const epoch = 1718000000000;
  return MatomeItem(
    id: id,
    spaceId: spaceId,
    title: title,
    happenedAt: epoch,
    createdAt: epoch,
    summaryStale: false,
    recordingCount: audioCount + imageCount + documentCount,
    recordings: const [],
    aggregatedSummary: summary,
    spaceName: spaceName,
    audioCount: audioCount,
    imageCount: imageCount,
    documentCount: documentCount,
    peopleCount: peopleCount,
    coreId: coreId,
  );
}

Future<void> _pump(WidgetTester tester, MatomeItem matome) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: TranslationProvider(
          child: AppCard.matome(matome: matome, relativeTime: '2h'),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('keeps the matome-card-<id> tap key', (tester) async {
    await _pump(tester, _matome(id: 'mTap'));
    expect(find.byKey(const ValueKey('matome-card-mTap')), findsOneWidget);
  });

  testWidgets('is compact: no left layers avatar, no right chevron', (
    tester,
  ) async {
    await _pump(tester, _matome());
    expect(find.byIcon(Icons.layers_outlined), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('shows the summary peek when a summary is present', (
    tester,
  ) async {
    await _pump(tester, _matome(summary: 'Q3 budget approved.'));
    expect(find.text('Q3 budget approved.'), findsOneWidget);
    expect(find.text(t.matome.noSummary), findsNothing);
  });

  testWidgets('falls back to "No summary yet" when the summary is empty', (
    tester,
  ) async {
    await _pump(tester, _matome(summary: null));
    expect(find.text(t.matome.noSummary), findsOneWidget);
  });

  testWidgets('meta strip leads with the relative time token', (tester) async {
    await _pump(tester, _matome());
    expect(find.text('2h'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('shows mic / image tokens only when their count > 0', (
    tester,
  ) async {
    await _pump(tester, _matome(audioCount: 2, imageCount: 0));
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // No image item → no image token.
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });

  testWidgets(
    'shows the document token with its count when documentCount > 0',
    (tester) async {
      // No document Items → no doc token (the strip stays dense).
      await _pump(tester, _matome(documentCount: 0));
      expect(find.byIcon(Icons.description_outlined), findsNothing);

      // A matome with N document Items → doc icon + the count (#1449/#1453).
      await _pump(tester, _matome(documentCount: 4));
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets('shows the people token only when peopleCount > 0', (
    tester,
  ) async {
    await _pump(tester, _matome(peopleCount: 0));
    expect(find.byIcon(Icons.people_outline), findsNothing);

    await _pump(tester, _matome(peopleCount: 3));
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('place chip shows the space name when filed', (tester) async {
    await _pump(tester, _matome(spaceId: 's1', spaceName: 'Marketing'));
    expect(find.text('Marketing'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
  });

  testWidgets('place chip shows Inbox when not filed', (tester) async {
    await _pump(tester, _matome(spaceId: null));
    expect(find.text(t.matome.placeInbox), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('sync chip always renders, driven by the rollup (on device)', (
    tester,
  ) async {
    await _pump(tester, _matome(coreId: null));
    expect(find.byType(MatomeSyncChip), findsOneWidget);
    expect(find.text(t.cardStatus.onDevice), findsOneWidget);
  });

  testWidgets('sync chip renders "Synced" for a synced rollup', (tester) async {
    await _pump(tester, _matome(coreId: 42));
    expect(find.byType(MatomeSyncChip), findsOneWidget);
    expect(find.text(t.cardStatus.cloud), findsOneWidget);
  });

  testWidgets('dense actions menu is present on the row', (tester) async {
    await _pump(tester, _matome());
    expect(
      find.byKey(const ValueKey('matome-actions-trigger')),
      findsOneWidget,
    );
  });
}
