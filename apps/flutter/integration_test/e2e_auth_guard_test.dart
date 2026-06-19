import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/auth/login_screen.dart';
import 'package:matome_flutter/features/auth/welcome_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_item.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/e2e_harness.dart';
import '../test/support/fake_inbox.dart';

// ---------------------------------------------------------------------------
// E2E auth + guard — headless. Mirrors apps/mobile .maestro/smoke.yaml (login
// path) + .maestro/auth-deeplink-guard.yaml end-to-end against the REAL router:
//   1. seeded persisted session  -> cold boot lands in the authed tabs
//   2. logout from Settings       -> guard redirects back to Welcome
//   3. login from Welcome         -> Welcome → Login → submit → authed tabs
//
// No network / secure-storage / mic: in-memory Drift + token store + a fake
// auth repo (FakeE2EAuthRepository), and a fake inbox so the Inbox renders a
// stable row.
// ---------------------------------------------------------------------------

InboxItem _seedItem() => InboxItem(
  card: const RecordingItem(
    id: '1',
    title: 'Standup notes',
    timestamp: '9:00 AM',
    duration: '0:30',
    badge: 'work',
    isProcessing: false,
    mediaType: 'audio',
    processingStatus: 'done',
  ),
  createdAt: DateTime(2024).millisecondsSinceEpoch,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryTokenStore store;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = InMemoryTokenStore();
  });
  tearDown(() => db.close());

  List<Override> overrides({required FakeE2EAuthRepository repo}) => [
    appDatabaseProvider.overrideWithValue(db),
    tokenStoreProvider.overrideWithValue(store),
    settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
    authRepositoryProvider.overrideWithValue(repo),
    inboxControllerProvider.overrideWith(
      (ref) => FakeInboxController(ref, AsyncValue.data([_seedItem()])),
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
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
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
    GoRouter.of(ctx).go('/inbox/settings');
    await tester.pumpAndSettle();

    final signOut = find.byIcon(Icons.logout);
    await tester.scrollUntilVisible(signOut, 200);
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
    await tester.enterText(fields.at(1), 'devpass');
    await tester.tap(find.widgetWithText(FilledButton, t.welcome.signIn));
    await tester.pumpAndSettle();

    // login() succeeded -> auth state flips -> guard lands us in the tabs.
    expect(repo.loginCalls, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });
}
