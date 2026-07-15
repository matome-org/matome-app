// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_queue_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkQueueDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkQueueTable get workQueue => attachedDatabase.workQueue;
  $ItemsTable get items => attachedDatabase.items;
  WorkQueueDaoManager get managers => WorkQueueDaoManager(this);
}

class WorkQueueDaoManager {
  final _$WorkQueueDaoMixin _db;
  WorkQueueDaoManager(this._db);
  $$WorkQueueTableTableManager get workQueue =>
      $$WorkQueueTableTableManager(_db.attachedDatabase, _db.workQueue);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db.attachedDatabase, _db.items);
}
