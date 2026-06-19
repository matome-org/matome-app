// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matomes_dao.dart';

// ignore_for_file: type=lint
mixin _$MatomesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MatomesTable get matomes => attachedDatabase.matomes;
  $RecordingsTable get recordings => attachedDatabase.recordings;
  MatomesDaoManager get managers => MatomesDaoManager(this);
}

class MatomesDaoManager {
  final _$MatomesDaoMixin _db;
  MatomesDaoManager(this._db);
  $$MatomesTableTableManager get matomes =>
      $$MatomesTableTableManager(_db.attachedDatabase, _db.matomes);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
}
