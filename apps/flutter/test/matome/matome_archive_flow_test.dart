import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/features/matome/matome_sync_service.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// A sync service whose archive write succeeds locally (so the optimistic
/// removal happens) but then THROWS, exercising the rollback path. Restore is
/// real so the rollback can be observed in Drift.
class _FailingArchiveSyncService extends MatomeSyncService {
  _FailingArchiveSyncService(super.ref, this._db);

  final AppDatabase _db;

  @override
  Future<void> archiveMatome(String id) async {
    // Local-first write lands first (optimistic removal), then sync fails.
    await _db.matomesDao.archive(id);
    throw Exception('archive sync failed');
  }

  @override
  Future<void> restoreMatome(String id) => _db.matomesDao.restore(id);
}

Future<void> _seed(AppDatabase db, {required String id, String? summary}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: const Value('Standup notes'),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      aggregatedSummary: Value(summary),
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

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ProviderContainer container({List<Override> extra = const []}) {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db), ...extra],
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('copy summary copies the aggregated summary to the clipboard', (
    tester,
  ) async {
    await _seed(db, id: 'm1', summary: 'Roadmap discussed.');

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(_app(container(), id: 'm1'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-copy')));
    await tester.pumpAndSettle();

    expect(copied, 'Roadmap discussed.');
    expect(find.text(t.matome.actions.summaryCopied), findsOneWidget);
  });

  testWidgets('archive confirm optimistically removes the matome from lists', (
    tester,
  ) async {
    await _seed(db, id: 'm_arch');

    await tester.pumpWidget(_app(container(), id: 'm_arch'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-archive')));
    await tester.pumpAndSettle();

    // Confirm dialog → archive.
    await tester.tap(find.byKey(const ValueKey('matome-archive-confirm')));
    await tester.pumpAndSettle();

    // Soft-deleted: archived_at stamped, so it leaves every list (which exclude
    // archived rows).
    final row = await db.matomesDao.getById('m_arch');
    expect(row!.archivedAt, isNotNull);

    // Undo affordance surfaced.
    expect(find.text(t.matome.actions.archived), findsOneWidget);
    expect(find.text(t.matome.actions.undo), findsOneWidget);
  });

  testWidgets('Undo restores the archived matome', (tester) async {
    await _seed(db, id: 'm_undo');

    await tester.pumpWidget(_app(container(), id: 'm_undo'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-archive-confirm')));
    await tester.pumpAndSettle();

    expect((await db.matomesDao.getById('m_undo'))!.archivedAt, isNotNull);

    await tester.tap(find.text(t.matome.actions.undo));
    await tester.pumpAndSettle();

    // Restored → back in the lists.
    expect((await db.matomesDao.getById('m_undo'))!.archivedAt, isNull);
  });

  testWidgets('archive failure rolls the optimistic removal back', (
    tester,
  ) async {
    await _seed(db, id: 'm_fail');

    final c = container(
      extra: [
        matomeSyncServiceProvider.overrideWith(
          (ref) => _FailingArchiveSyncService(ref, db),
        ),
      ],
    );

    await tester.pumpWidget(_app(c, id: 'm_fail'));
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('matome-action-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-archive-confirm')));
    await tester.pumpAndSettle();

    // The optimistic removal was rolled back: the row is NOT archived.
    final row = await db.matomesDao.getById('m_fail');
    expect(row!.archivedAt, isNull);

    // The error is surfaced, and no Undo SnackBar is shown.
    expect(find.text(t.matome.actions.archiveFailed), findsOneWidget);
    expect(find.text(t.matome.actions.archived), findsNothing);
  });
}
