import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';

/// Guards the legacy-media path rewrite SQL. The production [_relocateLegacyMedia]
/// is gated off under `flutter test` (its path_provider call hangs), so the raw
/// UPDATE shipped unverified — and used the WRONG column name (`audio_file_path`
/// instead of the legacy camelCase `audioFilePath`), throwing "no such column"
/// and silently relocating nothing. This exercises the extracted
/// [AppDatabase.rewriteLegacyMediaPaths] against a real in-memory DB.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  RecordingsCompanion rec(String id, String path) => RecordingsCompanion(
        id: Value(id),
        title: Value(id),
        timestamp: const Value('9:00 AM'),
        duration: const Value('0:30'),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: Value(path),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        mediaType: const Value('image'),
        processingStatus: const Value('done'),
      );

  Future<String?> pathOf(String id) async =>
      (await db.recordingsDao.getRecordingById(id))?.audioFilePath;

  test('rewrites import_/segment_ paths from the old dir into the new dir '
      '(does NOT throw on the camelCase column)', () async {
    const oldDir = '/home/u/Documents';
    const newDir = '/home/u/Documents/Matome';
    await db.recordingsDao.insertRecording(
      rec('r_import', '$oldDir/import_123.png'),
    );
    await db.recordingsDao.insertRecording(
      rec('r_segment', '$oldDir/segment_456.wav'),
    );

    await db.rewriteLegacyMediaPaths(oldDir, newDir);

    // Filename preserved, prefix moved under the Matome folder.
    expect(await pathOf('r_import'), '$newDir/import_123.png');
    expect(await pathOf('r_segment'), '$newDir/segment_456.wav');
  });

  test('leaves non-legacy and already-relocated paths untouched', () async {
    const oldDir = '/home/u/Documents';
    const newDir = '/home/u/Documents/Matome';
    // A path already under the new dir must NOT be rewritten again.
    await db.recordingsDao.insertRecording(
      rec('r_already', '$newDir/import_999.png'),
    );
    // A non-import/segment file under the old dir is out of scope.
    await db.recordingsDao.insertRecording(
      rec('r_other', '$oldDir/notes.txt'),
    );

    await db.rewriteLegacyMediaPaths(oldDir, newDir);

    expect(await pathOf('r_already'), '$newDir/import_999.png');
    expect(await pathOf('r_other'), '$oldDir/notes.txt');
  });

  test('is idempotent — a second run is a no-op', () async {
    const oldDir = '/home/u/Documents';
    const newDir = '/home/u/Documents/Matome';
    await db.recordingsDao.insertRecording(
      rec('r_x', '$oldDir/import_1.png'),
    );

    await db.rewriteLegacyMediaPaths(oldDir, newDir);
    final afterFirst = await pathOf('r_x');
    await db.rewriteLegacyMediaPaths(oldDir, newDir);

    expect(await pathOf('r_x'), afterFirst);
    expect(afterFirst, '$newDir/import_1.png');
  });
}
