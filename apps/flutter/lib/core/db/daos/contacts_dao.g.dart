// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contacts_dao.dart';

// ignore_for_file: type=lint
mixin _$ContactsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $MatomeContactsTable get matomeContacts => attachedDatabase.matomeContacts;
  $SpaceContactsTable get spaceContacts => attachedDatabase.spaceContacts;
  $MatomeSharesTable get matomeShares => attachedDatabase.matomeShares;
  ContactsDaoManager get managers => ContactsDaoManager(this);
}

class ContactsDaoManager {
  final _$ContactsDaoMixin _db;
  ContactsDaoManager(this._db);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$MatomeContactsTableTableManager get matomeContacts =>
      $$MatomeContactsTableTableManager(
        _db.attachedDatabase,
        _db.matomeContacts,
      );
  $$SpaceContactsTableTableManager get spaceContacts =>
      $$SpaceContactsTableTableManager(_db.attachedDatabase, _db.spaceContacts);
  $$MatomeSharesTableTableManager get matomeShares =>
      $$MatomeSharesTableTableManager(_db.attachedDatabase, _db.matomeShares);
}
