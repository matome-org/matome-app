import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/app/router.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/auth/auth_controller.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';

import 'support/e2e_harness.dart';

/// REPRODUCTION against the REAL production [routerProvider] (with its
/// `refreshListenable: _AuthListenable`), which the plain-MaterialApp /
/// custom-GoRouter widget tests never exercised.
///
/// BUG #1: tapping an image Item pushes [FileDetailScreen] IMPERATIVELY onto
/// go_router's ROOT navigator. When the auth-state listenable next ticks (any
/// post-navigation auth refresh — the live app fires these), go_router rebuilds
/// and reasserts its DECLARATIVE page stack, popping the untracked imperative
/// route. The image detail screen vanishes — exactly the "tapping an image does
/// nothing / flashes away" the user saw. Audio survives because it is pushed
/// DECLARATIVELY via `context.push('/recording/detail/:id')`, so go_router owns
/// it and keeps it across rebuilds.

Future<void> _seedMatome(AppDatabase db, {required String id}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: const Value('Standup notes'),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );
}

Future<void> _seedItem(
  AppDatabase db, {
  required String id,
  required String matomeId,
  required String mediaType,
  required String title,
}) async {
  await db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: Value(id),
      title: Value(title),
      timestamp: const Value('2026-06-08T12:00:00Z'),
      duration: const Value('0:10'),
      audioFilePath: const Value('/tmp/does-not-exist.bin'),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      mediaType: Value(mediaType),
      matomeId: Value(matomeId),
      isProcessing: const Value(0),
      processingStatus: const Value('done'),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'BUG #1 (real router): an auth tick after opening an image Item drops '
      'the imperatively-pushed detail route', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedMatome(db, id: 'm1');
    await _seedItem(
      db,
      id: 'img1',
      matomeId: 'm1',
      mediaType: 'image',
      title: 'A photo',
    );

    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'e2e-access', refreshToken: 'e2e-refresh');
    final authRepo = FakeE2EAuthRepository(store);

    await tester.pumpWidget(buildE2EApp(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(store),
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      authRepositoryProvider.overrideWithValue(authRepo),
    ]));
    await tester.pumpAndSettle();

    // Drive the production router to the matome hub.
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/matome/m1');
    await tester.pumpAndSettle();

    // Reveal the items and open the image.
    await tester.tap(find.byKey(const ValueKey('matome-show-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-image-img1')),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-image-img1')));
    await tester.pumpAndSettle();

    // The image detail is up.
    expect(find.byType(FileDetailScreen), findsOneWidget,
        reason: 'the image detail screen opened');

    // Fire an auth-state tick (the live app does this on any auth refresh).
    // The _AuthListenable notifies → go_router rebuilds → the imperatively
    // pushed route is reasserted away.
    final container = ProviderScope.containerOf(ctx);
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'dev@matome.test', password: 'x');
    await tester.pumpAndSettle();

    // EXPECTATION (what the FIX must guarantee): the image detail SURVIVES the
    // auth-driven router rebuild. Pre-fix this fails — the imperative route was
    // dropped and the user is back on the hub.
    expect(find.byType(FileDetailScreen), findsOneWidget,
        reason: 'the image detail must survive an auth-driven router rebuild');
  });

  testWidgets(
      'PROBE: back from the image detail returns to the hub (not stranded by '
      "the hub's canPop:false PopScope)", (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedMatome(db, id: 'm1');
    await _seedItem(
      db,
      id: 'img1',
      matomeId: 'm1',
      mediaType: 'image',
      title: 'A photo',
    );

    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');
    await tester.pumpWidget(buildE2EApp(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(store),
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      authRepositoryProvider.overrideWithValue(FakeE2EAuthRepository(store)),
    ]));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/matome/m1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-show-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-image-img1')),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-image-img1')));
    await tester.pumpAndSettle();
    expect(find.byType(FileDetailScreen), findsOneWidget);

    // Press the detail screen's AppBar back button.
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();

    // Back should land on the hub, NOT strand or jump to /inbox.
    expect(find.byType(FileDetailScreen), findsNothing,
        reason: 'the image detail closed');
    expect(find.byKey(const ValueKey('matome-detail-back')), findsOneWidget,
        reason: 'back returned to the matome hub');
  });
}
