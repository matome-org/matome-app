import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_card.dart';

/// The single shared sync chip (#1407). One vocabulary — Synced / Syncing /
/// On device — driven purely by [MatomeSyncRollup]. Because the matome list row
/// and the detail pill render the SAME widget, they can never disagree for the
/// same matome (the original /critique P0).
void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  Future<void> pump(WidgetTester tester, MatomeSyncRollup rollup) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: MatomeSyncChip(rollup: rollup)),
      ),
    );
  }

  testWidgets('cloud rollup → "Synced"', (tester) async {
    await pump(tester, MatomeSyncRollup.cloud);
    expect(find.text(t.cardStatus.cloud), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
  });

  testWidgets(
    'partial rollup → "Syncing" (failed child stays here, 3 states)',
    (tester) async {
      await pump(tester, MatomeSyncRollup.partial);
      expect(find.text(t.cardStatus.syncing), findsOneWidget);
      expect(find.text('Syncing'), findsOneWidget);
    },
  );

  testWidgets('onDevice rollup → "On device" with the cloud_off glyph', (
    tester,
  ) async {
    await pump(tester, MatomeSyncRollup.onDevice);
    expect(find.text(t.cardStatus.onDevice), findsOneWidget);
    expect(find.text('On device'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('no triage suffix — filing is a separate concern', (
    tester,
  ) async {
    await pump(tester, MatomeSyncRollup.cloud);
    expect(find.textContaining('not filed'), findsNothing);
    expect(find.textContaining('·'), findsNothing);
  });
}
