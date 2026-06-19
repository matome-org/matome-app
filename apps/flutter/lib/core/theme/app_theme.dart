import 'package:flutter/material.dart';

/// Matome "Eva" palette + greys. Mirrors `@matome/ui` eva theme tokens and the
/// UI-Kitten `color-basic-*` surfaces used by the RN app, so the Flutter shell
/// renders with the same accent gold and neutral surfaces.
final class MatomeColors extends ThemeExtension<MatomeColors> {
  const MatomeColors({
    required this.primary,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.onAccent,
    required this.onTextPrimary,
    required this.background,
    required this.surface,
    required this.border,
    required this.subtleFill,
    required this.subtleFillStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.failed,
    required this.badgeWork,
    required this.badgeWorkText,
    required this.badgePersonal,
    required this.badgeIdeas,
    required this.badgeDefault,
    required this.spaceGold,
    required this.spaceGreen,
    required this.spaceBlue,
    required this.spaceOrange,
    required this.spaceRose,
    required this.spacePurple,
    required this.spaceTeal,
    required this.spaceRed,
  });

  // Eva accent (gold) — single source of truth for primary.
  static const Color _accent = Color(0xFFE1B346); // ACCENT
  static const Color _accentDark = Color(0xFFB98A1F); // ACCENT_DARK
  static const Color _accentSoft = Color(0xFFF6E8C0); // ACCENT_SOFT
  static const Color _onAccent = _textPrimary;

  // Light surfaces — warm off-whites tinted toward the gold hue so the accent
  // reads as the spine of the palette, not a sticker. No pure #FFF.
  static const Color _background = Color(0xFFF6F4EF);
  static const Color _surface = Color(0xFFFDFCF9);
  static const Color _border = Color(0xFFE7E2D7);

  // Dark surfaces — warm charcoal, not neutral grey, for the same cohesion.
  static const Color _backgroundDark = Color(0xFF1A1714);
  static const Color _surfaceDark = Color(0xFF252119);
  static const Color _borderDark = Color(0xFF38322A);

  // Foreground for filled controls that intentionally use textPrimary as fill.
  static const Color _onTextPrimary = _surface;
  static const Color _onTextPrimaryDark = _backgroundDark;

  // Tokenized translucent fills, warm-tinted and now perceptibly distinct
  // (the old pair differed by 1% alpha and were identical in dark).
  static const Color _subtleFill = Color(0x0F1A1712);
  static const Color _subtleFillStrong = Color(0x1A1A1712);
  static const Color _subtleFillDark = Color(0x14F4F1E9);
  static const Color _subtleFillStrongDark = Color(0x29F4F1E9);

  // Text greys (color-basic-500..800).
  //
  // WCAG AA audit (plan #45, W3 + task #1299): the existing LIGHT-surface
  // annotations are kept verbatim, then extended with measured dark-surface
  // ratios in `backgroundDark / surfaceDark` order. Dark tokens are the
  // ThemeExtension-ready AA pairs for dark surfaces.
  // Warm-tinted greys (hue nudged toward gold, luminance held to preserve the
  // audited AA headroom). Re-verified by app_theme_contrast_test.
  static const Color _textPrimary = Color(0xFF221E16); // warm near-black
  static const Color _textSecondary = Color(0xFF585249); // ~6:1 on surface
  static const Color _textMuted = Color(0xFF655D4F); // AA on warm surface
  static const Color _textPrimaryDark = Color(0xFFF4F1E9); // warm off-white
  static const Color _textSecondaryDark = Color(0xFFC4BCAD);
  static const Color _textMutedDark = Color(0xFFAAA08D);

  // Status. Darkened from #C64A3D (4.72:1) to keep headroom now that it also
  // backs error TEXT on white, not just icons. `failedDark` starts from Eva
  // danger (#E63946) and is lifted enough to clear AA on both dark surfaces.
  static const Color _failed = Color(
    0xFFB23A2E,
  ); // 5.6:1 on white; 2.93:1 / 2.42:1 on dark
  static const Color _failedDark = Color(
    0xFFFF6B75,
  ); // 2.76:1 on white; 6.31:1 / 5.20:1 on dark

