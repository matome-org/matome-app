import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/items/text_item_host.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import '../support/item_fixtures.dart';

final _testOwnerProvider = StateProvider<String?>((ref) => '1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    LocaleSettings.setLocaleRaw('en');
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  testWidgets('TextItemHost renders and saves a plain-text item', (
    tester,
  ) async {
    await insertTestTextItem(
      db,
      id: '100',
      body: 'Original note',
      matomeId: '7',
      position: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: '100'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text note'), findsWidgets);
    expect(find.text('Original note'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('text-item-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-item-field')),
      'Updated plain text',
    );
    await tester.tap(find.byKey(const ValueKey('text-item-save')));
    await tester.pumpAndSettle();

    final row = await (db.select(
      db.textContents,
    )..where((tbl) => tbl.id.equals('text_content_100'))).getSingle();
    expect(row.body, 'Updated plain text');
    expect(find.text('Updated plain text'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('renders typed text summary and truthful failed retry state', (
    tester,
  ) async {
    await insertTestTextItem(
      db,
      id: 'summary',
      body: 'Original note remains user-owned',
      coreId: 42,
      summary: 'Machine-generated summary',
      processingState: ProcessingState.failed,
      processingRunId: 'run-text',
      processingAttempt: 1,
      processingErrorCode: 'processor_unavailable',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: 'summary'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original note remains user-owned'), findsOneWidget);
    expect(find.text('Machine-generated summary'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('text-item-processing-retry')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('keeps original separate and exposes pending sync honestly', (
    tester,
  ) async {
    await insertTestTextItem(
      db,
      id: 'pending',
      body: 'Editable original',
      summary: 'Generated summary',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: 'pending'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editable original'), findsOneWidget);
    expect(find.text('Generated summary'), findsOneWidget);
    expect(find.byKey(const ValueKey('text-item-sync-status')), findsOneWidget);
    expect(find.text('Saved on device · waiting to sync'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('surfaces durable sync failure with a queue retry action', (
    tester,
  ) async {
    await insertTestTextItem(db, id: 'failed-sync', body: 'Still local');
    await db.itemsDao.updateItem(
      'failed-sync',
      '1',
      const ItemsCompanion(syncState: Value('failed')),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: 'failed-sync'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync failed · retry to continue'), findsOneWidget);
    expect(find.byKey(const ValueKey('text-item-sync-retry')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('reacts when the authenticated owner changes', (tester) async {
    await insertTestTextItem(db, id: 'owner-bound', body: 'Owner one note');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWith(
            (ref) => ref.watch(_testOwnerProvider),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: 'owner-bound'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Owner one note'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextItemHost)),
    );
    container.read(_testOwnerProvider.notifier).state = '2';
    await tester.pumpAndSettle();

    expect(find.text('Owner one note'), findsNothing);
    expect(find.text('Text note not found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('delete conflict is visible and can be explicitly retried', (
    tester,
  ) async {
    await insertTestTextItem(
      db,
      id: 'delete-conflict',
      body: 'Preserved local body',
      coreId: 42,
    );
    await db.itemsDao.updateItem(
      'delete-conflict',
      '1',
      const ItemsCompanion(
        acceptedSourceRevision: Value(2),
        syncState: Value('conflict'),
        isDirty: Value(true),
        isDeleted: Value(false),
      ),
    );
    await db.itemsDao.updateText(
      'delete-conflict',
      '1',
      const TextContentsCompanion(
        acceptedBody: Value('Remote newer body'),
        isDirty: Value(true),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: 'delete-conflict'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preserved local body'), findsOneWidget);
    expect(
      find.text('Sync conflict · your local text is preserved'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('text-item-delete')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
