// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspaces_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkspacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $ItemsTable get items => attachedDatabase.items;
  $MatomesTable get matomes => attachedDatabase.matomes;
  WorkspacesDaoManager get managers => WorkspacesDaoManager(this);
}

class WorkspacesDaoManager {
  final _$WorkspacesDaoMixin _db;
  WorkspacesDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db.attachedDatabase, _db.items);
  $$MatomesTableTableManager get matomes =>
      $$MatomesTableTableManager(_db.attachedDatabase, _db.matomes);
}