  // Badge accents (matches RN BADGE_COLORS spirit, keyed by free-form badge).
  // The accent dots are decorative, but `badgePersonal` also backs the cloud
  // sync badge TEXT (on a 12% self-tint), and `badgeDefault`/`badgeIdeas` can
  // surface as text — so they are darkened to clear AA as text on white.
  // Dark badge tokens restore the Eva/RN badge hues where AA permits it.
  static const Color _badgeWork = Color(
    0xFFE1B346,
  ); // 1.96:1 on white; 8.90:1 / 7.34:1 on dark
  static const Color _badgeWorkText = Color(
    0xFF8F6D2A,
  ); // 4.78:1 on white; 3.64:1 / 3.00:1 on dark
  static const Color _badgePersonal = Color(
    0xFF3A7150,
  ); // 5.74:1 white / 4.87:1 on 12% self-tint (cloud badge); 3.03:1 / 2.50:1 on dark
  static const Color _badgeIdeas = Color(
    0xFF4A6FC0,
  ); // 4.85:1 (was #6A8AD9); 3.59:1 / 2.96:1 on dark
  static const Color _badgeDefault = Color(
    0xFF6B7280,
  ); // 4.83:1 (was #A6ADB8); 3.60:1 / 2.97:1 on dark
  static const Color _badgeWorkDark =
      _badgeWork; // 1.96:1 on white; 8.90:1 / 7.34:1 on dark
  static const Color _badgePersonalDark = Color(
    0xFF6FB180,
  ); // 2.54:1 on white; 6.86:1 / 5.66:1 on dark
  static const Color _badgeIdeasDark = Color(
    0xFF7899E8,
  ); // 2.79:1 on white; 6.23:1 / 5.14:1 on dark
  static const Color _badgeDefaultDark = Color(
    0xFFA6ADB8,
  ); // 2.26:1 on white; 7.70:1 / 6.35:1 on dark

  // Spaces accent palette — re-derived as one harmonized, low-chroma band
  // (equal-ish saturation/lightness, no raw Tailwind values). Reads as a
  // considered set rather than a rainbow, so spaces stay distinguishable
  // without fighting the single-accent gold brand.
  static const Color _spaceGold = Color(0xFFC8A24E);
  static const Color _spaceGreen = Color(0xFF7E9B6E);
  static const Color _spaceBlue = Color(0xFF6E86A8);
  static const Color _spaceOrange = Color(0xFFC68A5E);
  static const Color _spaceRose = Color(0xFFBC8497);
  static const Color _spacePurple = Color(0xFF9587AE);
  static const Color _spaceTeal = Color(0xFF6FA39A);
  static const Color _spaceRed = Color(0xFFC2705F);

  static const MatomeColors light = MatomeColors(
    primary: _accent,
    accent: _accent,
    accentDark: _accentDark,
    accentSoft: _accentSoft,
    onAccent: _onAccent,
    onTextPrimary: _onTextPrimary,
    background: _background,
    surface: _surface,
    border: _border,
    subtleFill: _subtleFill,
    subtleFillStrong: _subtleFillStrong,
    textPrimary: _textPrimary,
    textSecondary: _textSecondary,
    textMuted: _textMuted,
    failed: _failed,
    badgeWork: _badgeWork,
    badgeWorkText: _badgeWorkText,
    badgePersonal: _badgePersonal,
    badgeIdeas: _badgeIdeas,
    badgeDefault: _badgeDefault,
    spaceGold: _spaceGold,
    spaceGreen: _spaceGreen,
    spaceBlue: _spaceBlue,
    spaceOrange: _spaceOrange,
    spaceRose: _spaceRose,
    spacePurple: _spacePurple,
    spaceTeal: _spaceTeal,
    spaceRed: _spaceRed,
  );

