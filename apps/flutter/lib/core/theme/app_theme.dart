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
  static const Color textPrimary = Color(0xFF1A2138); // color-basic-800
  static const Color textSecondary = Color(0xFF6B7280); // color-basic-600
  static const Color textMuted = Color(0xFF9AA1AC); // color-basic-500
  static const Color textPrimaryDark = Color(0xFFF4F5F6);

  // Status.
  static const Color failed = Color(0xFFC64A3D);

  // Badge accents (matches RN BADGE_COLORS spirit, keyed by free-form badge).
  static const Color badgeWork = Color(0xFFE1B346);
  static const Color badgePersonal = Color(0xFF6FB180);
  static const Color badgeIdeas = Color(0xFF6A8AD9);
  static const Color badgeDefault = Color(0xFFA6ADB8);
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
