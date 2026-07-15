import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/auth_state.dart';
import 'core/audio/audio_desktop_init.dart';
import 'core/config/endpoint_controller.dart';
import 'core/i18n/locale_controller.dart';
import 'core/observability/app_log.dart';
import 'core/logging/log_redaction.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/recordings/upload_retry_service.dart';
import 'i18n/strings.g.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.event(LogCat.lifecycle, 'app start');
  // #870 (plan #46 W1): on Linux/Windows desktop, register the media_kit backend
  // under the just_audio platform interface so playback + the duration probe
  // actually work (just_audio 0.9.x ships no native desktop backend). No-op on
  // mobile/web. Must run before any AudioPlayback is created.
  initDesktopAudioBackend();
  // SEC (#815): redact the Guardian JWT from any phoenix_socket log record
  // (the access token rides the WS connect URL's `?token=` query). Installed
  // before anything can log so the token never lands in a sink in cleartext.
  installSocketLogRedaction();
  // slang: hydrate from the device locale; the persisted choice is applied by
  // LocaleController on first build.
  LocaleSettings.useDeviceLocale();
  runApp(ProviderScope(child: TranslationProvider(child: const MatomeApp())));
}

/// App root: boots Riverpod + slang, then renders the go_router shell with the
/// Eva light/dark themes driven by the persisted theme controller.
class MatomeApp extends ConsumerStatefulWidget {
  const MatomeApp({super.key});

  @override
  ConsumerState<MatomeApp> createState() => _MatomeAppState();
}

class _MatomeAppState extends ConsumerState<MatomeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final policy = ref.read(systemPolicyProvider.notifier);
      final uploads = ref.read(uploadRetryServiceProvider);
      unawaited(policy.initialize().then((_) => uploads.start()));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPolicyAndDrain();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        _refreshPolicyAndDrain();
      }
    });
    ref.listen<String>(endpointConfigProvider, (previous, next) {
      if (previous != null && previous != next) {
        _refreshPolicyAndDrain();
      }
    });

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

  void _refreshPolicyAndDrain() {
    final policy = ref.read(systemPolicyProvider.notifier);
    final uploads = ref.read(uploadRetryServiceProvider);
    unawaited(policy.refresh());
    unawaited(uploads.drainNow());
  }
}