  static const MatomeColors dark = MatomeColors(
    primary: _accentDark,
    accent: _accent,
    accentDark: _accentDark,
    accentSoft: _accentSoft,
    onAccent: _onAccent,
    onTextPrimary: _onTextPrimaryDark,
    background: _backgroundDark,
    surface: _surfaceDark,
    border: _borderDark,
    subtleFill: _subtleFillDark,
    subtleFillStrong: _subtleFillStrongDark,
    textPrimary: _textPrimaryDark,
    textSecondary: _textSecondaryDark,
    textMuted: _textMutedDark,
    failed: _failedDark,
    badgeWork: _badgeWorkDark,
    badgeWorkText: _badgeWorkDark,
    badgePersonal: _badgePersonalDark,
    badgeIdeas: _badgeIdeasDark,
    badgeDefault: _badgeDefaultDark,
    spaceGold: _spaceGold,
    spaceGreen: _spaceGreen,
    spaceBlue: _spaceBlue,
    spaceOrange: _spaceOrange,
    spaceRose: _spaceRose,
    spacePurple: _spacePurple,
    spaceTeal: _spaceTeal,
    spaceRed: _spaceRed,
  );

  final Color primary;
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color onAccent;
  final Color onTextPrimary;
  final Color background;
  final Color surface;
  final Color border;
  final Color subtleFill;
  final Color subtleFillStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color failed;
  final Color badgeWork;
  final Color badgeWorkText;
  final Color badgePersonal;
  final Color badgeIdeas;
  final Color badgeDefault;
  final Color spaceGold;
  final Color spaceGreen;
  final Color spaceBlue;
  final Color spaceOrange;
  final Color spaceRose;
  final Color spacePurple;
  final Color spaceTeal;
  final Color spaceRed;

  Color badgeColor(String? badge) {
    switch (badge?.toLowerCase()) {
      case 'work':
        return badgeWork;
      case 'personal':
        return badgePersonal;
      case 'ideas':
        return badgeIdeas;
      default:
        return badgeDefault;
    }
  }

  Color spaceColor(int index) {
    switch (index % 8) {
      case 0:
        return spaceGold;
      case 1:
        return spaceGreen;
      case 2:
        return spaceBlue;
      case 3:
        return spaceOrange;
      case 4:
        return spaceRose;
      case 5:
        return spacePurple;
      case 6:
        return spaceTeal;
      default:
        return spaceRed;
    }
  }

  @override
  MatomeColors copyWith({
    Color? primary,
    Color? accent,
    Color? accentDark,
    Color? accentSoft,
    Color? onAccent,
    Color? onTextPrimary,
    Color? background,
    Color? surface,
    Color? border,
    Color? subtleFill,
    Color? subtleFillStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? failed,
    Color? badgeWork,
    Color? badgeWorkText,
    Color? badgePersonal,
    Color? badgeIdeas,
    Color? badgeDefault,
    Color? spaceGold,
    Color? spaceGreen,
    Color? spaceBlue,
    Color? spaceOrange,
    Color? spaceRose,
    Color? spacePurple,
    Color? spaceTeal,
    Color? spaceRed,
  }) {
    return MatomeColors(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      onTextPrimary: onTextPrimary ?? this.onTextPrimary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      subtleFill: subtleFill ?? this.subtleFill,
      subtleFillStrong: subtleFillStrong ?? this.subtleFillStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      failed: failed ?? this.failed,
      badgeWork: badgeWork ?? this.badgeWork,
      badgeWorkText: badgeWorkText ?? this.badgeWorkText,
      badgePersonal: badgePersonal ?? this.badgePersonal,
      badgeIdeas: badgeIdeas ?? this.badgeIdeas,
      badgeDefault: badgeDefault ?? this.badgeDefault,
      spaceGold: spaceGold ?? this.spaceGold,
      spaceGreen: spaceGreen ?? this.spaceGreen,
      spaceBlue: spaceBlue ?? this.spaceBlue,
      spaceOrange: spaceOrange ?? this.spaceOrange,
      spaceRose: spaceRose ?? this.spaceRose,
      spacePurple: spacePurple ?? this.spacePurple,
      spaceTeal: spaceTeal ?? this.spaceTeal,
      spaceRed: spaceRed ?? this.spaceRed,
    );
  }

