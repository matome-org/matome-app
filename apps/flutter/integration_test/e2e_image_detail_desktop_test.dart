import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

import 'support/e2e_harness.dart';
import '../test/support/item_fixtures.dart';

/// A repo whose presigned-download call NEVER completes — simulates a real Core
/// that is slow/unreachable for a SYNCED image (storage-key path, no local
/// file). The audio-centric details load awaits this for an image it does not
/// even need an audio source for.
class _HangingDownloadRepo extends RecordingsRepository {
  _HangingDownloadRepo({required super.apiClient});
  @override
  Future<String?> downloadUrl(int id) => Completer<String?>().future;
}

/// Seed-and-tap repro for the image-detail bug, at DESKTOP width (the failing
/// scenario in the screenshots). Unlike the prior test it asserts the IMAGE
/// VIEWER actually rendered (`file-detail-image-header`), not merely that some
/// FileDetailScreen wrapper exists — the wrapper is present even when the
/// dispatch falls through to the audio host.

Future<void> _seedMatome(AppDatabase db, {required String id}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: const Value('Screenshot matome'),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );
}

Future<void> _seedImage(
  AppDatabase db, {
  required String id,
  required String matomeId,
}) async {
  await insertTestFileItem(
    db,
    id: id,
    title: 'screenshot-2026-06-20',
    coreId: 1,
    createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    mediaType: 'image',
    matomeId: matomeId,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DESKTOP: tapping a seeded image opens the image viewer', (
    tester,
  ) async {
    // Desktop / wide viewport — the two-pane home the screenshots show.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedMatome(db, id: 'm1');
    await _seedImage(db, id: 'img1', matomeId: 'm1');

    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');

    await tester.pumpWidget(
      buildE2EApp(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          authRepositoryProvider.overrideWithValue(
            FakeE2EAuthRepository(store),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The exact desktop scenario: select the matome in the wide inbox list →
    // it opens in the embedded right-pane detail (not a pushed route).
    final card = find.byKey(const ValueKey('matome-card-m1'));
    expect(card, findsOneWidget, reason: 'seeded matome shows in the inbox');
    await tester.tap(card);
    await tester.pumpAndSettle();

    // Reveal the items if collapsed behind a "show more".
    final showMore = find.byKey(const ValueKey('matome-show-more'));
    if (showMore.evaluate().isNotEmpty) {
      await tester.tap(showMore.first);
      await tester.pumpAndSettle();
    }

    final imageTile = find.byKey(const ValueKey('matome-image-img1'));
    expect(imageTile, findsWidgets, reason: 'the seeded image tile is present');
    await tester.ensureVisible(imageTile.first);
    await tester.pumpAndSettle();
    await tester.tap(imageTile.first);
    await tester.pumpAndSettle();

    // THE assertion the prior test missed: the IMAGE media header rendered —
    // i.e. the dispatch reached _ImageDetailHost, not the audio fallback.
    final imageHeader = find.byKey(const ValueKey('file-detail-image-header'));
    expect(
      imageHeader,
      findsOneWidget,
      reason:
          'the image viewer (image media header) must render, not the '
          'audio host fallback',
    );
    // And it is actually laid out (non-zero size), not an offstage shell.
    expect(tester.getSize(imageHeader).height, greaterThan(0));
    // It COVERS the home two-pane — the inbox list card behind is no longer
    // hit-testable (the screenshots showed the home visible *behind* a header).
    expect(
      find.byKey(const ValueKey('matome-card-m1')).hitTestable(),
      findsNothing,
      reason:
          'the image detail must cover the home, not leave it showing '
          'behind a header',
    );
  });

  testWidgets(
    'DESKTOP + slow Core: a synced image whose downloadUrl hangs still shows '
    'the image viewer (must NOT get stuck on the audio loading host)',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedMatome(db, id: 'm1');
      await _seedImage(db, id: 'img1', matomeId: 'm1');

      final store = InMemoryTokenStore();
      await store.saveTokens(accessToken: 'a', refreshToken: 'r');

      await tester.pumpWidget(
        buildE2EApp(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            tokenStoreProvider.overrideWithValue(store),
            settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
            authRepositoryProvider.overrideWithValue(
              FakeE2EAuthRepository(store),
            ),
            recordingsRepositoryProvider.overrideWith(
              (ref) =>
                  _HangingDownloadRepo(apiClient: ref.watch(apiClientProvider)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('matome-card-m1'));
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();

      final showMore = find.byKey(const ValueKey('matome-show-more'));
      if (showMore.evaluate().isNotEmpty) {
        await tester.tap(showMore.first);
        await tester.pumpAndSettle();
      }

      final imageTile = find.byKey(const ValueKey('matome-image-img1'));
      await tester.ensureVisible(imageTile.first);
      await tester.pumpAndSettle();
      await tester.tap(imageTile.first);
      // downloadUrl hangs, so the load future never completes — do NOT
      // pumpAndSettle (it would time out). Pump fixed frames instead.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      final imageHeader = find.byKey(
        const ValueKey('file-detail-image-header'),
      );
      expect(
        imageHeader,
        findsOneWidget,
        reason:
            'image detail must render immediately from the Item in hand — '
            'it must NOT wait on the audio-source downloadUrl (which an image '
            'does not need) and get stuck on the audio loading host',
      );
    },
  );
}
