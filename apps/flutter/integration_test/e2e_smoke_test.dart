import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/auth/login_screen.dart';
import 'package:matome_flutter/features/auth/welcome_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/e2e_harness.dart';

// ---------------------------------------------------------------------------
// E2E smoke — headless (runs under `flutter test integration_test/` on web /
// linux / android). Mirrors apps/mobile .maestro/smoke.yaml +
// .maestro/auth-deeplink-guard.yaml:
//   * cold boot with no session lands on the Welcome (unauthenticated) screen
//   * the Welcome → Login navigation works
//   * the nav guard bounces an unauthenticated deep-link into /inbox back to
//     Welcome (no leaking into the authed shell)
//
// Backed by in-memory Drift + an in-memory token store + a fake auth repo, so
// nothing hits the network or platform channels.
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryTokenStore store;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = InMemoryTokenStore(); // no session -> unauthenticated boot
  });
  tearDown(() => db.close());

  testWidgets('cold boot with no session lands on Welcome', (tester) async {
    await tester.pumpWidget(
      buildE2EApp(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          authRepositoryProvider
              .overrideWithValue(FakeE2EAuthRepository(store)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    // Wordmark proves the real Welcome chrome rendered.
    expect(find.text('マトメ'), findsOneWidget);
    // Not leaked into the authed shell.
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Welcome → Sign in navigates to the Login screen', (tester) async {
    await tester.pumpWidget(
      buildE2EApp(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          authRepositoryProvider
              .overrideWithValue(FakeE2EAuthRepository(store)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The "Have an account? Sign in" CTA is the TextButton at the bottom of a
    // scroll view — make sure it is on-screen on small (test) viewports first.
    final signInCta = find.byType(TextButton).last;
    await tester.ensureVisible(signInCta);
    await tester.pumpAndSettle();
    await tester.tap(signInCta);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(t.auth.email), findsWidgets);
    expect(find.text(t.auth.password), findsWidgets);
  });

  testWidgets('nav guard: unauthenticated deep-link to /inbox redirects to '
      'Welcome', (tester) async {
    await tester.pumpWidget(
      buildE2EApp(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          authRepositoryProvider
              .overrideWithValue(FakeE2EAuthRepository(store)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Attempt to deep-link straight into the authed shell.
    final ctx = tester.element(find.byType(WelcomeScreen));
    GoRouter.of(ctx).go('/inbox');
    await tester.pumpAndSettle();

    // Guard bounced it back to Welcome — never reached the inbox.
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
