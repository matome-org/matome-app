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
        'lib/widgetbook.dart':
            'class MatomeWidgetbook extends StatelessWidget {}',
        // Generated code is ignored even when it declares a public widget.
        'lib/generated_catalog.g.dart':
            'class GeneratedThing extends StatelessWidget {}',
      });
      expect(violations, isEmpty);
    });
  });

  group('catalogScenarioViolations (unit)', () {
    test('flags private catalog widgets named like Pages or Journeys', () {
      final violations = catalogScenarioViolations({
        'lib/auth_stories.dart': 'class _LoginPage extends StatelessWidget {}',
        'lib/journey_stories.dart':
            'class _AuthJourney extends StatelessWidget {}',
      });

      expect(violations, hasLength(2));
      expect(violations.join('\n'), contains('_LoginPage'));
      expect(violations.join('\n'), contains('_AuthJourney'));
    });

    test('flags [Pages] use-cases typed against catalog-defined classes', () {
      final violations = catalogScenarioViolations({
        'lib/auth_stories.dart': '''
class _LoginScene extends StatelessWidget {}

@widgetbook.UseCase(name: 'Login', type: _LoginScene, path: '[Pages]/Auth')
Widget loginPageUseCase(BuildContext context) => const _LoginScene();
''',
      });

      expect(violations, hasLength(1));
      expect(violations.single, contains('[Pages]/Auth'));
      expect(violations.single, contains('_LoginScene'));
    });

    test('allows private scenes outside Pages/Journeys', () {
      final violations = catalogScenarioViolations({
        'lib/component_stories.dart': '''
class _LoginScene extends StatelessWidget {}

@widgetbook.UseCase(name: 'Login scene', type: AuthScaffold, path: '[Components]/Auth')
Widget loginSceneUseCase(BuildContext context) => const _LoginScene();
''',
      });

      expect(violations, isEmpty);
    });
  });

  group('catalogTaxonomyViolations (unit)', () {
    test('flags flat Global paths and docs-less components', () {
      final violations = catalogTaxonomyViolations({
        'lib/widgetbook.dart': '''
final matomeWidgetbookComponents = [
  _component(
    name: 'PrimaryButton',
    path: 'Global/Buttons',
    stories: [const _StorySpec('Primary states', primaryButtonsUseCase)],
  ),
  _component(
    name: 'RouteFrame',
    path: 'Frames',
    docs: 'Frame docs.',
    stories: [const _StorySpec('Route surface', routeFrameUseCase)],
  ),
  _component(
    name: 'Auth',
    path: 'Journeys/Mobile',
    docs: 'Journey order: 1 WelcomePage -> 2 LoginPage.',
    stories: [const _StorySpec('Welcome', authJourneyWelcomeStepUseCase)],
  ),
  _component(
    name: 'Auth',
    path: 'Journeys/Desktop',
    docs: 'Journey order: 1 WelcomePage -> 2 LoginPage.',
    stories: [const _StorySpec('Welcome', authJourneyWelcomeStepUseCase)],
  ),
];
''',
      });

      expect(violations.join('\n'), contains('Global/Buttons'));
      expect(violations.join('\n'), contains('has no native docs'));
    });

    test('flags aggregate journey stories', () {
      final violations = catalogTaxonomyViolations({
        'lib/widgetbook.dart': '''
final matomeWidgetbookComponents = [
  _component(
    name: 'PrimaryButton',
    path: 'Components/Atoms/Buttons',
    docs: 'Button docs.',
    stories: [const _StorySpec('Primary states', primaryButtonsUseCase)],
  ),
  _component(
    name: 'AppCard',
    path: 'Components/Composite/Cards',
    docs: 'Card docs.',
    stories: [const _StorySpec('Done', appCardDoneUseCase)],
  ),
  _component(
    name: 'RouteFrame',
    path: 'Frames',
    docs: 'Frame docs.',
    stories: [const _StorySpec('Route surface', routeFrameUseCase)],
  ),
  _component(
    name: 'Auth',
    path: 'Journeys/Mobile',
    docs: 'Journey order: 1 WelcomePage -> 2 LoginPage.',
    stories: [const _StorySpec('Welcome -> Login', authJourneyUseCase)],
  ),
];
''',
      });

      expect(violations.join('\n'), contains('aggregate `*JourneyUseCase`'));
    });

    test('flags journey step components instead of step stories', () {
      final violations = catalogTaxonomyViolations({
        'lib/widgetbook.dart': '''
final matomeWidgetbookComponents = [
  _component(
    name: 'PrimaryButton',
    path: 'Components/Atoms/Buttons',
    docs: 'Button docs.',
    stories: [const _StorySpec('Primary states', primaryButtonsUseCase)],
  ),
  _component(
    name: 'AppCard',
    path: 'Components/Composite/Cards',
    docs: 'Card docs.',
    stories: [const _StorySpec('Done', appCardDoneUseCase)],
  ),
  _component(
    name: 'RouteFrame',
    path: 'Frames',
    docs: 'Frame docs.',
    stories: [const _StorySpec('Route surface', routeFrameUseCase)],
  ),
  _component(
    name: '01 WelcomePage',
    path: 'Journeys/Mobile/Auth',
    docs: 'Journey order: 1 WelcomePage -> 2 LoginPage.',
    stories: [const _StorySpec('Welcome', authJourneyWelcomeStepUseCase)],
  ),
];
''',
      });

      expect(violations.join('\n'), contains('directly under'));
      expect(violations.join('\n'), contains('registered as a component'));
    });

    test('allows the required Widgetbook 4 taxonomy shape', () {
      final violations = catalogTaxonomyViolations({
        'lib/widgetbook.dart': '''
final matomeWidgetbookComponents = [
  _component(
    name: 'PrimaryButton',
    path: 'Components/Atoms/Buttons',
    docs: 'Button docs.',
    stories: [const _StorySpec('Primary states', primaryButtonsUseCase)],
  ),
  _component(
    name: 'AppCard',
    path: 'Components/Composite/Cards',
    docs: 'Card docs.',
    stories: [const _StorySpec('Done', appCardDoneUseCase)],
  ),
  _component(
    name: 'RouteFrame',
    path: 'Frames',
    docs: 'Frame docs.',
    stories: [const _StorySpec('Route surface', routeFrameUseCase)],
  ),
  _component(
    name: 'Auth',
    path: 'Journeys/Mobile',
    docs: 'Journey order: 1 WelcomePage -> 2 LoginPage.',
    stories: const [
      _StorySpec('01 WelcomePage', authJourneyWelcomeStepUseCase),
      _StorySpec('02 LoginPage', authJourneyLoginStepUseCase),
    ],
  ),
  _component(
    name: 'Auth',
    path: 'Journeys/Desktop',
    docs: 'Journey order: 1 WelcomePage -> 2 LoginPage.',
    stories: const [
      _StorySpec('01 WelcomePage', authJourneyWelcomeDesktopStepUseCase),
      _StorySpec('02 LoginPage', authJourneyLoginDesktopStepUseCase),
    ],
  ),
];
''',
      });

      expect(violations, isEmpty);
    });
  });

  test(
    'real apps/flutter_widgetbook/lib has zero violations (integration)',
    () {
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

      final violations = catalogProvenanceViolations(sources);
      expect(
        violations,
        isEmpty,
        reason: 'catalog defines public widget(s):\n${violations.join('\n')}',
      );
    },
  );
}
