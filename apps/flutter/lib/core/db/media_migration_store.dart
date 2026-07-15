import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../crypto/media_migration.dart'
    show MediaMigrationCandidate, MediaMigrationRecordStore;
import 'app_database.dart';
import 'daos/items_dao.dart';

/// Owner-scoped media-at-rest migration adapter over canonical file Items.
class ItemsDaoMediaMigrationStore implements MediaMigrationRecordStore {
  ItemsDaoMediaMigrationStore(this._dao, this._ownerId);

  final ItemsDao _dao;
  final String _ownerId;

  @override
  Future<List<MediaMigrationCandidate>> fetchCandidates() async {
    final rows = await _dao.listAll(_ownerId);
    final candidates = <MediaMigrationCandidate>[];
    for (final row in rows) {
      if (row.file == null || row.wrappedFek != null) continue;
      final path = row.localPath;
      if (path == null || path.isEmpty || !await File(path).exists()) continue;
      candidates.add(
        MediaMigrationCandidate(recordingId: row.id, plaintextPath: path),
      );
    }
    candidates.sort((a, b) => a.recordingId.compareTo(b.recordingId));
    return candidates;
  }

  @override
  Future<void> markMigrated(
    String recordingId, {
    required String newPath,
    required String wrappedFekBase64,
    required String fileNoncePrefixBase64,
  }) async {
    await _dao.updateFile(
      recordingId,
      _ownerId,
      FileBlobsCompanion(
        localPath: Value(newPath),
        wrappedFek: Value(wrappedFekBase64),
        fileNoncePrefix: Value(fileNoncePrefixBase64),
        isDirty: const Value(true),
      ),
    );
  }

  @override
  Future<void> markRolledBack(
    String recordingId, {
    required String originalPath,
  }) async {
    await _dao.updateFile(
      recordingId,
      _ownerId,
      FileBlobsCompanion(
        localPath: Value(originalPath),
        wrappedFek: const Value(null),
        fileNoncePrefix: const Value(null),
        isDirty: const Value(true),
      ),
    );
  }
}
