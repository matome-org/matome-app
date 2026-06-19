import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/contacts/contacts_controller.dart';
import 'package:matome_flutter/features/contacts/contacts_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Widget tests for the Contacts tab (#1374): the directory renders the owner's
/// contacts, the FAB-create modal adds a contact, tapping a tile edits it, and
/// long-press + confirm deletes it. No auth user is overridden, so the
/// placeholder owner id is used throughout.

Widget _app(AppDatabase db) {
  final router = GoRouter(
    initialLocation: '/contacts',
    routes: [
      GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen()),
    ],
  );

  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: TranslationProvider(
      child: MaterialApp.router(theme: buildLightTheme(), routerConfig: router),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('empty directory shows the empty state', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.text(t.contacts.empty), findsOneWidget);
    expect(find.text(t.contacts.emptyHint), findsOneWidget);
  });

  testWidgets('renders the owner contacts list', (tester) async {
    await db.contactsDao.create(
      _contactCompanion(id: 'c1', name: 'Ada Lovelace'),
    );
    await db.contactsDao.create(
      _contactCompanion(id: 'c2', name: 'Grace Hopper'),
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text(t.contacts.count(n: 2)), findsOneWidget);
  });

  testWidgets('create modal adds a contact', (tester) async {
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Alan Turing');
    await tester.tap(find.byKey(const ValueKey('save-contact-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Alan Turing'), findsOneWidget);
    final rows =
        await db.contactsDao.listContactsForOwner(kPlaceholderContactOwnerId);
    expect(rows.single.displayName, 'Alan Turing');
  });

  testWidgets('tapping a contact opens the edit modal and saves changes', (
    tester,
  ) async {
    await db.contactsDao.create(_contactCompanion(id: 'c1', name: 'Old Name'));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('contact-tile-c1')));
    await tester.pumpAndSettle();

    expect(find.text(t.contacts.editTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'New Name');
    await tester.tap(find.byKey(const ValueKey('save-contact-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('Old Name'), findsNothing);
    final row = await db.contactsDao.getById('c1');
    expect(row?.displayName, 'New Name');
  });

  testWidgets('long-press + confirm deletes the contact', (tester) async {
    await db.contactsDao.create(_contactCompanion(id: 'c1', name: 'Doomed'));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('contact-tile-c1')));
    await tester.pumpAndSettle();

    expect(find.text(t.contacts.deleteTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-contact-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Doomed'), findsNothing);
    expect(await db.contactsDao.getById('c1'), isNull);
  });

  testWidgets('cancelling delete keeps the contact', (tester) async {
    await db.contactsDao.create(_contactCompanion(id: 'c1', name: 'Kept'));

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('contact-tile-c1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.contacts.cancel));
    await tester.pumpAndSettle();

    expect(find.text('Kept'), findsOneWidget);
  });
}

ContactsCompanion _contactCompanion({
  required String id,
  required String name,
}) {
  return ContactsCompanion.insert(
    id: id,
    ownerId: kPlaceholderContactOwnerId,
    displayName: name,
    createdAt: DateTime(2026, 6, 19).millisecondsSinceEpoch,
  );
}
