import 'package:flutter/material.dart';

/// Matome "Eva" palette + greys. Mirrors `@matome/ui` eva theme tokens and the
/// UI-Kitten `color-basic-*` surfaces used by the RN app, so the Flutter shell
/// renders with the same accent gold and neutral surfaces.
abstract final class AppColors {
  // Eva accent (gold) — single source of truth for primary.
  static const Color accent = Color(0xFFE1B346); // ACCENT
  static const Color accentDark = Color(0xFFB98A1F); // ACCENT_DARK
  static const Color accentSoft = Color(0xFFF6E8C0); // ACCENT_SOFT

  // Backwards-compatible alias kept for existing lab widgets.
  static const Color primary = accent;

  // Light surfaces (UI-Kitten color-basic-100..400).
  static const Color background = Color(0xFFF4F5F6); // color-basic-200
  static const Color surface = Color(0xFFFFFFFF); // color-basic-100
  static const Color border = Color(0xFFE4E7EB); // color-basic-400

  // Dark surfaces.
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF2A2A2A);
  static const Color borderDark = Color(0xFF3A3A3A);

  // Text greys (color-basic-500..800).
  //
  // WCAG AA audit (plan #45, W3): every screen paints text on the LIGHT
  // surfaces above (cards/sheets hardcode `surface`/`background`), so these
  // tokens are tuned to clear AA *on white* (body ≥4.5:1). Contrast ratios on
  // #FFFFFF are noted inline. (`textPrimaryDark` is the only genuinely
  // dark-surface text token, used via ThemeData.textTheme.)
  static const Color textPrimary = Color(0xFF1A2138); // 15.93:1 on white
  static const Color textSecondary = Color(0xFF595F6B); // 6.0:1 (was #6B7280)
  static const Color textMuted = Color(0xFF6B7280); // 4.83:1 (was #9AA1AC, 2.6)
  static const Color textPrimaryDark = Color(0xFFF4F5F6);

  // Status. Darkened from #C64A3D (4.72:1) to keep headroom now that it also
  // backs error TEXT on white, not just icons.
  static const Color failed = Color(0xFFB23A2E); // 5.6:1 on white

  // Badge accents (matches RN BADGE_COLORS spirit, keyed by free-form badge).
  // The accent dots are decorative, but `badgePersonal` also backs the cloud
  // sync badge TEXT (on a 12% self-tint), and `badgeDefault`/`badgeIdeas` can
  // surface as text — so they are darkened to clear AA as text on white.
  static const Color badgeWork = Color(0xFFE1B346);
  static const Color badgePersonal =
      Color(0xFF3A7150); // 5.74:1 white / 4.87:1 on 12% self-tint (cloud badge)
  static const Color badgeIdeas = Color(0xFF4A6FC0); // 4.85:1 (was #6A8AD9)
  static const Color badgeDefault = Color(0xFF6B7280); // 4.83:1 (was #A6ADB8)
}

/// Resolves a free-form `badge` string to a stable accent color.
Color badgeColor(String? badge) {
  switch (badge?.toLowerCase()) {
    case 'work':
      return AppColors.badgeWork;
    case 'personal':
      return AppColors.badgePersonal;
    case 'ideas':
      return AppColors.badgeIdeas;
    default:
      return AppColors.badgeDefault;
  }
}

ThemeData _baseTheme(ColorScheme scheme, {required Color scaffold}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    fontFamily: 'Roboto',
  );
}

/// Light theme using the Eva gold accent.
ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: AppColors.surface,
    brightness: Brightness.light,
  );
  return _baseTheme(scheme, scaffold: AppColors.background).copyWith(
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}

/// Dark theme using the darker Eva gold accent.
ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accentDark,
    surface: AppColors.surfaceDark,
    brightness: Brightness.dark,
  );
  return _baseTheme(scheme, scaffold: AppColors.backgroundDark).copyWith(
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.textPrimaryDark,
      displayColor: AppColors.textPrimaryDark,
    ),
  );
}

/// Backwards-compatible default theme (light) for existing lab widgets/tests.
ThemeData buildAppTheme() => buildLightTheme();
