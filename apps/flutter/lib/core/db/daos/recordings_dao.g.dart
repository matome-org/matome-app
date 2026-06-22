// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recordings_dao.dart';

// ignore_for_file: type=lint
mixin _$RecordingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $MatomesTable get matomes => attachedDatabase.matomes;
  $MatomeContactsTable get matomeContacts => attachedDatabase.matomeContacts;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $RecordingContactsTable get recordingContacts =>
      attachedDatabase.recordingContacts;
  RecordingsDaoManager get managers => RecordingsDaoManager(this);
}

class RecordingsDaoManager {
  final _$RecordingsDaoMixin _db;
  RecordingsDaoManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$MatomesTableTableManager get matomes =>
      $$MatomesTableTableManager(_db.attachedDatabase, _db.matomes);
  $$MatomeContactsTableTableManager get matomeContacts =>
      $$MatomeContactsTableTableManager(
        _db.attachedDatabase,
        _db.matomeContacts,
      );
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$RecordingContactsTableTableManager get recordingContacts =>
      $$RecordingContactsTableTableManager(
        _db.attachedDatabase,
        _db.recordingContacts,
      );
}
