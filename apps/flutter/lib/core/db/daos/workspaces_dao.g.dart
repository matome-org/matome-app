// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspaces_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkspacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $MatomesTable get matomes => attachedDatabase.matomes;
  WorkspacesDaoManager get managers => WorkspacesDaoManager(this);
}

class WorkspacesDaoManager {
  final _$WorkspacesDaoMixin _db;
  WorkspacesDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$MatomesTableTableManager get matomes =>
      $$MatomesTableTableManager(_db.attachedDatabase, _db.matomes);
}
