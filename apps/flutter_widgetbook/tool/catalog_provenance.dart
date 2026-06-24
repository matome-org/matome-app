// Catalog provenance check.
//
// The widgetbook catalog RENDERS app widgets; it must never DEFINE shippable
// ones. Concretely: no PUBLIC widget class may be defined in this package
// except the `MatomeWidgetbook` entry point. Private fixtures/scenes (leading
// underscore) are allowed — they wrap real `package:matome_flutter/...` widgets.
//
// This file exposes a pure, testable scanner (`catalogWidgetViolations`) plus a
// `main()` that scans `lib/**.dart` and exits non-zero on any violation, so it
// runs as `dart run tool/catalog_provenance.dart` from apps/flutter_widgetbook.
//
// KNOWN GAP (accepted by the design council for now): a private bespoke mock is
// allowed because it is private (e.g. `_FakeAudioPlayback`). The deterministic,
// enforceable rule we ship is "no PUBLIC widget classes except the entry point";
// it intentionally does not catch a private hand-rolled reimplementation of an
// app widget. Authoring discipline (CONTRIBUTING.md) covers that softer case.

import 'dart:io';

/// Widget base classes that mark a class as a shippable UI widget.
const Set<String> kWidgetBases = {
  'StatelessWidget',
  'StatefulWidget',
  'ConsumerWidget',
  'ConsumerStatefulWidget',
  'HookWidget',
  'HookConsumerWidget',
};

/// The only PUBLIC widget class allowed to be defined in the catalog package.
const Set<String> kAllowedPublicWidgets = {'MatomeWidgetbook'};

/// Matches `class <Name> extends <Base>` at the start of a line.
final RegExp _classDecl =
    RegExp(r'^class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+([A-Za-z_][A-Za-z0-9_]*)');

/// Pure, deterministic scanner: returns a human-readable violation per PUBLIC
/// class (identifier starts with an uppercase letter, i.e. not `_`-prefixed)
/// that `extends` one of [kWidgetBases], excluding [kAllowedPublicWidgets].
///
/// Files whose path ends in `.g.dart` are ignored (generated code).
List<String> catalogWidgetViolations(Map<String, String> sourcesByPath) {
  final violations = <String>[];
  final paths = sourcesByPath.keys.toList()..sort();
  for (final path in paths) {
    if (path.endsWith('.g.dart')) continue;
    final source = sourcesByPath[path]!;
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = _classDecl.firstMatch(lines[i]);
      if (match == null) continue;
      final name = match.group(1)!;
      final base = match.group(2)!;
      if (!kWidgetBases.contains(base)) continue;
      // Private classes (leading underscore) are allowed fixtures/scenes.
      if (name.startsWith('_')) continue;
      // Lowercase-leading public identifiers cannot be a widget class name.
      final first = name[0];
      if (first.toUpperCase() != first) continue;
      if (kAllowedPublicWidgets.contains(name)) continue;
      violations.add(
        '$path:${i + 1}: public widget class `$name extends $base` is defined '
        'in the catalog. The catalog must only RENDER app widgets (import them '
        'via package:matome_flutter/...). Make it a private fixture (prefix `_`) '
        'or move it into the app. Allowed public class: '
        '${kAllowedPublicWidgets.join(', ')}.',
      );
    }
  }
  return violations;
}

Future<void> main() async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln(
      'catalog_provenance: no lib/ directory found. Run from apps/flutter_widgetbook.',
    );
    exit(2);
  }

  final sources = <String, String>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    sources[entity.path] = entity.readAsStringSync();
  }

  final violations = catalogWidgetViolations(sources);
  if (violations.isEmpty) {
    stdout.writeln('catalog provenance: OK (no public widget classes defined).');
    exit(0);
  }

  stderr.writeln('catalog provenance: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  ✗ $v');
  }
  exit(1);
}
