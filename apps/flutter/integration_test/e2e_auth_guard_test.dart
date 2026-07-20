import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/app/screens/settings_screen.dart';
import 'package:matome_flutter/features/auth/forgot_password_screen.dart';
import 'package:matome_flutter/features/auth/login_screen.dart';
import 'package:matome_flutter/features/auth/reset_password_screen.dart';
import 'package:matome_flutter/features/auth/signup_screen.dart';
import 'package:matome_flutter/features/auth/unlock_screen.dart';
import 'package:matome_flutter/features/auth/welcome_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/e2e_database.dart';
import 'support/e2e_harness.dart';

// ---------------------------------------------------------------------------
// E2E auth + guard — headless. Mirrors apps/mobile .maestro/smoke.yaml (login
// path) + .maestro/auth-deeplink-guard.yaml end-to-end against the REAL router:
//   1. seeded persisted session  -> cold boot lands in the authed tabs
//   2. logout from Settings       -> guard redirects back to Welcome
//   3. login from Welcome         -> Welcome → Login → submit → authed tabs
//
// No network / secure-storage / mic: in-memory Drift + token store + a fake
// auth repo (FakeE2EAuthRepository). The real inbox reads the in-memory DB.
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryTokenStore store;

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = await createE2EDatabase();
    store = InMemoryTokenStore();
  });
  tearDown(() => db.close());

  List<Override> overrides({
    required FakeE2EAuthRepository repo,
    bool restoreVaultReady = true,
  }) => [
    appDatabaseProvider.overrideWithValue(db),
    tokenStoreProvider.overrideWithValue(store),
    settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
    authRepositoryProvider.overrideWithValue(repo),
    vaultSessionProvider.overrideWith(
      (ref) => buildE2EVaultSession(restoreReady: restoreVaultReady),
    ),
  ];

  testWidgets('seeded session boots straight into the authed tabs', (
    tester,
  ) async {
    // Persist a valid session so restoreSession() lands authed.
    await store.saveTokens(
      accessToken: kE2ESession.accessToken,
      refreshToken: kE2ESession.refreshToken!,
    );

    await tester.pumpWidget(
      buildE2EApp(overrides: overrides(repo: FakeE2EAuthRepository(store))),
    );
    await tester.pumpAndSettle();

    // Past the guard into the Inbox tab.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('seeded session with a locked Vault lands on unlock and password '
      'opens the Inbox', (tester) async {
    await store.saveTokens(
      accessToken: kE2ESession.accessToken,
      refreshToken: kE2ESession.refreshToken!,
    );

    await tester.pumpWidget(
      buildE2EApp(
        overrides: overrides(
          repo: FakeE2EAuthRepository(store),
          restoreVaultReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.enterText(find.byType(TextField), 'devpassword123');
    await tester.tap(find.widgetWithText(FilledButton, t.auth.unlockSubmit));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(UnlockScreen), findsNothing);
  });

  testWidgets('logout from Settings clears tokens and returns to Welcome', (
    tester,
  ) async {
    await store.saveTokens(
      accessToken: kE2ESession.accessToken,
      refreshToken: kE2ESession.refreshToken!,
    );
    final repo = FakeE2EAuthRepository(store);

    await tester.pumpWidget(buildE2EApp(overrides: overrides(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Open Settings (an /inbox sub-route) and tap Sign out.
    final ctx = tester.element(find.byType(HomeScreen));
    final router = GoRouter.of(ctx)..go('/inbox/settings');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/inbox/settings');
    final signOut = find.byKey(const ValueKey('settings-sign-out'));
    final settingsScrollable = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      signOut,
      200,
      scrollable: settingsScrollable,
    );
    expect(signOut, findsOneWidget);
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(repo.logoutCalls, 1);
    expect(await store.readAccessToken(), isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('login from Welcome: Welcome → Login → submit → authed tabs', (
    tester,
  ) async {
    final repo = FakeE2EAuthRepository(store); // no seeded session -> Welcome

    await tester.pumpWidget(buildE2EApp(overrides: overrides(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    // Welcome -> Login (the "Sign in" CTA sits below the fold on small
    // viewports — scroll it on-screen first).
    final signInCta = find.byType(TextButton).last;
    await tester.ensureVisible(signInCta);
    await tester.pumpAndSettle();
    await tester.tap(signInCta);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Fill credentials (email field first, password second) and submit.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'dev@matome.test');
    await tester.enterText(fields.at(1), 'devpassword123');
    await tester.tap(find.widgetWithText(FilledButton, t.welcome.signIn));
    await pumpUntilFound(tester, find.byType(HomeScreen));

    // login() succeeded -> auth state flips -> guard lands us in the tabs.
    expect(repo.loginCalls, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('signup creates an account and opens a ready Vault session', (
    tester,
  ) async {
    final repo = FakeE2EAuthRepository(store);

    await tester.pumpWidget(
      buildE2EApp(overrides: overrides(repo: repo, restoreVaultReady: false)),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(WelcomeScreen))).go('/signup');
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'Dev User');
    await tester.enterText(fields.at(1), 'dev@matome.test');
    await tester.enterText(fields.at(2), 'devpassword123');
    await tester.enterText(fields.at(3), 'devpassword123');
    await tester.tap(find.widgetWithText(FilledButton, t.welcome.signUp));
    await pumpUntilFound(tester, find.byType(HomeScreen));

    expect(repo.registerCalls, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('forgot password requests a reset without revealing account '
      'existence', (tester) async {
    final repo = FakeE2EAuthRepository(store);

    await tester.pumpWidget(buildE2EApp(overrides: overrides(repo: repo)));
    await tester.pumpAndSettle();
    GoRouter.of(
      tester.element(find.byType(WelcomeScreen)),
    ).go('/forgot-password');
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'dev@matome.test');
    await tester.tap(
      find.widgetWithText(FilledButton, t.auth.forgotPasswordSubmit),
    );
    await tester.pumpAndSettle();

    expect(repo.requestPasswordResetCalls, 1);
    expect(repo.requestedResetEmail, 'dev@matome.test');
    expect(find.text(t.auth.forgotPasswordSent), findsOneWidget);
  });

  testWidgets(
    'reset password accepts a deep-link token and returns to sign in',
    (tester) async {
      final repo = FakeE2EAuthRepository(store);

      await tester.pumpWidget(buildE2EApp(overrides: overrides(repo: repo)));
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(WelcomeScreen)),
      ).go('/reset-password?token=reset-code');
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      expect(
        tester.widget<TextField>(fields.at(0)).controller?.text,
        'reset-code',
      );
      await tester.enterText(fields.at(1), 'newpassword123');
      await tester.enterText(fields.at(2), 'newpassword123');
      await tester.tap(
        find.widgetWithText(FilledButton, t.auth.resetPasswordSubmit),
      );
      await tester.pumpAndSettle();

      expect(repo.resetPasswordCalls, 1);
      expect(repo.resetToken, 'reset-code');
      expect(repo.resetPasswordValue, 'newpassword123');
      expect(find.text(t.auth.resetPasswordSuccess), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, t.auth.backToSignIn));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
