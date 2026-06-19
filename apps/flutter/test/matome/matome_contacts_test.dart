import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/contacts/contacts_controller.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// #1375 — attaching contacts to a Matome. Exercises the controller's
/// attach/detach actions (the `matome_contacts` edge), the header chip render,
/// and the directory picker. The owner-id falls back to the placeholder (no
/// signed-in user under `flutter test`), matching the Contacts tab.
void main() {
  // The controller reads authStateProvider, whose AuthController touches the
  // (secure) token store on creation — give it a network-free in-memory store
  // and an initialized binding so no platform channel is hit.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seedMatome(String id, {String title = 'Standup'}) {
    return db.matomesDao.create(
      MatomesCompanion(
        id: Value(id),
        spaceId: const Value(null),
        title: Value(title),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> seedContact(
    String id, {
    required String name,
    String ownerId = kPlaceholderContactOwnerId,
  }) {
    return db.contactsDao.create(
      ContactsCompanion.insert(
        id: id,
        ownerId: ownerId,
        displayName: name,
        createdAt: DateTime(2026, 6, 1).millisecondsSinceEpoch,
      ),
    );
  }

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c, {required String id}) {
    return UncontrolledProviderScope(
      container: c,
      child: TranslationProvider(
        child: MaterialApp(
          theme: buildLightTheme(),
          home: MatomeDetailScreen(id: id),
        ),
      ),
    );
  }

  test('attachContact persists a matome_contacts edge; detachContact removes it',
      () async {
    await seedMatome('m1');
    await seedContact('c1', name: 'Ada');
    final c = container();
    final controller = c.read(matomeDetailControllerProvider('m1').notifier);
    await controller.load();

    await controller.attachContact('c1');

    final after = await db.contactsDao.listContactsForMatome('m1');
    expect(after, hasLength(1));
    expect(after.single.contact.id, 'c1');
    expect(after.single.role, 'attendee');
    expect(
      c.read(matomeDetailControllerProvider('m1')).contacts,
      hasLength(1),
    );

    await controller.detachContact('c1');
    expect(await db.contactsDao.listContactsForMatome('m1'), isEmpty);
    expect(c.read(matomeDetailControllerProvider('m1')).contacts, isEmpty);
  });

  test('attachContact is idempotent (UNIQUE matome_id+contact_id)', () async {
    await seedMatome('m2');
    await seedContact('c1', name: 'Ada');
    final c = container();
    final controller = c.read(matomeDetailControllerProvider('m2').notifier);
    await controller.load();

    await controller.attachContact('c1');
    await controller.attachContact('c1');

    expect(await db.contactsDao.listContactsForMatome('m2'), hasLength(1));
  });

  test('directoryContacts lists the owner contacts', () async {
    await seedMatome('m3');
    await seedContact('c1', name: 'Ada');
    await seedContact('c2', name: 'Babbage');
    // A contact owned by someone else must NOT appear.
    await seedContact('c3', name: 'Other', ownerId: 'user_999');
    final c = container();
    final controller = c.read(matomeDetailControllerProvider('m3').notifier);

    final dir = await controller.directoryContacts();
    expect(dir.map((e) => e.id), containsAll(<String>['c1', 'c2']));
    expect(dir.map((e) => e.id), isNot(contains('c3')));
  });

  testWidgets('attaching via the picker renders a chip; detach removes it',
      (tester) async {
    await seedMatome('m4');
    await seedContact('c1', name: 'Ada');
    final c = container();

    await tester.pumpWidget(app(c, id: 'm4'));
    await tester.pumpAndSettle();

    // The add-contact affordance is in the reserved header slot.
    expect(find.byKey(const ValueKey('matome-add-contact')), findsOneWidget);

    // Open the picker — it lists the owner's directory contact.
    await tester.tap(find.byKey(const ValueKey('matome-add-contact')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('matome-pick-contact-c1')),
      findsOneWidget,
    );

    // Pick it → attaches + renders a chip.
    await tester.tap(find.byKey(const ValueKey('matome-pick-contact-c1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('matome-contact-c1')), findsOneWidget);
    expect(find.text('Ada'), findsWidgets);
    expect(find.text(t.matome.roleAttendee), findsWidgets);
    expect(await db.contactsDao.listContactsForMatome('m4'), hasLength(1));

    // Detach via the chip's remove affordance.
    await tester.tap(find.byKey(const ValueKey('matome-contact-remove-c1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('matome-contact-c1')), findsNothing);
    expect(await db.contactsDao.listContactsForMatome('m4'), isEmpty);
  });

  testWidgets('the tag-contacts coming-soon stub is replaced; Share remains',
      (tester) async {
    await seedMatome('m5');
    final c = container();

    await tester.pumpWidget(app(c, id: 'm5'));
    await tester.pumpAndSettle();

    // #1372 deferred tag-contacts row is gone.
    expect(find.byKey(const ValueKey('matome-tag-contacts')), findsNothing);
    // Share is the only remaining deferred affordance.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-share')),
      200,
    );
    expect(find.byKey(const ValueKey('matome-share')), findsOneWidget);
  });
}
