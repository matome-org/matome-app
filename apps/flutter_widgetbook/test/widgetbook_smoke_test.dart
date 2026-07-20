import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/avatar.dart';
import 'package:matome_widgetbook/widgetbook.dart';

Widget _useCaseHost(WidgetBuilder builder, {_SmokeVariant? variant}) {
  final selected = variant ?? _lightEnglish;
  LocaleSettings.setLocaleSync(selected.locale);
  return TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: selected.theme,
      locale: selected.locale.flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: builder),
    ),
  );
}

final _lightEnglish = _SmokeVariant(
  label: 'light / en',
  locale: AppLocale.en,
  theme: buildLightTheme(),
);

final _darkJapanese = _SmokeVariant(
  label: 'dark / ja',
  locale: AppLocale.ja,
  theme: buildDarkTheme(),
);

final _pageJourneyMatrix = <_SmokeCase>[
  _SmokeCase(
    label: 'auth mobile',
    builder: welcomePageMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'auth desktop locale stress',
    builder: loginPageDesktopUseCase,
    variant: _darkJapanese,
  ),
  _SmokeCase(
    label: 'login invalid credentials',
    builder: loginPageInvalidMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'signup email taken locale stress',
    builder: signupPageEmailTakenDesktopUseCase,
    variant: _darkJapanese,
  ),
  _SmokeCase(
    label: 'files desktop',
    builder: filesPageDesktopUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'files empty mobile',
    builder: filesPageEmptyMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'files error desktop',
    builder: filesPageErrorDesktopUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'inbox loading mobile',
    builder: inboxPageLoadingMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'inbox populated desktop',
    builder: inboxPagePopulatedDesktopUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'matome detail loaded mobile',
    builder: matomeDetailLoadedMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'text item clean mobile',
    builder: textItemPageCleanMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'text item pending offline desktop',
    builder: textItemPagePendingDesktopUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'text item processing mobile',
    builder: textItemPageProcessingMobileUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'text item retryable failure desktop',
    builder: textItemPageFailureDesktopUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'text item version conflict locale stress',
    builder: textItemPageConflictMobileUseCase,
    variant: _darkJapanese,
  ),
  _SmokeCase(
    label: 'settings locale stress',
    builder: settingsPageDesktopUseCase,
    variant: _darkJapanese,
  ),
  _SmokeCase(
    label: 'capture mobile journey step',
    builder: captureJourneyInboxStepUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'capture desktop journey step',
    builder: captureJourneyInboxDesktopStepUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'recovery mobile journey locale stress',
    builder: recoveryJourneyFilesStepUseCase,
    variant: _darkJapanese,
  ),
  _SmokeCase(
    label: 'recovery desktop journey locale stress',
    builder: recoveryJourneyFilesDesktopStepUseCase,
    variant: _darkJapanese,
  ),
];

class _SmokeVariant {
  const _SmokeVariant({
    required this.label,
    required this.locale,
    required this.theme,
  });

  final String label;
  final AppLocale locale;
  final ThemeData theme;
}

class _SmokeCase {
  const _SmokeCase({
    required this.label,
    required this.builder,
    required this.variant,
  });

  final String label;
  final WidgetBuilder builder;
  final _SmokeVariant variant;
}

String _docsRouteFor(String path, String componentName) {
  return '/?path=${Uri.encodeComponent('$path/$componentName/Docs')}';
}

