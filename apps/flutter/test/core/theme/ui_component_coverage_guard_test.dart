import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _widgetbookExemptions = <String, String>{};
const _goldenExemptions = <String, String>{};

/// Allow-list escape hatch for PUBLIC presentational widgets under
/// lib/features/** that the Widgetbook-coverage rule would otherwise require a
/// use-case for. Each entry MUST carry a documented reason of >= 12 characters.
/// This is the SAME pattern as [_widgetbookExemptions] for lib/ui, kept so a
/// genuine exception (never a "skip the work" entry) has a reviewed home.
///
/// Today this is intentionally EMPTY: every uncovered presentational feature
/// widget got a real use-case (#1477) rather than an allow-list line.
const _featureWidgetbookExemptions = <String, String>{};

void main() {
  test('Widgetbook coverage requires a registry component entry', () {
    const coverage = _WidgetbookCoverage(
      source: "_component(name: 'OtherWidget', path: 'Components/Atoms/Test')",
    );

    expect(_hasWidgetbookCoverage(coverage, 'AppCard'), isFalse);
  });

  test('lib/ui widgets have Widgetbook and shared golden coverage', () {
    final components = _discoverUiComponents();
    expect(
      components,
      isNotEmpty,
      reason: 'Expected to discover public Widget classes in lib/ui/**.',
    );

    _expectValidExemptions(
      components: components,
      exemptions: _widgetbookExemptions,
      coverageName: 'Widgetbook',
    );
    _expectValidExemptions(
      components: components,
      exemptions: _goldenExemptions,
      coverageName: 'shared golden',
    );

    final widgetbookCoverage = _readWidgetbookCoverage();
    final missingWidgetbook = components
        .where(
          (component) =>
              !_widgetbookExemptions.containsKey(component.className) &&
              !_hasWidgetbookCoverage(widgetbookCoverage, component.className),
        )
        .toList();

    expect(
      missingWidgetbook,
      isEmpty,
      reason: _coverageFailure(
        title: 'Missing Widgetbook coverage for lib/ui widgets.',
        components: missingWidgetbook,
        remediation:
            'Add a Widgetbook 4 `_component(name: ComponentName, ...)` entry '
            'in ../flutter_widgetbook/lib/widgetbook.dart, including native '
            'docs and a representative story, or add a reviewed reason to '
            '_widgetbookExemptions.',
      ),
    );

    final goldenSource = File(
      'test/goldens/shared_widgets_golden_test.dart',
    ).readAsStringSync();
    final missingGolden = components
        .where(
          (component) =>
              !_goldenExemptions.containsKey(component.className) &&
              !_hasGoldenCoverage(goldenSource, component.className),
        )
        .toList();

    expect(
      missingGolden,
      isEmpty,
      reason: _coverageFailure(
        title: 'Missing shared visual regression coverage for lib/ui widgets.',
        components: missingGolden,
        remediation:
            'Render the component in test/goldens/shared_widgets_golden_test.dart '
            'or add a reviewed reason to _goldenExemptions.',
      ),
    );
  });

  test(
    'presentational feature widgets (lib/features/**) have Widgetbook coverage',
    () {
      // OWNER DIRECTIVE (#1477): ALL presentational feature widgets must live in
      // Widgetbook, enforced here. This test was added RED — before the matching
      // component stories landed it failed listing AudioPlayerBar, AuthField,
      // AuthScaffold, AuthSubmitButton, FileActionsMenu, FilesBulkBar,
      // FilesEmptyState, FilesMutedDash, FilesUndoBar, MatomeActionsMenu — and
      // turns GREEN once each has a real Widgetbook component rendering the REAL
      // widget. (Widgets already covered before #1477 — e.g. ContactDetail,
      // FileView, FilesGrid/Table, MatomeTable, the nav trio — keep passing.)
      //
      // RULE (BEHAVIOR-based, not directory-based — so a presentational widget
      // sitting OUTSIDE a /widgets folder is still caught):
      //   INCLUDE a public class iff it `extends StatelessWidget` or
      //   `StatefulWidget` AND its name does NOT end in `Screen`.
      //   EXCLUDE provider-bound widgets (`extends ConsumerWidget` /
      //   `ConsumerStatefulWidget`) and `*Screen` classes. Those need fake
      //   providers / full app scaffolding to render and are tracked as the
      //   SEPARATE screens-coverage effort — they are excluded BY THE RULE, not
      //   silently allow-listed.
      //
      // GOLDEN DECISION (#1477): the shared visual-regression (golden) suite
      // requirement stays lib/ui-ONLY. Feature widgets require a use-case but
      // NOT a shared golden. Rationale: lib/ui is the bounded primitive layer
      // (~25 widgets) whose pixels are the design-system contract; feature
      // widgets compose those primitives and are far more numerous, so gating
      // every one on a golden would balloon the golden suite (and its
      // maintenance/flake surface) without adding contract coverage the
      // primitive goldens don't already give. Documented states live in the
      // Widgetbook catalog instead; promote a feature widget into the golden
      // suite case-by-case when its composition itself is load-bearing (as
      // FileView already is).
      final components = _discoverFeatureComponents();
      expect(
        components,
        isNotEmpty,
        reason:
            'Expected to discover public presentational Widget classes under '
            'lib/features/** (non-Consumer, non-*Screen).',
      );

      _expectValidExemptions(
        components: components,
        exemptions: _featureWidgetbookExemptions,
        coverageName: 'feature Widgetbook',
        scopeLabel: 'lib/features/**',
      );

      final widgetbookCoverage = _readWidgetbookCoverage();
      final missingWidgetbook = components
          .where(
            (component) =>
                !_featureWidgetbookExemptions.containsKey(
                  component.className,
                ) &&
                !_hasWidgetbookCoverage(
                  widgetbookCoverage,
                  component.className,
                ),
          )
          .toList();

      expect(
        missingWidgetbook,
        isEmpty,
        reason: _coverageFailure(
          title:
              'Missing Widgetbook coverage for presentational feature widgets.',
          components: missingWidgetbook,
          remediation:
              'Add a Widgetbook 4 `_component(name: ComponentName, ...)` story '
              'rendering the REAL widget with representative sample data in '
              '../flutter_widgetbook/lib/widgetbook.dart, or — only for a '
              'genuine exception — add a reviewed reason to '
              '_featureWidgetbookExemptions. Provider-bound (Consumer*) widgets '
              'and *Screen classes are out of scope and should be left as such, '
              'not allow-listed.',
        ),
      );
    },
  );

  test('Widgetbook dependencies stay isolated from matome_flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final productionSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final widgetbookImports = productionSources
        .where((file) => file.readAsStringSync().contains("package:widgetbook"))
        .map((file) => file.path)
        .toList();

    expect(
      RegExp(
        r'^\s*widgetbook(?:_annotation|_generator)?:',
        multiLine: true,
      ).hasMatch(pubspec),
      isFalse,
      reason:
          'Widgetbook packages belong in apps/flutter_widgetbook, not the '
          'production apps/flutter pubspec.',
    );
    expect(
      widgetbookImports,
      isEmpty,
      reason:
          'Production lib/** must not import Widgetbook APIs: $widgetbookImports',
    );
  });
}

