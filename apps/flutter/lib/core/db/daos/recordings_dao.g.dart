// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recordings_dao.dart';

// ignore_for_file: type=lint
mixin _$RecordingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  RecordingsDaoManager get managers => RecordingsDaoManager(this);
}

class RecordingsDaoManager {
  final _$RecordingsDaoMixin _db;
  RecordingsDaoManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
}