  @override
  MatomeColors lerp(ThemeExtension<MatomeColors>? other, double t) {
    if (other is! MatomeColors) {
      return this;
    }

    return MatomeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onTextPrimary: Color.lerp(onTextPrimary, other.onTextPrimary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      subtleFill: Color.lerp(subtleFill, other.subtleFill, t)!,
      subtleFillStrong: Color.lerp(
        subtleFillStrong,
        other.subtleFillStrong,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      failed: Color.lerp(failed, other.failed, t)!,
      badgeWork: Color.lerp(badgeWork, other.badgeWork, t)!,
      badgeWorkText: Color.lerp(badgeWorkText, other.badgeWorkText, t)!,
      badgePersonal: Color.lerp(badgePersonal, other.badgePersonal, t)!,
      badgeIdeas: Color.lerp(badgeIdeas, other.badgeIdeas, t)!,
      badgeDefault: Color.lerp(badgeDefault, other.badgeDefault, t)!,
      spaceGold: Color.lerp(spaceGold, other.spaceGold, t)!,
      spaceGreen: Color.lerp(spaceGreen, other.spaceGreen, t)!,
      spaceBlue: Color.lerp(spaceBlue, other.spaceBlue, t)!,
      spaceOrange: Color.lerp(spaceOrange, other.spaceOrange, t)!,
      spaceRose: Color.lerp(spaceRose, other.spaceRose, t)!,
      spacePurple: Color.lerp(spacePurple, other.spacePurple, t)!,
      spaceTeal: Color.lerp(spaceTeal, other.spaceTeal, t)!,
      spaceRed: Color.lerp(spaceRed, other.spaceRed, t)!,
    );
  }
}

final class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const AppSpacing standard = AppSpacing(
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  );

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  @override
  AppSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return AppSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) {
      return this;
    }

    return AppSpacing(
      xxs: _lerpDouble(xxs, other.xxs, t),
      xs: _lerpDouble(xs, other.xs, t),
      sm: _lerpDouble(sm, other.sm, t),
      md: _lerpDouble(md, other.md, t),
      lg: _lerpDouble(lg, other.lg, t),
      xl: _lerpDouble(xl, other.xl, t),
      xxl: _lerpDouble(xxl, other.xxl, t),
    );
  }
}

final class AppRadius extends ThemeExtension<AppRadius> {
  const AppRadius({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pill,
  });

  static const AppRadius standard = AppRadius(
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    pill: 999,
  );

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;

  @override
  AppRadius copyWith({
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? pill,
  }) {
    return AppRadius(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
    );
  }

  @override
  AppRadius lerp(ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) {
      return this;
    }

    return AppRadius(
      sm: _lerpDouble(sm, other.sm, t),
      md: _lerpDouble(md, other.md, t),
      lg: _lerpDouble(lg, other.lg, t),
      xl: _lerpDouble(xl, other.xl, t),
      pill: _lerpDouble(pill, other.pill, t),
    );
  }
}

final class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.title,
    required this.body,
    required this.bodySmall,
    required this.label,
  });

  // Type families. Display/title use Schibsted Grotesk (editorial geometric
  // grotesk); body/label use Hanken Grotesk (humanist, tuned for small sizes).
  // Zen Kaku Gothic New is the Japanese fallback so JA glyphs render in a
  // deliberate gothic rather than the platform default. Both latin faces are
  // variable fonts — Flutter maps `fontWeight` onto the `wght` axis.
  static const String displayFamily = 'Schibsted Grotesk';
  static const String bodyFamily = 'Hanken Grotesk';
  static const List<String> _jaFallback = ['Zen Kaku Gothic New'];

  // Scale favours contrast over rungs: display (44) → title (24) → body (16)
  // is ~1.8×/1.5×, so one element per screen reads unambiguously largest.
  static const AppTypography standard = AppTypography(
    display: TextStyle(
      fontFamily: displayFamily,
      fontFamilyFallback: _jaFallback,
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 1.04,
      letterSpacing: -1.0,
    ),
    title: TextStyle(
      fontFamily: displayFamily,
      fontFamilyFallback: _jaFallback,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.16,
      letterSpacing: -0.4,
    ),
    body: TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: _jaFallback,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: _jaFallback,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    label: TextStyle(
      fontFamily: bodyFamily,
      fontFamilyFallback: _jaFallback,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0.4,
    ),
  );

  final TextStyle display;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
  }) {
    return AppTypography(
      display: display ?? this.display,
      title: title ?? this.title,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      label: label ?? this.label,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) {
      return this;
    }

    return AppTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
    );
  }
}

