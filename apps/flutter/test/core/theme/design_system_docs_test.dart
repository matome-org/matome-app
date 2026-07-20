import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';

void main() {
  test('design-system README token tables match ThemeExtension values', () {
    final readme = File('lib/ui/README.md').readAsStringSync();

    expect(_tableRows(readme, 'color-tokens'), _colorRows());
    expect(_tableRows(readme, 'spacing-tokens'), _spacingRows());
    expect(_tableRows(readme, 'radius-tokens'), _radiusRows());
    expect(_tableRows(readme, 'typography-tokens'), _typographyRows());
    expect(_tableRows(readme, 'elevation-tokens'), _elevationRows());
  });
}

List<String> _tableRows(String markdown, String marker) {
  final match = RegExp(
    '<!-- $marker:start -->([\\s\\S]*?)<!-- $marker:end -->',
  ).firstMatch(markdown);

  expect(match, isNotNull, reason: 'Missing $marker block in README');

  return match!
      .group(1)!
      .split('\n')
      .where((line) => line.startsWith('| `'))
      .toList();
}

List<String> _colorRows() {
  const light = MatomeColors.light;
  const dark = MatomeColors.dark;

  return [
    _colorRow('primary', light.primary, dark.primary),
    _colorRow('accent', light.accent, dark.accent),
    _colorRow('accentDark', light.accentDark, dark.accentDark),
    _colorRow('accentSoft', light.accentSoft, dark.accentSoft),
    _colorRow('onAccent', light.onAccent, dark.onAccent),
    _colorRow('onTextPrimary', light.onTextPrimary, dark.onTextPrimary),
    _colorRow('background', light.background, dark.background),
    _colorRow('surface', light.surface, dark.surface),
    _colorRow('border', light.border, dark.border),
    _colorRow('subtleFill', light.subtleFill, dark.subtleFill),
    _colorRow(
      'subtleFillStrong',
      light.subtleFillStrong,
      dark.subtleFillStrong,
    ),
    _colorRow('textPrimary', light.textPrimary, dark.textPrimary),
    _colorRow('textSecondary', light.textSecondary, dark.textSecondary),
    _colorRow('textMuted', light.textMuted, dark.textMuted),
    _colorRow('failed', light.failed, dark.failed),
    _colorRow('badgeWork', light.badgeWork, dark.badgeWork),
    _colorRow('badgeWorkText', light.badgeWorkText, dark.badgeWorkText),
    _colorRow('badgePersonal', light.badgePersonal, dark.badgePersonal),
    _colorRow('badgeIdeas', light.badgeIdeas, dark.badgeIdeas),
    _colorRow('badgeDefault', light.badgeDefault, dark.badgeDefault),
    _colorRow('spaceGold', light.spaceGold, dark.spaceGold),
    _colorRow('spaceGreen', light.spaceGreen, dark.spaceGreen),
    _colorRow('spaceBlue', light.spaceBlue, dark.spaceBlue),
    _colorRow('spaceOrange', light.spaceOrange, dark.spaceOrange),
    _colorRow('spaceRose', light.spaceRose, dark.spaceRose),
    _colorRow('spacePurple', light.spacePurple, dark.spacePurple),
    _colorRow('spaceTeal', light.spaceTeal, dark.spaceTeal),
    _colorRow('spaceRed', light.spaceRed, dark.spaceRed),
  ];
}

String _colorRow(String token, Color light, Color dark) {
  return _row(
    token,
    _hex(light),
    _hex(dark),
    _ratio(light, MatomeColors.light.surface),
    _ratio(dark, MatomeColors.dark.background),
    _ratio(dark, MatomeColors.dark.surface),
  );
}

List<String> _spacingRows() {
  const spacing = AppSpacing.standard;

  return [
    _sameValueRow('spacing.xxs', _number(spacing.xxs)),
    _sameValueRow('spacing.xs', _number(spacing.xs)),
    _sameValueRow('spacing.sm', _number(spacing.sm)),
    _sameValueRow('spacing.md', _number(spacing.md)),
    _sameValueRow('spacing.lg', _number(spacing.lg)),
    _sameValueRow('spacing.xl', _number(spacing.xl)),
    _sameValueRow('spacing.xxl', _number(spacing.xxl)),
  ];
}

List<String> _radiusRows() {
  const radius = AppRadius.standard;

  return [
    _sameValueRow('radius.sm', _number(radius.sm)),
    _sameValueRow('radius.md', _number(radius.md)),
    _sameValueRow('radius.lg', _number(radius.lg)),
    _sameValueRow('radius.xl', _number(radius.xl)),
    _sameValueRow('radius.pill', _number(radius.pill)),
  ];
}

List<String> _typographyRows() {
  const typography = AppTypography.standard;

  return [
    _sameValueRow('typography.display', _styleValue(typography.display)),
    _sameValueRow('typography.title', _styleValue(typography.title)),
    _sameValueRow('typography.body', _styleValue(typography.body)),
    _sameValueRow('typography.bodySmall', _styleValue(typography.bodySmall)),
    _sameValueRow('typography.label', _styleValue(typography.label)),
  ];
}

List<String> _elevationRows() {
  const elevation = AppElevation.standard;

  return [
    _sameValueRow('elevation.level0', _number(elevation.level0)),
    _sameValueRow('elevation.level1', _number(elevation.level1)),
    _sameValueRow('elevation.level2', _number(elevation.level2)),
    _sameValueRow('elevation.level3', _number(elevation.level3)),
  ];
}

String _sameValueRow(String token, String value) {
  return _row(token, value, value, 'n/a', 'n/a', 'n/a');
}

String _row(
  String token,
  String light,
  String dark,
  String lightRatio,
  String darkBackgroundRatio,
  String darkSurfaceRatio,
) {
  return '| `$token` | `$light` | `$dark` | $lightRatio | '
      '$darkBackgroundRatio | $darkSurfaceRatio |';
}

String _hex(Color color) {
  return '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

String _ratio(Color foreground, Color background) {
  return '${_contrastRatio(foreground, background).toStringAsFixed(2)}:1';
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

String _styleValue(TextStyle style) {
  final family = style.fontFamily ?? 'system';
  final size = _number(style.fontSize ?? 0);
  final weight = _fontWeight(style.fontWeight);
  final height = style.height?.toString() ?? 'default';
  final letter = style.letterSpacing == null
      ? 'default'
      : _number(style.letterSpacing!);

  return '$family; size $size; weight $weight; height $height; letter $letter';
}

String _fontWeight(FontWeight? weight) {
  if (weight == null) return 'default';
  return 'w${weight.value}';
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
