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

/// The matome hub has an editable notes block (explicit edit mode + Save). This
/// mirrors [DetailsScreen]'s leave-guard: backing out with unsaved note edits
/// must NOT silently lose them — it prompts to keep editing or discard.

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

  Future<void> revealDetails(WidgetTester tester) async {
    final toggle = find.byKey(const ValueKey('matome-show-more'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/list',
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
            path: '/matome/:id',
            builder: (context, state) =>
                MatomeDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      );

  testWidgets('backing out with unsaved note edits prompts a leave-guard',
      (tester) async {
    await _seedMatome(db, id: 'm1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container(),
        child: TranslationProvider(
          child: MaterialApp.router(
            theme: buildLightTheme(),
            routerConfig: buildRouter(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the hub (pushed), reveal the detail, start editing notes.
    await tester.tap(find.byKey(const ValueKey('open-matome')));
    await tester.pumpAndSettle();
    await revealDetails(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-edit-notes')),
      200,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('matome-edit-notes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-edit-notes')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('matome-notes-field')));
    await tester.enterText(
      find.byKey(const ValueKey('matome-notes-field')),
      'a draft note I have not saved',
    );
    await tester.pumpAndSettle();

    // Try to back out — the leave-guard must intercept rather than strand the
    // edit. Keep editing first.
    await tester.tap(find.byKey(const ValueKey('matome-detail-back')));
    await tester.pumpAndSettle();

    expect(find.text(t.details.unsavedTitle), findsOneWidget);
    // Still on the hub (kept).
    await tester.tap(find.text(t.details.keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(MatomeDetailScreen), findsOneWidget);

    // Now back out and discard — returns to the list.
    await tester.tap(find.byKey(const ValueKey('matome-detail-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.details.discard));
    await tester.pumpAndSettle();
    expect(find.byType(MatomeDetailScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-matome')), findsOneWidget);
  });
}
