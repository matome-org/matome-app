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
  FileTypeChipAction action = FileTypeChipAction.open,
  FileTypeChipState state = FileTypeChipState.ready,
  VoidCallback? onAction,
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
              action: action,
              state: state,
              onAction: onAction,
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

    testWidgets('uses a distinct type icon for a .md extension', (
      tester,
    ) async {
      await _pump(tester, fileName: 'notes.md', extension: 'md');

      expect(find.byIcon(FileTypeChip.iconForExtension('md')), findsOneWidget);
    });

    testWidgets('renders an enabled external Open action', (tester) async {
      var opened = false;
      await _pump(
        tester,
        fileName: 'spec.pdf',
        extension: 'pdf',
        onAction: () => opened = true,
      );

      expect(find.text(t.fileView.fileChip.open), findsOneWidget);
      final button = tester.widget<AbstractButton>(
        find.byKey(const ValueKey('file-type-chip-open')),
      );
      expect(button.onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('file-type-chip-open')));
      expect(opened, isTrue);
    });

    testWidgets(
      'renders loading, failure, download, and active-content warning states',
      (tester) async {
        await _pump(
          tester,
          fileName: 'page.html',
          extension: 'html',
          action: FileTypeChipAction.downloadWithWarning,
          state: FileTypeChipState.loading,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text(t.fileView.fileChip.activeContentWarning),
          findsOneWidget,
        );

        await _pump(
          tester,
          fileName: 'archive.xyz',
          extension: 'xyz',
          action: FileTypeChipAction.download,
          state: FileTypeChipState.failed,
          onAction: () {},
        );
        expect(find.text(t.fileView.fileChip.openFailed), findsOneWidget);
        expect(find.text(t.common.retry), findsOneWidget);
      },
    );

    testWidgets('falls back to a generic icon for an unknown extension', (
      tester,
    ) async {
      await _pump(tester, fileName: 'archive.xyz', extension: 'xyz');

      expect(find.byIcon(FileTypeChip.iconForExtension('xyz')), findsOneWidget);
      expect(
        FileTypeChip.iconForExtension('xyz'),
        FileTypeChip.iconForExtension(null),
      );
    });

    testWidgets('disabled state is unavailable and never offers retry', (
      tester,
    ) async {
      await _pump(
        tester,
        fileName: 'report.pdf',
        extension: 'pdf',
        state: FileTypeChipState.disabled,
        onAction: () {},
      );

      expect(find.text(t.fileView.fileChip.unavailable), findsOneWidget);
      expect(find.text(t.common.retry), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
      final button = tester.widget<AbstractButton>(
        find.byKey(const ValueKey('file-type-chip-open')),
      );
      expect(button.onPressed, isNull);
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
