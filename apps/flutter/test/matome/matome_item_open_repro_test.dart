import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import '../support/item_fixtures.dart';

/// REPRODUCTION (TDD red) for the two file-view runtime bugs reported on the
/// live matome detail screen (#97 shipped work):
///
///   1. Tapping an IMAGE Item does not open its file-detail screen (audio does).
///   2. The '…' overflow menu on Items is buggy.
///
/// Unlike the original 1438 dispatch test (a plain MaterialApp), this drives the
/// REAL go_router routes the shipping app uses: `/matome/:id` PLUS the real
/// `/items/audio/:id` → [FileDetailScreen.byId]. That is the gap — the
/// imperative-root-push path the image tile uses was never exercised under the
/// real router.

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
  await insertTestFileItem(
    db,
    id: id,
    title: title,
    mediaType: mediaType,
    matomeId: matomeId,
    localPath: '/tmp/does-not-exist.bin',
    createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// A router faithful to production: the real `/matome/:id` and the real
  /// `/items/audio/:id` (→ [FileDetailScreen.byId]) routes, both on the
  /// root navigator — exactly the shape `lib/app/router.dart` uses for these
  /// two routes.
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/matome/m1',
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (_, _) => const Scaffold(body: Text('inbox-stub')),
        ),
        GoRoute(
          path: '/matome/:id',
          builder: (context, state) =>
              MatomeDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/items/audio/:id',
          builder: (context, state) =>
              FileDetailScreen.byId(id: state.pathParameters['id']!),
        ),
        // Image Items drill into the unified image host (#1438/#1450), a
        // SEPARATE route from the audio host — the live `lib/app/router.dart`
        // registers it, so a faithful repro router must too. Without it the
        // imperative `/items/image/:id` push has no match and nothing opens.
        GoRoute(
          path: '/items/image/:id',
          builder: (context, state) =>
              FileDetailScreen.imageById(id: state.pathParameters['id']!),
        ),
      ],
    );
  }

  Widget buildApp(ProviderContainer c, GoRouter router) {
    return UncontrolledProviderScope(
      container: c,
      child: TranslationProvider(
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
  }

  /// The matome letter reveals its child Items behind "Show more" on the narrow
  /// (phone, the live app) presentation — expand it and scroll to the tile.
  Future<void> revealItems(WidgetTester tester, Key tileKey) async {
    await tester.tap(find.byKey(const ValueKey('matome-show-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(tileKey), 200);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'BUG #1: tapping an image Item opens the file-detail screen and it STAYS',
    (tester) async {
      await _seedMatome(db, id: 'm1');
      await _seedItem(
        db,
        id: 'img1',
        matomeId: 'm1',
        mediaType: 'image',
        title: 'A photo',
      );

      await tester.pumpWidget(buildApp(container(), buildRouter()));
      await tester.pumpAndSettle();

      await revealItems(tester, const ValueKey('matome-image-img1'));

      // The image tile is present in the hub.
      expect(find.byKey(const ValueKey('matome-image-img1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('matome-image-img1')));
      await tester.pumpAndSettle();

      // A file-detail screen must appear AND survive a settle (a go_router
      // refreshListenable rebuild must not drop an imperatively-pushed route).
      expect(
        find.byKey(const ValueKey('file-detail-view')),
        findsOneWidget,
        reason: 'tapping an image Item must open its file-detail screen',
      );
      // And it must be the IMAGE host (its framed media header).
      expect(
        find.byKey(const ValueKey('file-detail-image-header')),
        findsOneWidget,
        reason: 'the image host (not the audio host) must render',
      );
    },
  );

  testWidgets(
    'CONTROL: tapping an audio Item opens its file-detail screen (works today)',
    (tester) async {
      await _seedMatome(db, id: 'm1');
      await _seedItem(
        db,
        id: 'aud1',
        matomeId: 'm1',
        mediaType: 'audio',
        title: 'A memo',
      );

      await tester.pumpWidget(buildApp(container(), buildRouter()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('matome-show-more')));
      await tester.pumpAndSettle();
      // The recording (audio) card has no per-id key, so reach it via its tile
      // wrapper key, then tap the card by title within it.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('matome-item-aud1')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('matome-item-aud1')),
          matching: find.text('A memo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('file-detail-view')), findsOneWidget);
    },
  );

  testWidgets(
    'BUG #2: the row long-press opens the actions sheet and Delete is '
    'reachable (no inline "…" — #1475)',
    (tester) async {
      await _seedMatome(db, id: 'm1');
      await _seedItem(
        db,
        id: 'img1',
        matomeId: 'm1',
        mediaType: 'image',
        title: 'A photo',
      );

      await tester.pumpWidget(buildApp(container(), buildRouter()));
      await tester.pumpAndSettle();

      await revealItems(tester, const ValueKey('matome-item-img1'));

      // The clean approved row carries NO inline overflow trigger (#1475).
      expect(
        find.byKey(const ValueKey('matome-item-overflow-img1')),
        findsNothing,
      );

      // Long-press the row → the actions sheet opens with the Delete entry.
      await tester.longPress(find.byKey(const ValueKey('matome-item-img1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('matome-item-overflow-img1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('matome-item-delete-img1')),
        findsOneWidget,
        reason: 'the long-press actions sheet must open with a Delete entry',
      );
      // And long-pressing must NOT also open the image detail (the gesture must
      // not leak through to the row's tap handler).
      expect(
        find.byKey(const ValueKey('file-detail-view')),
        findsNothing,
        reason: 'long-pressing must not also open the file detail',
      );
    },
  );
}
