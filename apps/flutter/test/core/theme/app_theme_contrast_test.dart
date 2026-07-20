import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';

void main() {
  group('MatomeColors contrast audit', () {
    test('light tokens clear AA on light surfaces', () {
      const colors = MatomeColors.light;
      final tokens = <String, Color>{
        'textPrimary': colors.textPrimary,
        'textSecondary': colors.textSecondary,
        'textMuted': colors.textMuted,
        'failed': colors.failed,
        'badgeWorkText': colors.badgeWorkText,
        'badgePersonal': colors.badgePersonal,
        'badgeIdeas': colors.badgeIdeas,
        'badgeDefault': colors.badgeDefault,
      };

      for (final MapEntry(:key, :value) in tokens.entries) {
        expect(
          _contrastRatio(value, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$key must clear AA on MatomeColors.light.surface',
        );
      }
    });

    test('dark tokens clear AA on both dark surfaces', () {
      const colors = MatomeColors.dark;
      final tokens = <String, Color>{
        'textPrimary': colors.textPrimary,
        'textSecondary': colors.textSecondary,
        'textMuted': colors.textMuted,
        'failed': colors.failed,
        'badgeWork': colors.badgeWork,
        'badgePersonal': colors.badgePersonal,
        'badgeIdeas': colors.badgeIdeas,
        'badgeDefault': colors.badgeDefault,
      };

      for (final MapEntry(:key, :value) in tokens.entries) {
        expect(
          _contrastRatio(value, colors.background),
          greaterThanOrEqualTo(4.5),
          reason: '$key must clear AA on MatomeColors.dark.background',
        );
        expect(
          _contrastRatio(value, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$key must clear AA on MatomeColors.dark.surface',
        );
      }
    });

    test('filled control foregrounds clear AA in both themes', () {
      final pairs = <String, ({Color foreground, Color background})>{
        'light textPrimary fill': (
          foreground: MatomeColors.light.onTextPrimary,
          background: MatomeColors.light.textPrimary,
        ),
        'dark textPrimary fill': (
          foreground: MatomeColors.dark.onTextPrimary,
          background: MatomeColors.dark.textPrimary,
        ),
        'light accent fill': (
          foreground: MatomeColors.light.onAccent,
          background: MatomeColors.light.accent,
        ),
        'dark accent fill': (
          foreground: MatomeColors.dark.onAccent,
          background: MatomeColors.dark.accent,
        ),
      };

      for (final MapEntry(:key, :value) in pairs.entries) {
        expect(
          _contrastRatio(value.foreground, value.background),
          greaterThanOrEqualTo(4.5),
          reason: '$key must clear AA for filled controls',
        );
      }
    });

    test('badge resolvers return theme tokens', () {
      expect(badgeColor('Work'), MatomeColors.light.badgeWork);
      expect(badgeColor('Personal'), MatomeColors.light.badgePersonal);
      expect(badgeColor('Ideas'), MatomeColors.light.badgeIdeas);
      expect(badgeColor('Inbox'), MatomeColors.light.badgeDefault);
      expect(badgeColor(null), MatomeColors.light.badgeDefault);

      expect(badgeColorDark('Work'), MatomeColors.dark.badgeWork);
      expect(badgeColorDark('Personal'), MatomeColors.dark.badgePersonal);
      expect(badgeColorDark('Ideas'), MatomeColors.dark.badgeIdeas);
      expect(badgeColorDark('Inbox'), MatomeColors.dark.badgeDefault);
      expect(badgeColorDark(null), MatomeColors.dark.badgeDefault);
    });
  });

  group('ThemeExtension foundation', () {
    testWidgets('light theme exposes all extensions through Theme.of', (
      tester,
    ) async {
      late ThemeData theme;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      _expectFoundationExtensions(theme, MatomeColors.light);
    });

    testWidgets('dark theme exposes all extensions through Theme.of', (
      tester,
    ) async {
      late ThemeData theme;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      _expectFoundationExtensions(theme, MatomeColors.dark);
    });

    test('MatomeColors lerps every field', () {
      final midpoint = MatomeColors.light.lerp(MatomeColors.dark, 0.5);
      final lightFields = _matomeColorFields(MatomeColors.light);
      final darkFields = _matomeColorFields(MatomeColors.dark);
      final midpointFields = _matomeColorFields(midpoint);

      for (final MapEntry(:key, :value) in lightFields.entries) {
        expect(
          midpointFields[key],
          Color.lerp(value, darkFields[key]!, 0.5),
          reason: '$key must interpolate from light to dark',
        );
      }
    });

    test('space palette resolves through MatomeColors', () {
      expect(MatomeColors.light.spaceColor(0), MatomeColors.light.spaceGold);
      expect(MatomeColors.light.spaceColor(7), MatomeColors.light.spaceRed);
      expect(MatomeColors.light.spaceColor(8), MatomeColors.light.spaceGold);
      expect(MatomeColors.dark.spaceColor(1), MatomeColors.dark.spaceGreen);
    });
  });
}

void _expectFoundationExtensions(ThemeData theme, MatomeColors expectedColors) {
  final colors = theme.extension<MatomeColors>();
  expect(colors, isNotNull);
  expect(colors!.background, expectedColors.background);
  expect(colors.surface, expectedColors.surface);
  expect(colors.onTextPrimary, expectedColors.onTextPrimary);
  expect(colors.textPrimary, expectedColors.textPrimary);
  expect(colors.failed, expectedColors.failed);

  expect(theme.extension<AppSpacing>(), isNotNull);
  expect(theme.extension<AppRadius>(), isNotNull);
  expect(theme.extension<AppTypography>(), isNotNull);
  expect(theme.extension<AppElevation>(), isNotNull);
}

Map<String, Color> _matomeColorFields(MatomeColors colors) {
  return <String, Color>{
    'primary': colors.primary,
    'accent': colors.accent,
    'accentDark': colors.accentDark,
    'accentSoft': colors.accentSoft,
    'onAccent': colors.onAccent,
    'onTextPrimary': colors.onTextPrimary,
    'background': colors.background,
    'surface': colors.surface,
    'border': colors.border,
    'subtleFill': colors.subtleFill,
    'subtleFillStrong': colors.subtleFillStrong,
    'textPrimary': colors.textPrimary,
    'textSecondary': colors.textSecondary,
    'textMuted': colors.textMuted,
    'failed': colors.failed,
    'badgeWork': colors.badgeWork,
    'badgeWorkText': colors.badgeWorkText,
    'badgePersonal': colors.badgePersonal,
    'badgeIdeas': colors.badgeIdeas,
    'badgeDefault': colors.badgeDefault,
    'spaceGold': colors.spaceGold,
    'spaceGreen': colors.spaceGreen,
    'spaceBlue': colors.spaceBlue,
    'spaceOrange': colors.spaceOrange,
    'spaceRose': colors.spaceRose,
    'spacePurple': colors.spacePurple,
    'spaceTeal': colors.spaceTeal,
    'spaceRed': colors.spaceRed,
  };
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lightest = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darkest = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;

  return (lightest + 0.05) / (darkest + 0.05);
}
