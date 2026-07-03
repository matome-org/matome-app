import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.g.dart';
import '../providers.dart';
import '../settings/settings_store.dart';

/// Persisted language selector, mirroring RN `languageStore` (`'en' | 'ja'`).
///
/// Drives slang's global [LocaleSettings] (so `t.*` and the
/// `TranslationProvider` rebuild) and persists the choice to the secure
/// [SettingsStore]. Default falls back to the device locale, matching the RN
/// `getDeviceLanguage()` behaviour.

const _localeKey = 'matome.language';

class LocaleController extends StateNotifier<AppLocale> {
  LocaleController(this._store) : super(LocaleSettings.currentLocale) {
    _hydrate();
  }

  final SettingsStore _store;

  Future<void> _hydrate() async {
    final raw = await _store.read(_localeKey);
    final locale = _parse(raw);
    if (locale != null) {
      LocaleSettings.setLocaleSync(locale);
      if (mounted) state = locale;
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    LocaleSettings.setLocaleSync(locale);
    state = locale;
    await _store.write(_localeKey, locale.languageCode);
  }

  static AppLocale? _parse(String? raw) {
    switch (raw) {
      case 'en':
        return AppLocale.en;
      case 'ja':
        return AppLocale.ja;
      default:
        return null;
    }
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, AppLocale>(
      (ref) => LocaleController(ref.watch(settingsStoreProvider)),
    );
