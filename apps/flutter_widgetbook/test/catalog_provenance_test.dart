// Provenance gate: the widgetbook catalog RENDERS app widgets and must never
// DEFINE shippable ones. The only PUBLIC widget class allowed in this package
// is the `MatomeWidgetbook` entry point; everything else must be a private
// fixture/scene. Runs as a plain `flutter test` (no chrome).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../tool/catalog_provenance.dart';

void main() {
  group('catalogWidgetViolations (unit)', () {
    test('flags a public widget class defined in the catalog', () {
      final violations = catalogWidgetViolations({
        'lib/foo_proposal.dart': 'class FooProposal extends StatelessWidget {}',
      });
      expect(violations, hasLength(1));
      expect(violations.single, contains('FooProposal'));
    });

    test('allows private fixtures, the entry point, and *.g.dart widgets', () {
      final violations = catalogWidgetViolations({
        'lib/scenes.dart': 'class _InboxScene extends StatelessWidget {}',
        'lib/widgetbook.dart': 'class MatomeWidgetbook extends StatelessWidget {}',
        // Generated code is ignored even when it declares a public widget.
        'lib/widgetbook.directories.g.dart':
            'class GeneratedThing extends StatelessWidget {}',
      });
      expect(violations, isEmpty);
    });
  });

  test('real apps/flutter_widgetbook/lib has zero violations (integration)', () {
    // Resolve lib/ relative to the test's working directory (package root).
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'expected to run from apps/flutter_widgetbook (lib/ missing)',
    );

    final sources = <String, String>{};
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      sources[entity.path] = entity.readAsStringSync();
    }

    final violations = catalogWidgetViolations(sources);
    expect(
      violations,
      isEmpty,
      reason: 'catalog defines public widget(s):\n${violations.join('\n')}',
    );
  });
}
