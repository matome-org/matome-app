import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/settings_store.dart';

/// Theme mode, mirroring RN `themeStore` (`'light' | 'dark' | 'system'`).
/// Maps 1:1 onto Flutter's [ThemeMode], so we reuse the SDK enum directly.

const _themeKey = 'matome.theme_mode';

/// Riverpod controller holding the selected [ThemeMode], hydrated from and
/// persisted to the secure [SettingsStore]. Default is [ThemeMode.system],
/// matching the RN store's initial `'system'`.
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._store) : super(ThemeMode.system) {
    _hydrate();
  }

  final SettingsStore _store;

  Future<void> _hydrate() async {
    final raw = await _store.read(_themeKey);
    final mode = _parse(raw);
    if (mode != null && mounted) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _store.write(_themeKey, mode.name);
  }

  static ThemeMode? _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>(
      (ref) => ThemeController(ref.watch(settingsStoreProvider)),
    );
