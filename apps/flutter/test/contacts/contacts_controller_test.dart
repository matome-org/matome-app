import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/contacts/contacts_controller.dart';

/// Unit tests for [ContactsController] (#1374): create / edit / delete go
/// through the DAO under the placeholder owner id (no auth user overridden),
/// and `notes` round-trip through the `metadata` JSON blob.

void main() {
  // The controller reads authStateProvider, whose AuthController touches the
  // (secure) token store on creation — give it a network-free in-memory store
  // and an initialized binding so no platform channel is hit.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  ContactsController controller() =>
      container.read(contactsControllerProvider.notifier);

  Future<List<ContactRow>> awaitList() async {
    final c = controller();
    await c.load();
    return container.read(contactsControllerProvider).requireValue;
  }

  test('uses the placeholder owner id when no user is signed in', () {
    expect(controller().ownerId, kPlaceholderContactOwnerId);
  });

  test('createContact persists under the owner and lists it', () async {
    await controller().createContact(
      displayName: 'Ada',
      notes: 'ada@example.com',
    );

    final rows = await awaitList();
    expect(rows.single.displayName, 'Ada');
    expect(contactNotes(rows.single), 'ada@example.com');
    expect(rows.single.ownerId, kPlaceholderContactOwnerId);
  });

  test('createContact ignores a blank display name', () async {
    await controller().createContact(displayName: '   ');
    expect(await awaitList(), isEmpty);
  });

  test('updateContact rewrites name and notes', () async {
    await controller().createContact(displayName: 'Before', notes: 'old');
    final id = (await awaitList()).single.id;

    await controller().updateContact(
      id: id,
      displayName: 'After',
      notes: 'new',
    );

    final row = await db.contactsDao.getById(id);
    expect(row?.displayName, 'After');
    expect(contactNotes(row!), 'new');
  });

  test('empty notes round-trip to the default {} metadata', () async {
    await controller().createContact(displayName: 'NoNotes');
    final row = (await awaitList()).single;
    expect(row.metadata, '{}');
    expect(contactNotes(row), '');
  });

  test('deleteContact removes the row', () async {
    await controller().createContact(displayName: 'Gone');
    final id = (await awaitList()).single.id;

    await controller().deleteContact(id);

    expect(await awaitList(), isEmpty);
    expect(await db.contactsDao.getById(id), isNull);
  });
}