void main() {
  testWidgets('Widgetbook shell renders without runtime errors', (
    tester,
  ) async {
    await tester.pumpWidget(const MatomeWidgetbook());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Avatar use case renders without runtime errors', (tester) async {
    await tester.pumpWidget(
      const MatomeWidgetbook(
        initialRoute:
            '/?path=Components%2FAtoms%2FAvatars%2FAvatar%2FIcon%20%2B%20initials',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(Avatar), findsNWidgets(4));
  });

  testWidgets('component docs render visible story previews', (tester) async {
    await tester.pumpWidget(
      const MatomeWidgetbook(
        initialRoute: '/?path=Components%2FComposite%2FCards%2FAppCard%2FDocs',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Calendar row'), findsWidgets);
    expect(find.text('Roadmap review'), findsWidgets);
  });

  test('journeys are components with ordered step stories', () {
    final mobileJourneyComponents = matomeWidgetbookComponents
        .where((component) => component.path == 'Journeys/Mobile')
        .toList();
    final desktopJourneyComponents = matomeWidgetbookComponents
        .where((component) => component.path == 'Journeys/Desktop')
        .toList();
    final oldStepComponents = matomeWidgetbookComponents.where(
      (component) =>
          component.path == 'Journey' ||
          component.path.startsWith('Journey/') ||
          component.path.startsWith('Journeys/Mobile/') ||
          component.path.startsWith('Journeys/Desktop/'),
    );

    expect(oldStepComponents, isEmpty);
    expect(
      mobileJourneyComponents.map((component) => component.name),
      containsAll(['Auth', 'Capture', 'Organize', 'Review', 'Recovery']),
    );
    expect(
      desktopJourneyComponents.map((component) => component.name),
      containsAll(['Auth', 'Capture', 'Organize', 'Review', 'Recovery']),
    );
    expect(
      mobileJourneyComponents
          .singleWhere((component) => component.name == 'Auth')
          .stories
          .map((story) => story.name),
      ['01 WelcomePage', '02 LoginPage', '03 SignupPage'],
    );
    expect(
      desktopJourneyComponents
          .singleWhere((component) => component.name == 'Auth')
          .stories
          .map((story) => story.name),
      ['01 WelcomePage', '02 LoginPage', '03 SignupPage'],
    );
  });

  testWidgets('journey docs render all step previews under one docs node', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MatomeWidgetbook(
        initialRoute: '/?path=Journeys%2FMobile%2FAuth%2FDocs',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('01 WelcomePage'), findsWidgets);
    expect(find.text('02 LoginPage'), findsWidgets);
    expect(find.text('03 SignupPage'), findsWidgets);
    expect(find.text('Create account'), findsWidgets);

    await tester.pumpWidget(
      const MatomeWidgetbook(
        initialRoute: '/?path=Journeys%2FDesktop%2FAuth%2FDocs',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('01 WelcomePage'), findsWidgets);
    expect(find.text('02 LoginPage'), findsWidgets);
    expect(find.text('03 SignupPage'), findsWidgets);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('all journey docs render without provider or viewport errors', (
    tester,
  ) async {
    final journeyComponents = matomeWidgetbookComponents
        .where(
          (component) =>
              component.path == 'Journeys/Mobile' ||
              component.path == 'Journeys/Desktop',
        )
        .toList();

    expect(journeyComponents, hasLength(10));

    for (final component in journeyComponents) {
      final route = _docsRouteFor(component.path, component.name);

      await tester.pumpWidget(MatomeWidgetbook(initialRoute: route));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull, reason: route);
      expect(find.byType(ErrorWidget, skipOffstage: false), findsNothing);
      for (final story in component.stories) {
        expect(find.text(story.name), findsWidgets, reason: route);
      }

      if (component.path == 'Journeys/Mobile' &&
          (component.name == 'Capture' || component.name == 'Organize')) {
        expect(
          find.text('Select a matome to preview'),
          findsNothing,
          reason: '$route should stay in compact mobile layout',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('critical Page use cases render without runtime errors', (
    tester,
  ) async {
    for (final builder in <WidgetBuilder>[
      filesPageDesktopUseCase,
      inboxPageMobileUseCase,
      recordingPageMobileUseCase,
    ]) {
      await tester.pumpWidget(_useCaseHost(builder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('secondary Page use cases render without runtime errors', (
    tester,
  ) async {
    for (final builder in <WidgetBuilder>[
      settingsPageMobileUseCase,
      calendarPageMobileUseCase,
      spacesPageMobileUseCase,
      contactsPageMobileUseCase,
    ]) {
      await tester.pumpWidget(_useCaseHost(builder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('critical Journey use cases render without runtime errors', (
    tester,
  ) async {
    for (final builder in <WidgetBuilder>[
      authJourneyWelcomeStepUseCase,
      authJourneyWelcomeDesktopStepUseCase,
      captureJourneyCaptureStepUseCase,
      captureJourneyCaptureDesktopStepUseCase,
      captureJourneyInboxStepUseCase,
      captureJourneyInboxDesktopStepUseCase,
      captureJourneyMatomeStepUseCase,
      captureJourneyMatomeDesktopStepUseCase,
      organizeJourneyInboxStepUseCase,
      organizeJourneyInboxDesktopStepUseCase,
      organizeJourneyMatomeStepUseCase,
      organizeJourneyMatomeDesktopStepUseCase,
      organizeJourneySpaceStepUseCase,
      organizeJourneySpaceDesktopStepUseCase,
      reviewJourneyFilesStepUseCase,
      reviewJourneyFilesDesktopStepUseCase,
      reviewJourneyAudioStepUseCase,
      reviewJourneyAudioDesktopStepUseCase,
      recoveryJourneySettingsStepUseCase,
      recoveryJourneySettingsDesktopStepUseCase,
      recoveryJourneyInboxStepUseCase,
      recoveryJourneyInboxDesktopStepUseCase,
      recoveryJourneyFilesStepUseCase,
      recoveryJourneyFilesDesktopStepUseCase,
    ]) {
      await tester.pumpWidget(_useCaseHost(builder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('bounded Page/Journey visual smoke matrix renders', (
    tester,
  ) async {
    for (final smokeCase in _pageJourneyMatrix) {
      await tester.pumpWidget(
        _useCaseHost(smokeCase.builder, variant: smokeCase.variant),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.takeException(),
        isNull,
        reason: '${smokeCase.label} (${smokeCase.variant.label})',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
