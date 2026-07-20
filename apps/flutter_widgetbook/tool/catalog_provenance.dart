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

/// Taxonomy guard for the Widgetbook 4 manual component registry.
///
/// The catalog registry must expose `Components/Atoms`, `Components/Composite`,
/// `Frames`, and journey-level `Journeys/Mobile` + `Journeys/Desktop` components
/// whose stories are the ordered steps. Every component must provide native
/// Widgetbook docs via the required `_component(docs: ...)` argument.
///
/// It also enforces the design-system dependency lattice on the tree shape:
/// `Pages`, `Screens`, and `Frames` stories must use exactly one device group
/// (`Mobile` or `Desktop`) with no intermediate feature folder.
List<String> catalogTaxonomyViolations(Map<String, String> sourcesByPath) {
  final violations = <String>[];
  final componentCalls =
      <({String path, String name, String body, String at})>[];
  final paths = sourcesByPath.keys.toList()..sort();

  for (final sourcePath in paths) {
    if (sourcePath.endsWith('.g.dart')) continue;
    final source = sourcesByPath[sourcePath]!;
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('  _component(')) continue;

      final start = i;
      final buffer = StringBuffer(lines[i]);
      i++;
      while (i < lines.length && !lines[i].startsWith('  ),')) {
        buffer.writeln(lines[i]);
        i++;
      }
      if (i < lines.length) buffer.writeln(lines[i]);

      final body = buffer.toString();
      final path = RegExp(r"path:\s*'([^']+)'").firstMatch(body)?.group(1);
      final name = RegExp(r"name:\s*'([^']+)'").firstMatch(body)?.group(1);
      if (path == null || name == null) {
        violations.add(
          '$sourcePath:${start + 1}: `_component` must declare literal `name` '
          'and `path` fields so the catalog taxonomy remains guardable.',
        );
        continue;
      }
      componentCalls.add((
        path: path,
        name: name,
        body: body,
        at: '$sourcePath:${start + 1}',
      ));
    }
  }

  if (componentCalls.isEmpty) {
    return ['No Widgetbook `_component(...)` registry entries were found.'];
  }

  var hasComponentsAtoms = false;
  var hasComponentsComposite = false;
  var hasFrames = false;
  var hasMobileJourney = false;
  var hasDesktopJourney = false;

  for (final component in componentCalls) {
    final path = component.path;
    if (!component.body.contains('docs:')) {
      violations.add(
        '${component.at}: component `${component.name}` at `$path` has no '
        'native docs. Pass a non-empty `_component(docs: ...)` body.',
      );
    }

    if (path.startsWith('Components/') || path.startsWith('Global/')) {
      final isAtoms = path.startsWith('Components/Atoms/');
      final isComposite = path.startsWith('Components/Composite/');
      hasComponentsAtoms = hasComponentsAtoms || isAtoms;
      hasComponentsComposite = hasComponentsComposite || isComposite;
      if (!isAtoms && !isComposite) {
        violations.add(
          '${component.at}: component `${component.name}` uses `$path`. '
          'Reusable components must live under `Components/Atoms/...` or '
          '`Components/Composite/...` (legacy `Global/*` is retired).',
        );
      }
    }

    hasFrames = hasFrames || path == 'Frames' || path.startsWith('Frames/');

    // Device-group lattice: Pages/Screens/Frames derive from lower layers and
    // are browsed by viewport. Each must be exactly `<Section>/Mobile` or
    // `<Section>/Desktop` — no intermediate feature folder (fold it into the
    // component/story name).
    if (path.startsWith('Pages/') ||
        path.startsWith('Screens/') ||
        path.startsWith('Frames/')) {
      final section = path.split('/').first;
      if (!RegExp('^$section/(Mobile|Desktop)\$').hasMatch(path)) {
        violations.add(
          '${component.at}: `${component.name}` uses `$path`. `$section` stories '
          'must use exactly one device group: `$section/Mobile` or '
          '`$section/Desktop`, with no intermediate feature folder. Fold the '
          'feature into the component or story name.',
        );
      }
    }

    if (path == 'Journey' || path.startsWith('Journey/')) {
      violations.add(
        '${component.at}: journey component `${component.name}` uses legacy '
        'singular `$path`. Use `Journeys/Mobile` or `Journeys/Desktop`.',
      );
    }

    if (path == 'Journeys' || path.startsWith('Journeys/')) {
      final isMobile = path == 'Journeys/Mobile';
      final isDesktop = path == 'Journeys/Desktop';
      hasMobileJourney = hasMobileJourney || isMobile;
      hasDesktopJourney = hasDesktopJourney || isDesktop;
      if (!isMobile && !isDesktop) {
        violations.add(
          '${component.at}: journey component `${component.name}` uses `$path`. '
          'Journey components must live directly under `Journeys/Mobile` or '
          '`Journeys/Desktop`; put ordered step screens in that component\'s '
          '`_StorySpec(...)` list.',
        );
      }
      if (RegExp(r'^\d{2}\s').hasMatch(component.name)) {
        violations.add(
          '${component.at}: journey step `${component.name}` is registered as a '
          'component. Register the journey flow as the component and make this '
          'screen an ordered `_StorySpec(...)` story instead.',
        );
      }
      if (!component.body.contains('Journey order:')) {
        violations.add(
          '${component.at}: journey component `${component.name}` at `$path` '
          'must document the sequence in its docs body.',
        );
      }
      if (RegExp(r'\b\w+JourneyUseCase\b').hasMatch(component.body)) {
        violations.add(
          '${component.at}: journey component `${component.name}` references an '
          'aggregate `*JourneyUseCase`. Split the flow into per-screen step '
          'stories instead.',
        );
      }
    }
  }

  if (!hasComponentsAtoms) {
    violations.add(
      'Widgetbook taxonomy is missing `Components/Atoms/...` entries.',
    );
  }
  if (!hasComponentsComposite) {
    violations.add(
      'Widgetbook taxonomy is missing `Components/Composite/...` entries.',
    );
  }
  if (!hasFrames) {
    violations.add('Widgetbook taxonomy is missing the `Frames` section.');
  }
  if (!hasMobileJourney) {
    violations.add('Widgetbook taxonomy is missing `Journeys/Mobile` entries.');
  }
  if (!hasDesktopJourney) {
    violations.add('Widgetbook taxonomy is missing `Journeys/Desktop` entries.');
  }

  return violations;
}

List<String> catalogProvenanceViolations(Map<String, String> sourcesByPath) {
  return [
    ...catalogWidgetViolations(sourcesByPath),
    ...catalogScenarioViolations(sourcesByPath),
    ...catalogTaxonomyViolations(sourcesByPath),
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
