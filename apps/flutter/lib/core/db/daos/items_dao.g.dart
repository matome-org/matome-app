// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'items_dao.dart';

// ignore_for_file: type=lint
mixin _$ItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ItemsTable get items => attachedDatabase.items;
  $FileBlobsTable get fileBlobs => attachedDatabase.fileBlobs;
  $TextContentsTable get textContents => attachedDatabase.textContents;
  ItemsDaoManager get managers => ItemsDaoManager(this);
}

class ItemsDaoManager {
  final _$ItemsDaoMixin _db;
  ItemsDaoManager(this._db);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db.attachedDatabase, _db.items);
  $$FileBlobsTableTableManager get fileBlobs =>
      $$FileBlobsTableTableManager(_db.attachedDatabase, _db.fileBlobs);
  $$TextContentsTableTableManager get textContents =>
      $$TextContentsTableTableManager(_db.attachedDatabase, _db.textContents);
}
