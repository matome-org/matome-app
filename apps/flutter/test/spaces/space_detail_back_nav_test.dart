import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/spaces/space_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Navigation tests for the Space detail screen's back affordance (the same
/// strand-the-user defect the matome hub had): the explicit `BackButton` pops
/// to the REAL origin when there is a stack (push from the spaces list), and
/// falls back to `/spaces` only when there is genuinely nothing to pop (a
/// deep-link / redirect entry with an empty stack). Previously 100% untested.
void main() {
  late AppDatabase db;
  late String spaceId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final work = await db.workspacesDao.createWorkspace('Work');
    spaceId = work.id;
  });
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// A router with a spaces-list stub that PUSHES the space detail, plus the
  /// `/spaces` root used as the deep-link fallback target.
  GoRouter buildRouter({required String initialLocation}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/spaces',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('open-space'),
                onPressed: () => context.push('/spaces/$spaceId'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/spaces/:spaceId',
          builder: (context, state) =>
              SpaceDetailScreen(spaceId: state.pathParameters['spaceId']!),
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

  testWidgets('push from spaces list leaves canPop true; back pops to origin', (
    tester,
  ) async {
    final router = buildRouter(initialLocation: '/spaces');
    await tester.pumpWidget(buildApp(container(), router));
    await tester.pumpAndSettle();

    // Push the detail from the list.
    await tester.tap(find.byKey(const ValueKey('open-space')));
    await tester.pumpAndSettle();

    // We are on the detail and it can pop (proves push, not go/replace).
    expect(find.byType(SpaceDetailScreen), findsOneWidget);
    final context = tester.element(find.byType(SpaceDetailScreen));
    expect(context.canPop(), isTrue);

    // Back returns to the real origin (the spaces list), not the /spaces root
    // via a fresh go — the list button is back on screen.
    await tester.tap(find.byKey(const ValueKey('space-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byType(SpaceDetailScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-space')), findsOneWidget);
  });

  testWidgets('deep-link entry (empty stack) falls back to /spaces', (
    tester,
  ) async {
    final router = buildRouter(initialLocation: '/spaces/$spaceId');
    await tester.pumpWidget(buildApp(container(), router));
    await tester.pumpAndSettle();

    // No stack to pop on a deep-link entry.
    final context = tester.element(find.byType(SpaceDetailScreen));
    expect(context.canPop(), isFalse);

    await tester.tap(find.byKey(const ValueKey('space-detail-back')));
    await tester.pumpAndSettle();

    // Fell back to the spaces root rather than stranding the user.
    expect(find.byType(SpaceDetailScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-space')), findsOneWidget);
  });
}
