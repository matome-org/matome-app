import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/matome_chip.dart';

Future<void> _pump(WidgetTester tester, {String? matome}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: TranslationProvider(
          child: Center(child: MatomeChip(matome: matome)),
        ),
      ),
    ),
  );
}

void main() {
  group('MatomeChip', () {
    testWidgets('renders the matome title with the workspaces glyph', (
      tester,
    ) async {
      await _pump(tester, matome: 'Client X — weekly sync');

      expect(find.text('Client X — weekly sync'), findsOneWidget);
      expect(find.byIcon(Icons.workspaces_outlined), findsOneWidget);
    });

    testWidgets('is a FILLED pill (subtleFill background, no border)', (
      tester,
    ) async {
      await _pump(tester, matome: 'Design review');

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('matome-chip')),
      );
      final decoration = container.decoration! as BoxDecoration;
      final colors = MatomeColors.light;
      expect(decoration.color, colors.subtleFill);
      expect(decoration.border, isNull);
    });

    testWidgets('shows italic, muted "Unfiled" when matome is null', (
      tester,
    ) async {
      await _pump(tester, matome: null);

      final label = tester.widget<Text>(find.text(t.files.unfiled));
      expect(label.style!.fontStyle, FontStyle.italic);
      expect(label.style!.color, MatomeColors.light.textMuted);
      // The Unfiled (no-matome) absence uses the inbox glyph, not workspaces.
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byIcon(Icons.workspaces_outlined), findsNothing);
    });
  });
}