List<_UiComponent> _discoverUiComponents() {
  final files =
      Directory('lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .where((file) => !file.path.endsWith('.freezed.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final file in files)
      for (final className in _publicWidgetClasses(file.readAsStringSync()))
        _UiComponent(className: className, path: file.path),
  ];
}

List<String> _publicWidgetClasses(String source) {
  return RegExp(
    r'class\s+([A-Z][A-Za-z0-9_]*)(?:<[^>]+>)?\s+extends\s+'
    r'(?:StatelessWidget|StatefulWidget)\b',
  ).allMatches(source).map((match) => match.group(1)!).toList();
}

/// Discovers PUBLIC presentational widgets under lib/features/** using the
/// behavior-based rule (#1477): a class that `extends StatelessWidget` /
/// `StatefulWidget` (NOT a Consumer*) whose name does not end in `Screen`.
/// Provider-bound widgets (`ConsumerWidget`/`ConsumerStatefulWidget`) and
/// `*Screen` classes are excluded by construction — they belong to the separate
/// screens-coverage effort.
List<_UiComponent> _discoverFeatureComponents() {
  final files =
      Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .where((file) => !file.path.endsWith('.freezed.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  return [
    for (final file in files)
      for (final className in _publicWidgetClasses(file.readAsStringSync()))
        // Behavior-based exclusion: *Screen classes are screens, not catalog
        // components, regardless of which base they extend.
        if (!className.endsWith('Screen'))
          _UiComponent(className: className, path: file.path),
  ];
}

_WidgetbookCoverage _readWidgetbookCoverage() {
  final widgetbookSource = File('../flutter_widgetbook/lib/widgetbook.dart');

  if (!widgetbookSource.existsSync()) {
    fail(
      'Missing apps/flutter_widgetbook/lib/widgetbook.dart; Widgetbook coverage '
      'cannot run.',
    );
  }

  return _WidgetbookCoverage(source: widgetbookSource.readAsStringSync());
}

bool _hasWidgetbookCoverage(_WidgetbookCoverage coverage, String className) {
  final typeUseCase = RegExp(
    "name:\\s*'${RegExp.escape(className)}'",
    multiLine: true,
  );

  return _componentBlocks(coverage.source).any(typeUseCase.hasMatch);
}

List<String> _componentBlocks(String source) {
  final lines = source.split('\n');
  final blocks = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('  _component(')) continue;
    final buffer = StringBuffer(lines[i]);
    i++;
    while (i < lines.length && !lines[i].startsWith('  ),')) {
      buffer.writeln(lines[i]);
      i++;
    }
    if (i < lines.length) buffer.writeln(lines[i]);
    blocks.add(buffer.toString());
  }
  return blocks;
}

bool _hasGoldenCoverage(String source, String className) {
  return RegExp('\\b$className\\s*(?:[.(<])').hasMatch(source);
}

void _expectValidExemptions({
  required List<_UiComponent> components,
  required Map<String, String> exemptions,
  required String coverageName,
  String scopeLabel = 'lib/ui/**',
}) {
  final componentNames = components
      .map((component) => component.className)
      .toSet();
  final invalid = exemptions.entries
      .where(
        (entry) =>
            !componentNames.contains(entry.key) ||
            entry.value.trim().length < 12,
      )
      .map((entry) => '${entry.key}: ${entry.value}')
      .toList();

  expect(
    invalid,
    isEmpty,
    reason:
        '$coverageName exemptions must name a current public Widget class in '
        '$scopeLabel and include a documented reason of at least 12 characters.',
  );
}

String _coverageFailure({
  required String title,
  required List<_UiComponent> components,
  required String remediation,
}) {
  return [
    title,
    remediation,
    ...components.map(
      (component) => '- ${component.className} (${component.relativePath})',
    ),
  ].join('\n');
}

class _UiComponent {
  const _UiComponent({required this.className, required this.path});

  final String className;
  final String path;

  String get relativePath =>
      path.replaceFirst('${Directory.current.path}/', '');

  @override
  String toString() => '$className ($relativePath)';
}

class _WidgetbookCoverage {
  const _WidgetbookCoverage({required this.source});

  final String source;
}
