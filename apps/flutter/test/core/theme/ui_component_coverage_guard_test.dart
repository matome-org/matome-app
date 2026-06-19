import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _widgetbookExemptions = <String, String>{};
const _goldenExemptions = <String, String>{};

void main() {
  test('Widgetbook coverage requires generated runtime directories', () {
    const coverage = _WidgetbookCoverage(
      annotationSource: '@widgetbook.UseCase(type: AppCard)',
      generatedSource: "_widgetbook.WidgetbookComponent(name: 'OtherWidget')",
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
            'Add a @widgetbook.UseCase(type: ComponentName, ...) in '
            '../flutter_widgetbook/lib/widgetbook.dart, regenerate '
            'widgetbook.directories.g.dart, and keep the generated '
            'WidgetbookComponent(name: ComponentName) entry, or add a '
            'reviewed reason to _widgetbookExemptions.',
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

_WidgetbookCoverage _readWidgetbookCoverage() {
  final widgetbookSource = File('../flutter_widgetbook/lib/widgetbook.dart');
  final generatedSource = File(
    '../flutter_widgetbook/lib/widgetbook.directories.g.dart',
  );

  if (!widgetbookSource.existsSync() || !generatedSource.existsSync()) {
    fail(
      'Missing apps/flutter_widgetbook/lib/widgetbook.dart or '
      'widgetbook.directories.g.dart; Widgetbook coverage cannot run.',
    );
  }

  return _WidgetbookCoverage(
    annotationSource: widgetbookSource.readAsStringSync(),
    generatedSource: generatedSource.readAsStringSync(),
  );
}

bool _hasWidgetbookCoverage(_WidgetbookCoverage coverage, String className) {
  final typeUseCase = RegExp(
    'type:\\s*$className\\b',
    multiLine: true,
  ).hasMatch(coverage.annotationSource);
  final generatedComponent = RegExp(
    "name:\\s*'$className'",
    multiLine: true,
  ).hasMatch(coverage.generatedSource);

  return typeUseCase && generatedComponent;
}

bool _hasGoldenCoverage(String source, String className) {
  return RegExp('\\b$className\\s*(?:[.(<])').hasMatch(source);
}

void _expectValidExemptions({
  required List<_UiComponent> components,
  required Map<String, String> exemptions,
  required String coverageName,
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
        'lib/ui/** and include a documented reason of at least 12 characters.',
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
  const _WidgetbookCoverage({
    required this.annotationSource,
    required this.generatedSource,
  });

  final String annotationSource;
  final String generatedSource;
}
