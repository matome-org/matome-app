// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_drafts_dao.dart';

// ignore_for_file: type=lint
mixin _$RecordingDraftsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecordingDraftsTable get recordingDrafts => attachedDatabase.recordingDrafts;
  RecordingDraftsDaoManager get managers => RecordingDraftsDaoManager(this);
}

class RecordingDraftsDaoManager {
  final _$RecordingDraftsDaoMixin _db;
  RecordingDraftsDaoManager(this._db);
  $$RecordingDraftsTableTableManager get recordingDrafts =>
      $$RecordingDraftsTableTableManager(
        _db.attachedDatabase,
        _db.recordingDrafts,
      );
}
