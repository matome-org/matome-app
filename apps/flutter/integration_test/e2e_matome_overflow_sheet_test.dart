import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/auth/auth_controller.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';

import 'support/e2e_harness.dart';
import '../test/support/item_fixtures.dart';

/// Ground-truth probes against the REAL production [routerProvider]: does a
/// go_router rebuild (auth tick / matome reload) dismiss an imperatively-opened
/// modal route living on go_router's ROOT navigator?
///
///   * the '…' overflow bottom sheet (BUG #2 candidate)
///   * the image-tile push → its file-detail screen (BUG #1 candidate)
///   * the fullscreen image viewer (pushed root-nav inside the detail host)

Future<void> _seed(AppDatabase db) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: const Value('m1'),
      title: const Value('Standup notes'),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );
  await insertTestFileItem(
    db,
    id: 'img1',
    title: 'A photo',
    durationSeconds: 10,
    localPath: '/tmp/does-not-exist.bin',
    createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    mediaType: 'image',
    matomeId: 'm1',
  );
}

Future<void> _bootToHubItems(WidgetTester tester, AppDatabase db) async {
  final store = InMemoryTokenStore();
  await store.saveTokens(accessToken: 'a', refreshToken: 'r');
  await tester.pumpWidget(
    buildE2EApp(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(store),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        authRepositoryProvider.overrideWithValue(FakeE2EAuthRepository(store)),
      ],
    ),
  );
  await tester.pumpAndSettle();
  final ctx = tester.element(find.byType(Navigator).first);
  GoRouter.of(ctx).push('/matome/m1');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('matome-show-more')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('matome-item-overflow-img1')),
    200,
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PROBE: overflow sheet survives a matome reload (go_router rebuild)',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      await _bootToHubItems(tester, db);

      await tester.tap(find.byKey(const ValueKey('matome-item-overflow-img1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('matome-item-delete-img1')),
        findsOneWidget,
        reason: 'sheet opened',
      );

      // Force a go_router rebuild while the modal sheet is open: an auth tick.
      final ctx = tester.element(find.byType(Navigator).first);
      final container = ProviderScope.containerOf(ctx);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'dev@matome.test', password: 'x');
      // Also reload the matome controller (a routine live event).
      await container
          .read(matomeDetailControllerProvider('m1').notifier)
          .load();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('matome-item-delete-img1')),
        findsOneWidget,
        reason: 'the overflow sheet must SURVIVE a go_router rebuild',
      );
    },
  );

  testWidgets(
    'PROBE: image detail survives a matome reload (go_router rebuild)',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      await _bootToHubItems(tester, db);

      await tester.tap(find.byKey(const ValueKey('matome-image-img1')));
      await tester.pumpAndSettle();
      expect(
        find.byType(FileDetailScreen),
        findsOneWidget,
        reason: 'image opened',
      );

      final ctx = tester.element(find.byType(Navigator).first);
      final container = ProviderScope.containerOf(ctx);
      await container
          .read(matomeDetailControllerProvider('m1').notifier)
          .load();
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'dev@matome.test', password: 'x');
      await tester.pumpAndSettle();

      expect(
        find.byType(FileDetailScreen),
        findsOneWidget,
        reason: 'the image detail must SURVIVE a go_router rebuild',
      );
    },
  );
}
