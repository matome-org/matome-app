import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/items/text_item_host.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

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
    await db
        .into(db.textContents)
        .insert(
          TextContentsCompanion.insert(
            id: const Value(20),
            body: 'Original note',
          ),
        );
    await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            id: const Value(100),
            matomeId: 7,
            position: 1,
            itemType: 'text',
            textContentId: const Value(20),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const TextItemHost(itemId: 100),
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
    )..where((tbl) => tbl.id.equals(20))).getSingle();
    expect(row.body, 'Updated plain text');
    expect(find.text('Updated plain text'), findsOneWidget);
  });
}
