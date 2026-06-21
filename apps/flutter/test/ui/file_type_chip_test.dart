import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/file_type_chip.dart';

/// Pumps a [FileTypeChip] inside a themed + localized harness so the
/// presentational design-system widget can be asserted in isolation.
Future<void> _pump(
  WidgetTester tester, {
  required String fileName,
  String? extension,
  String? sizeLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: TranslationProvider(
          child: Center(
            child: FileTypeChip(
              fileName: fileName,
              extension: extension,
              sizeLabel: sizeLabel,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FileTypeChip', () {
    testWidgets('renders the file name and size', (tester) async {
      await _pump(
        tester,
        fileName: 'Q3 roadmap.pdf',
        extension: 'pdf',
        sizeLabel: '2.4 MB',
      );

      expect(find.text('Q3 roadmap.pdf'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
    });

    testWidgets('uses the PDF type icon for a .pdf extension', (tester) async {
      await _pump(tester, fileName: 'report.pdf', extension: 'pdf');

      expect(find.byIcon(FileTypeChip.iconForExtension('pdf')), findsOneWidget);
      // The .md icon must NOT be the same as the .pdf icon, so a pdf never
      // renders the markdown glyph.
      expect(
        FileTypeChip.iconForExtension('pdf'),
        isNot(FileTypeChip.iconForExtension('md')),
      );
    });

    testWidgets('uses a distinct type icon for a .md extension', (tester) async {
      await _pump(tester, fileName: 'notes.md', extension: 'md');

      expect(find.byIcon(FileTypeChip.iconForExtension('md')), findsOneWidget);
    });

    testWidgets('renders the Open affordance DISABLED with a "soon" label', (
      tester,
    ) async {
      await _pump(tester, fileName: 'spec.pdf', extension: 'pdf');

      // The Open affordance is present and labelled.
      expect(find.text(t.fileView.fileChip.open), findsOneWidget);
      expect(find.text(t.fileView.fileChip.soon), findsOneWidget);

      // …but it is disabled: the underlying button has a null onPressed so a
      // tap cannot route into the (deferred) preview path.
      final button = tester.widget<AbstractButton>(
        find.byKey(const ValueKey('file-type-chip-open')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('falls back to a generic icon for an unknown extension', (
      tester,
    ) async {
      await _pump(tester, fileName: 'archive.xyz', extension: 'xyz');

      expect(
        find.byIcon(FileTypeChip.iconForExtension('xyz')),
        findsOneWidget,
      );
      expect(
        FileTypeChip.iconForExtension('xyz'),
        FileTypeChip.iconForExtension(null),
      );
    });

    testWidgets('renders an em-dash placeholder when size is unknown', (
      tester,
    ) async {
      await _pump(tester, fileName: 'mystery.pdf', extension: 'pdf');

      expect(find.text(t.fileView.fileChip.unknownSize), findsOneWidget);
    });
  });
}

/// Minimal shared interface so the test can read [onPressed] off whatever
/// Material button the chip renders for the Open affordance without coupling to
/// its concrete type.
typedef AbstractButton = ButtonStyleButton;