final class AppElevation extends ThemeExtension<AppElevation> {
  const AppElevation({
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
  });

  static const AppElevation standard = AppElevation(
    level0: 0,
    level1: 1,
    level2: 3,
    level3: 8,
  );

  final double level0;
  final double level1;
  final double level2;
  final double level3;

  @override
  AppElevation copyWith({
    double? level0,
    double? level1,
    double? level2,
    double? level3,
  }) {
    return AppElevation(
      level0: level0 ?? this.level0,
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
    );
  }

  @override
  AppElevation lerp(ThemeExtension<AppElevation>? other, double t) {
    if (other is! AppElevation) {
      return this;
    }

    return AppElevation(
      level0: _lerpDouble(level0, other.level0, t),
      level1: _lerpDouble(level1, other.level1, t),
      level2: _lerpDouble(level2, other.level2, t),
      level3: _lerpDouble(level3, other.level3, t),
    );
  }
}

extension MatomeThemeContext on BuildContext {
  MatomeColors get colors => _themeExtension<MatomeColors>('MatomeColors');

  AppSpacing get spacing => _themeExtension<AppSpacing>('AppSpacing');

  AppRadius get radius => _themeExtension<AppRadius>('AppRadius');

  AppTypography get typography =>
      _themeExtension<AppTypography>('AppTypography');

  AppElevation get elevation => _themeExtension<AppElevation>('AppElevation');

  T _themeExtension<T extends ThemeExtension<T>>(String name) {
    final extension = Theme.of(this).extension<T>();
    if (extension == null) {
      throw StateError(
        '$name is missing from ThemeData.extensions. Use buildLightTheme() '
        'or buildDarkTheme().',
      );
    }
    return extension;
  }
}

/// Resolves a free-form `badge` string to a stable accent color.
Color badgeColor(String? badge) {
  return MatomeColors.light.badgeColor(badge);
}

/// Dark-surface badge resolver for the upcoming ThemeExtension wiring.
Color badgeColorDark(String? badge) {
  return MatomeColors.dark.badgeColor(badge);
}

const List<ThemeExtension<dynamic>> _lightThemeExtensions = [
  MatomeColors.light,
  AppSpacing.standard,
  AppRadius.standard,
  AppTypography.standard,
  AppElevation.standard,
];

const List<ThemeExtension<dynamic>> _darkThemeExtensions = [
  MatomeColors.dark,
  AppSpacing.standard,
  AppRadius.standard,
  AppTypography.standard,
  AppElevation.standard,
];

ThemeData _baseTheme(
  ColorScheme scheme, {
  required Color scaffold,
  required Iterable<ThemeExtension<dynamic>> extensions,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    fontFamily: AppTypography.bodyFamily,
    fontFamilyFallback: AppTypography._jaFallback,
    extensions: extensions,
  );
}

/// Light theme using the Eva gold accent.
ThemeData buildLightTheme() {
  const colors = MatomeColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    primary: colors.primary,
    surface: colors.surface,
    brightness: Brightness.light,
  );
  final theme = _baseTheme(
    scheme,
    scaffold: colors.background,
    extensions: _lightThemeExtensions,
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
  );
}

/// Dark theme using the darker Eva gold accent.
ThemeData buildDarkTheme() {
  const colors = MatomeColors.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    primary: colors.primary,
    surface: colors.surface,
    brightness: Brightness.dark,
  );
  final theme = _baseTheme(
    scheme,
    scaffold: colors.background,
    extensions: _darkThemeExtensions,
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
  );
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Backwards-compatible default theme (light) for existing lab widgets/tests.
ThemeData buildAppTheme() => buildLightTheme();
