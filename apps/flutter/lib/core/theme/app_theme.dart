import 'package:flutter/material.dart';

/// Base palette approximating the current RN/UI-Kitten "basic" greys + accent,
/// kept intentionally small (no full design system — this is the lab).
abstract final class AppColors {
  // Surfaces (mirror the UI-Kitten color-basic-100..200 backgrounds).
  static const Color background = Color(0xFFF4F5F6); // color-basic-200
  static const Color surface = Color(0xFFFFFFFF); // color-basic-100
  static const Color border = Color(0xFFE4E7EB); // color-basic-400

  // Text greys (color-basic-500..800).
  static const Color textPrimary = Color(0xFF1A2138); // color-basic-800
  static const Color textSecondary = Color(0xFF6B7280); // color-basic-600
  static const Color textMuted = Color(0xFF9AA1AC); // color-basic-500

  // Accent / status.
  static const Color primary = Color(0xFF6A5AE0);
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

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
