// Production [MediaMigrationRecordStore] adapter over [RecordingsDao] — task
// #1856, plan #131 W4. Kept in `core/db/` (not `core/crypto/`) because it
// depends on the Drift DAO layer; `media_migration.dart` itself stays
// DB-agnostic (the abstract [MediaMigrationRecordStore] seam) so its crash-
// replay/idempotency/rollback tests run against a plain in-memory fake
// without a real database.
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../crypto/media_migration.dart'
    show MediaMigrationCandidate, MediaMigrationRecordStore;
import 'app_database.dart';
import 'daos/recordings_dao.dart';

/// Candidates are every recording with `wrapped_fek IS NULL` (plaintext)
/// whose `audio_file_path` still exists on local disk — rows already
/// migrated, cloud-only, or whose file has vanished are excluded rather than
/// failing the whole batch. Ordered by [RecordingRow.id] so a `canaryLimit`
/// bound is stable across repeated calls.
class RecordingsDaoMediaMigrationStore implements MediaMigrationRecordStore {
  RecordingsDaoMediaMigrationStore(this._dao);

  final RecordingsDao _dao;

  @override
  Future<List<MediaMigrationCandidate>> fetchCandidates() async {
    final rows = await _dao.getAllRecordings();
    final candidates = <MediaMigrationCandidate>[];
    for (final row in rows) {
      if (row.wrappedFek != null) continue;
      if (row.audioFilePath.isEmpty) continue;
      if (!await File(row.audioFilePath).exists()) continue;
      candidates.add(
        MediaMigrationCandidate(
          recordingId: row.id,
          plaintextPath: row.audioFilePath,
        ),
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
    await _dao.updateRecording(
      recordingId,
      RecordingsCompanion(
        audioFilePath: Value(newPath),
        wrappedFek: Value(wrappedFekBase64),
        fileNoncePrefix: Value(fileNoncePrefixBase64),
      ),
    );
  }

  @override
  Future<void> markRolledBack(
    String recordingId, {
    required String originalPath,
  }) async {
    await _dao.updateRecording(
      recordingId,
      RecordingsCompanion(
        audioFilePath: Value(originalPath),
        wrappedFek: const Value(null),
        fileNoncePrefix: const Value(null),
      ),
    );
  }
}
