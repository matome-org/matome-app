import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/space_chip.dart';

Future<void> _pump(WidgetTester tester, {String? space}) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: TranslationProvider(
          child: Center(child: SpaceChip(space: space)),
        ),
      ),
    ),
  );
}

void main() {
  group('SpaceChip', () {
    testWidgets('renders the space name with the folder glyph', (tester) async {
      await _pump(tester, space: 'Marketing');

      expect(find.text('Marketing'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('is an OUTLINED pill (transparent fill + border)', (
      tester,
    ) async {
      await _pump(tester, space: 'Product');

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('space-chip')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNotNull);
      expect(
        (decoration.border! as Border).top.color,
        MatomeColors.light.border,
      );
    });

    testWidgets('shows italic, muted "Inbox" when space is null', (
      tester,
    ) async {
      await _pump(tester, space: null);

      final label = tester.widget<Text>(find.text(t.matome.placeInbox));
      expect(label.style!.fontStyle, FontStyle.italic);
      expect(label.style!.color, MatomeColors.light.textMuted);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
    });
  });
}
