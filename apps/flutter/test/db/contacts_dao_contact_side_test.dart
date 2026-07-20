import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';

import '../support/item_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('direct Item contact link round-trips owner-scoped', () async {
    await db.contactsDao.create(
      ContactsCompanion.insert(
        id: 'contact',
        ownerId: '1',
        displayName: 'Alice',
        createdAt: 1,
      ),
    );
    await insertTestFileItem(db, id: 'file');
    await db.contactsDao.linkContactToItem(
      itemId: 'file',
      contactId: 'contact',
    );

    expect(
      (await db.contactsDao.listContactsForFile(
        'file',
        '1',
      )).single.displayName,
      'Alice',
    );
    expect(await db.contactsDao.listContactsForFile('file', '2'), isEmpty);
    expect(
      (await db.contactsDao.listFilesForContact('contact', '1')).single.id,
      'file',
    );
  });

  test(
    'contact files union de-duplicates direct and Matome membership',
    () async {
      await db.contactsDao.create(
        ContactsCompanion.insert(
          id: 'contact',
          ownerId: '1',
          displayName: 'Alice',
          createdAt: 1,
        ),
      );
      await db.matomesDao.create(
        MatomesCompanion.insert(
          id: 'matome',
          title: 'Meeting',
          happenedAt: 1,
          createdAt: 1,
        ),
      );
      await db.contactsDao.addContactToMatome(
        matomeId: 'matome',
        contactId: 'contact',
      );
      await insertTestFileItem(db, id: 'file', matomeId: 'matome');
      await db.contactsDao.linkContactToItem(
        itemId: 'file',
        contactId: 'contact',
      );

      final files = await db.contactsDao.listFilesForContactUnion(
        'contact',
        '1',
      );
      expect(files.map((file) => file.id), ['file']);
    },
  );
}
