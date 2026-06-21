import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'matome_sync_service_test.dart' show FakeMatomesRepository;

/// Seed a single Matome. Inbox (coreId null) by default so the edit only writes
/// Drift — these widget tests assert the LOCAL-FIRST persistence, not the
/// network leg (the sync round-trip is covered in matome_sync_service_test).
Future<void> _seed(
  AppDatabase db, {
  required String id,
  String title = 'Old title',
  required DateTime happenedAt,
}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: Value(title),
      happenedAt: Value(happenedAt.millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
    ),
  );
}

Widget _app(ProviderContainer container, {required String id}) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildLightTheme(),
        home: MatomeDetailScreen(id: id),
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('matome-actions-trigger')));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container({List<Override> extra = const []}) {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db), ...extra],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('rename: dialog → controller → persisted (trimmed) title', (
    tester,
  ) async {
    await _seed(db, id: 'm_ren', title: 'Old title', happenedAt: DateTime(2026, 6, 8));

    await tester.pumpWidget(_app(container(), id: 'm_ren'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-rename')));
    await tester.pumpAndSettle();

    // Pre-filled with the current title.
    expect(find.text(t.matome.actions.renameTitle), findsOneWidget);
    expect(find.text('Old title'), findsWidgets);

    // Replace with a padded title; the dialog trims it.
    await tester.enterText(
      find.byKey(const ValueKey('matome-rename-field')),
      '  New title  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('matome-rename-save')));
    await tester.pumpAndSettle();

    // Persisted to Drift (local-first), trimmed.
    final row = await db.matomesDao.getById('m_ren');
    expect(row!.title, 'New title');
    expect(row.id, 'm_ren'); // PK stable

    // Confirmation surfaced.
    expect(find.text(t.matome.actions.renamed), findsOneWidget);
  });

  testWidgets('rename: an empty title is GUARDED — Save disabled, no write', (
    tester,
  ) async {
    await _seed(db, id: 'm_empty', title: 'Keep me', happenedAt: DateTime(2026, 6, 8));

    await tester.pumpWidget(_app(container(), id: 'm_empty'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-rename')));
    await tester.pumpAndSettle();

    // Clear the field to whitespace only — the non-empty guard kicks in.
    await tester.enterText(
      find.byKey(const ValueKey('matome-rename-field')),
      '   ',
    );
    await tester.pump();

    // Save is disabled (mirrors the server changeset's non-empty rule). The
    // underlying TextButton renders with a null onPressed.
    final saveButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('matome-rename-save')),
        matching: find.byType(TextButton),
      ),
    );
    expect(saveButton.onPressed, isNull);

    // The title is untouched.
    final row = await db.matomesDao.getById('m_empty');
    expect(row!.title, 'Keep me');
  });

  testWidgets('editDateTime: date + time pickers → persisted happenedAt', (
    tester,
  ) async {
    // Seeded on the 8th at 09:00; we re-date to the 20th, keeping the time.
    await _seed(
      db,
      id: 'm_dt',
      happenedAt: DateTime(2026, 6, 8, 9),
    );

    await tester.pumpWidget(_app(container(), id: 'm_dt'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-edit-datetime')));
    await tester.pumpAndSettle();

    // Date picker: pick the 20th, confirm with OK.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Time picker: keep the pre-filled time, confirm with OK.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Persisted to Drift (local-first): the day moved to the 20th.
    final row = await db.matomesDao.getById('m_dt');
    final stored = DateTime.fromMillisecondsSinceEpoch(row!.happenedAt);
    expect(stored.year, 2026);
    expect(stored.month, 6);
    expect(stored.day, 20);

    expect(find.text(t.matome.actions.editDateTimeUpdated), findsOneWidget);
  });

  testWidgets('editDateTime: reconciled matome round-trips Drift↔Core', (
    tester,
  ) async {
    // A reconciled, Core-backed matome (coreId 77) so the sync leg PATCHes Core.
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m_sync'),
        title: const Value('Synced'),
        coreId: const Value(77),
        happenedAt: Value(DateTime(2026, 6, 8, 9).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );

    final repo = FakeMatomesRepository();
    final c = container(
      extra: [matomesRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.pumpWidget(_app(c, id: 'm_sync'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-edit-datetime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Drift carries the new date AND Core was PATCHed by coreId (round-trip).
    final stored =
        DateTime.fromMillisecondsSinceEpoch((await db.matomesDao.getById('m_sync'))!.happenedAt);
    expect(stored.day, 20);
    expect(repo.updated, hasLength(1));
    expect(repo.updated.single['id'], 77);
  });
}
