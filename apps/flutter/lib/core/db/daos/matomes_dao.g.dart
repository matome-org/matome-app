// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matomes_dao.dart';

// ignore_for_file: type=lint
mixin _$MatomesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MatomesTable get matomes => attachedDatabase.matomes;
  $ItemsTable get items => attachedDatabase.items;
  $FileBlobsTable get fileBlobs => attachedDatabase.fileBlobs;
  $MatomeContactsTable get matomeContacts => attachedDatabase.matomeContacts;
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  MatomesDaoManager get managers => MatomesDaoManager(this);
}

class MatomesDaoManager {
  final _$MatomesDaoMixin _db;
  MatomesDaoManager(this._db);
  $$MatomesTableTableManager get matomes =>
      $$MatomesTableTableManager(_db.attachedDatabase, _db.matomes);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db.attachedDatabase, _db.items);
  $$FileBlobsTableTableManager get fileBlobs =>
      $$FileBlobsTableTableManager(_db.attachedDatabase, _db.fileBlobs);
  $$MatomeContactsTableTableManager get matomeContacts =>
      $$MatomeContactsTableTableManager(
        _db.attachedDatabase,
        _db.matomeContacts,
      );
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
}
