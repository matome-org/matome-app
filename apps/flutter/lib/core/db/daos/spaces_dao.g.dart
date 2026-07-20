// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spaces_dao.dart';

// ignore_for_file: type=lint
mixin _$SpacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $SpaceMembersTable get spaceMembers => attachedDatabase.spaceMembers;
  $OrganizationsTable get organizations => attachedDatabase.organizations;
  SpacesDaoManager get managers => SpacesDaoManager(this);
}

class SpacesDaoManager {
  final _$SpacesDaoMixin _db;
  SpacesDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$SpaceMembersTableTableManager get spaceMembers =>
      $$SpaceMembersTableTableManager(_db.attachedDatabase, _db.spaceMembers);
  $$OrganizationsTableTableManager get organizations =>
      $$OrganizationsTableTableManager(_db.attachedDatabase, _db.organizations);
}
