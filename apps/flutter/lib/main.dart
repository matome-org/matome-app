import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/i18n/locale_controller.dart';
import 'core/logging/log_redaction.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'i18n/strings.g.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // SEC (#815): redact the Guardian JWT from any phoenix_socket log record
  // (the access token rides the WS connect URL's `?token=` query). Installed
  // before anything can log so the token never lands in a sink in cleartext.
  installSocketLogRedaction();
  // slang: hydrate from the device locale; the persisted choice is applied by
  // LocaleController on first build.
  LocaleSettings.useDeviceLocale();
  runApp(
    ProviderScope(
      child: TranslationProvider(child: const MatomeApp()),
    ),
  );
}

/// App root: boots Riverpod + slang, then renders the go_router shell with the
/// Eva light/dark themes driven by the persisted theme controller.
class MatomeApp extends ConsumerWidget {
  const MatomeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    // Watch the locale so the whole app rebuilds on language switch.
    ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'Matome',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
