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

/// Private fixtures are allowed, but not when they masquerade as app-owned
/// route or journey surfaces. Use `_FooScene` / `_FooFixture` in the catalog, or
/// move the real `*Page` / `*Journey` into apps/flutter and import it.
const Set<String> kForbiddenPrivateScenarioSuffixes = {
  'Page',
  'Screen',
  'Journey',
};

/// Matches `class <Name> extends <Base>` at the start of a line.
final RegExp _classDecl = RegExp(
  r'^class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+([A-Za-z_][A-Za-z0-9_]*)',
);

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

/// Stronger provenance for the route/Page/Journey contract: Widgetbook may use
/// private fixtures, but it must not define local `*Page`, `*Screen`, or
/// `*Journey` widgets, and `[Pages]` / `[Journeys]` use-cases must not be typed
/// against a catalog-defined class.
List<String> catalogScenarioViolations(Map<String, String> sourcesByPath) {
  final violations = <String>[];
  final localWidgetClasses = <String, String>{};
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
      localWidgetClasses[name] = '$path:${i + 1}';

      if (!name.startsWith('_')) continue;
      final publicShape = name.replaceFirst(RegExp(r'^_+'), '');
      final forbidden = kForbiddenPrivateScenarioSuffixes.any(
        publicShape.endsWith,
      );
      if (forbidden) {
        violations.add(
          '$path:${i + 1}: private catalog widget `$name extends $base` looks '
          'like a shippable route/journey surface. Widgetbook may define '
          'private scenes/fixtures, but `*Page`, `*Screen`, and `*Journey` '
          'widgets must be app-owned and imported from package:matome_flutter.',
        );
      }
    }
  }

  final useCasePattern = RegExp(
    r'@widgetbook\.UseCase\(([\s\S]*?)\)\s*Widget\s+([A-Za-z0-9_]+)\s*\(',
    multiLine: true,
  );
  final pathPattern = RegExp(r'''path:\s*['"]([^'"]+)''');
  final typePattern = RegExp(r'type:\s*([A-Za-z_][A-Za-z0-9_]*)\b');

  for (final path in paths) {
    if (path.endsWith('.g.dart')) continue;
    final source = sourcesByPath[path]!;
    for (final match in useCasePattern.allMatches(source)) {
      final args = match.group(1)!;
      final storyPath = pathPattern.firstMatch(args)?.group(1) ?? '';
      final isScenarioPath =
          storyPath.startsWith('[Pages]') || storyPath.startsWith('[Journeys]');
      if (!isScenarioPath) continue;

      final typeName = typePattern.firstMatch(args)?.group(1);
      if (typeName == null) continue;
      final localAt = localWidgetClasses[typeName];
      if (localAt == null) continue;
      violations.add(
        '$path: Widgetbook use-case `${match.group(2)}` at `$storyPath` uses '
        'catalog-defined type `$typeName` ($localAt). `[Pages]` and '
        '`[Journeys]` must render app-owned Pages imported from '
        'package:matome_flutter, not local catalog UI.',
      );
    }
  }

  return violations;
}

List<String> catalogProvenanceViolations(Map<String, String> sourcesByPath) {
  return [
    ...catalogWidgetViolations(sourcesByPath),
    ...catalogScenarioViolations(sourcesByPath),
  ];
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

  final violations = catalogProvenanceViolations(sources);
  if (violations.isEmpty) {
    stdout.writeln('catalog provenance: OK (no catalog-defined shippable UI).');
    exit(0);
  }

  stderr.writeln('catalog provenance: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  ✗ $v');
  }
  exit(1);
}
