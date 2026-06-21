import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Navigation tests for the matome detail hub (the strand-the-user defect):
///   * the non-embedded hub always renders a visible back affordance,
///   * tapping it pops back to the previous list (when there is a stack),
///   * deep-link entry (empty stack) falls back to `/inbox` rather than
///     stranding the user,
///   * opening the hub from a list with `context.push` leaves `canPop()` true,
///   * the embedded two-pane path renders NO back affordance (nothing to pop).

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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// A router with a list stub that PUSHES the matome hub (the standardized
  /// detail navigation) plus an inbox stub for the deep-link fallback.
  GoRouter buildRouter({required String initialLocation}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/list',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('open-matome'),
                onPressed: () => context.push('/matome/m1'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/inbox',
          builder: (_, _) => const Scaffold(body: Text('inbox-stub')),
        ),
        GoRoute(
          path: '/matome/:id',
          builder: (context, state) =>
              MatomeDetailScreen(id: state.pathParameters['id']!),
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

  testWidgets('non-embedded hub renders an always-visible back affordance',
      (tester) async {
    await _seedMatome(db, id: 'm1');
    await tester.pumpWidget(buildApp(container(), buildRouter(initialLocation: '/matome/m1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('matome-detail-back')), findsOneWidget);
  });

  testWidgets('opening the hub from a list (push) leaves canPop true; back pops',
      (tester) async {
    await _seedMatome(db, id: 'm1');
    final router = buildRouter(initialLocation: '/list');
    await tester.pumpWidget(buildApp(container(), router));
    await tester.pumpAndSettle();

    // Push the detail from the list.
    await tester.tap(find.byKey(const ValueKey('open-matome')));
    await tester.pumpAndSettle();

    // We are on the hub and it can pop (proves push, not go/replace).
    expect(find.byType(MatomeDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-detail-back')), findsOneWidget);
    final context = tester.element(find.byType(MatomeDetailScreen));
    expect(context.canPop(), isTrue);

    // Tapping back returns to the list (the hub is gone, the list button is
    // back on screen).
    await tester.tap(find.byKey(const ValueKey('matome-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byType(MatomeDetailScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-matome')), findsOneWidget);
  });

  testWidgets('deep-link entry (empty stack) falls back to /inbox', (tester) async {
    await _seedMatome(db, id: 'm1');
    final router = buildRouter(initialLocation: '/matome/m1');
    await tester.pumpWidget(buildApp(container(), router));
    await tester.pumpAndSettle();

    // No stack to pop on a deep-link entry.
    final context = tester.element(find.byType(MatomeDetailScreen));
    expect(context.canPop(), isFalse);

    await tester.tap(find.byKey(const ValueKey('matome-detail-back')));
    await tester.pumpAndSettle();

    expect(find.text('inbox-stub'), findsOneWidget);
  });

  testWidgets('embedded two-pane path renders NO back affordance', (tester) async {
    await _seedMatome(db, id: 'm1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container(),
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(
              body: MatomeDetailScreen(id: 'm1', embedded: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('matome-detail-back')), findsNothing);
    // The embedded path drops the Scaffold/AppBar entirely.
    expect(find.byType(AppBar), findsNothing);
  });
}
