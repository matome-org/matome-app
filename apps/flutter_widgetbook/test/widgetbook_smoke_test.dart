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
    label: 'files desktop',
    builder: filesPageLoadedUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'settings locale stress',
    builder: settingsPageUseCase,
    variant: _darkJapanese,
  ),
  _SmokeCase(
    label: 'capture journey',
    builder: captureJourneyUseCase,
    variant: _lightEnglish,
  ),
  _SmokeCase(
    label: 'recovery journey locale stress',
    builder: recoveryJourneyUseCase,
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
        initialRoute: '/?path=global%2Favatars%2Favatar%2Ficon-%2B-initials',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(Avatar), findsNWidgets(4));
  });

  testWidgets('critical Page use cases render without runtime errors', (
    tester,
  ) async {
    for (final builder in <WidgetBuilder>[
      filesPageLoadedUseCase,
      inboxPageEmptyUseCase,
      recordingPageUseCase,
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
      settingsPageUseCase,
      calendarPageUseCase,
      spacesPageUseCase,
      contactsPageUseCase,
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
      authJourneyUseCase,
      captureJourneyUseCase,
      organizeJourneyUseCase,
      reviewJourneyUseCase,
      recoveryJourneyUseCase,
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
