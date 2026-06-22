import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/home/inbox_sync.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

// ---------------------------------------------------------------------------
// recordingToCompanion owner-scoping + the cross-owner SECURITY proof (#1469).
//
// SECURITY (A01 — Broken Access Control). Pre-#1469 the sync path never wrote
// `recordings.owner_id`, so every synced row landed NULL-owner and was invisible
// to `filesForOwner` (an EMPTY /files for everyone once nav turned on). The
// type-bug (parsing owner_id via asInt → "0") would have written a POISON value
// that DOES collide across owners — the exact leak #1461 guarded against. These
// tests pin BOTH halves of the contract:
//   1. a freshly-synced row is owner-scoped AND invisible to a different owner;
//   2. an absent/empty server owner_id is REJECTED, never written as 0/"".
//
// In-memory NativeDatabase, mirroring recordings_dao_files_test.dart.
// ---------------------------------------------------------------------------

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

Recording _coreRecording({
  required int id,
  Object? ownerId = '1',
  String title = 'File',
  String status = 'done',
  Object? byteSize = _absent,
}) {
  // Build via fromJson so we exercise the real wire-parse (owner_id → TEXT|null).
  return Recording.fromJson(<String, dynamic>{
    'id': id,
    if (ownerId != _absent) 'owner_id': ownerId,
    'title': title,
    'status': status,
    'media_type': 'audio',
    if (byteSize != _absent) 'byte_size': byteSize,
    'inserted_at': '2026-06-08T12:00:00Z',
  });
}

const Object _absent = Object();

void main() {
  late AppDatabase db;
  setUp(() => db = _memDb());
  tearDown(() => db.close());

  group('recordingToCompanion — owner write (#1469)', () {
    test('writes the Core owner_id onto the synced row', () {
      final companion = recordingToCompanion(_coreRecording(id: 1, ownerId: '7'));
      expect(companion.ownerId.present, isTrue);
      expect(companion.ownerId.value, '7');
    });

    test('REJECTS a missing owner_id — column left absent, never 0/""', () {
      final companion =
          recordingToCompanion(_coreRecording(id: 1, ownerId: _absent));
      // Absent (not written) → a first-time insert lands NULL-owner, correctly
      // invisible until a later sync supplies a real owner. NEVER "0"/"".
      expect(companion.ownerId.present, isFalse);
    });

    test('REJECTS a blank owner_id — column left absent', () {
      final companion =
          recordingToCompanion(_coreRecording(id: 1, ownerId: '  '));
      expect(companion.ownerId.present, isFalse);
    });

    test('conflict rule: Core owner overwrites a differing local owner', () async {
      // Seed a local row owned by "1".
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(_coreRecording(id: 1, ownerId: '1')),
      );
      final existing = await db.recordingsDao.getRecordingById('1');
      // A later Core sync now reports the row owned by "2" — Core wins.
      final companion = recordingToCompanion(
        _coreRecording(id: 1, ownerId: '2'),
        existing: existing,
      );
      expect(companion.ownerId.value, '2');
    });
  });

  group('recordingToCompanion — byte size (#1471)', () {
    test('adopts the Core byte_size onto the synced row', () {
      final companion =
          recordingToCompanion(_coreRecording(id: 1, byteSize: 2_516_582));
      expect(companion.byteSize.present, isTrue);
      expect(companion.byteSize.value, 2_516_582);
    });

    test('absent Core byte_size leaves the column untouched (first insert)', () {
      final companion = recordingToCompanion(_coreRecording(id: 1));
      // No local + no Core value → absent → NULL on insert → "—".
      expect(companion.byteSize.present, isFalse);
    });

    test('keeps a locally-known size when Core reports none (absence guard)',
        () async {
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(_coreRecording(id: 1, byteSize: 4096)),
      );
      final existing = await db.recordingsDao.getRecordingById('1');
      // A later Core list-row that hasn't computed a size must NOT null it out.
      final companion = recordingToCompanion(
        _coreRecording(id: 1),
        existing: existing,
      );
      expect(companion.byteSize.value, 4096);
    });

    test('full round-trip: Core byte_size → row → FileRow.sizeLabel', () async {
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(
          _coreRecording(id: 1, ownerId: '1', byteSize: 2_516_582),
        ),
      );
      final files = await db.recordingsDao.filesForOwner('1');
      expect(files.single.sizeLabel, '2.4 MB');
    });
  });

  group('cross-owner scoping after sync — the A01 SECURITY proof (#1469)', () {
    test(
        'a freshly-synced row is owner-scoped AND invisible to a different owner',
        () async {
      // Owner A (id "1") and owner B (id "2") each sync one recording.
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(_coreRecording(id: 1, ownerId: '1')),
      );
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(_coreRecording(id: 2, ownerId: '2')),
      );

      final filesA = await db.recordingsDao.filesForOwner('1');
      final filesB = await db.recordingsDao.filesForOwner('2');

      // /files is POPULATED for each owner (the #1461 positive proof)...
      expect(filesA.map((f) => f.id), ['1']);
      expect(filesB.map((f) => f.id), ['2']);
      // ...and owner B's row NEVER leaks into owner A's view (the negative proof).
      expect(filesA.any((f) => f.id == '2'), isFalse);
      expect(filesB.any((f) => f.id == '1'), isFalse);
    });

    test('a row synced WITHOUT an owner_id never surfaces for any owner',
        () async {
      // A poison/missing owner must be excluded, not defaulted to "0" (which
      // would collide across owners). The row lands NULL-owner → invisible.
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(_coreRecording(id: 9, ownerId: _absent)),
      );
      final row = await db.recordingsDao.getRecordingById('9');
      expect(row, isNotNull);
      expect(row!.ownerId, isNull); // not "0", not ""

      expect(await db.recordingsDao.filesForOwner('1'), isEmpty);
      expect(await db.recordingsDao.filesForOwner('0'), isEmpty);
    });
  });

  group('backfillNullOwner — local-only NULL-owner rows (#1469)', () {
    test('stamps the session owner onto NULL-owner rows and makes them visible',
        () async {
      // A local-only upload that never reconciled with Core → NULL owner.
      await db.recordingsDao.upsertRecordingWithMatome(
        RecordingsCompanion.insert(
          id: 'rec_local_x',
          title: 'Local memo',
          timestamp: '9:00 AM',
          duration: '0:30',
          audioFilePath: '/tmp/x.m4a',
          createdAt: 1000,
          // ownerId omitted → NULL.
        ),
      );
      // Invisible before backfill.
      expect(await db.recordingsDao.filesForOwner('1'), isEmpty);

      final n = await db.recordingsDao.backfillNullOwner('1');
      expect(n, 1);

      final files = await db.recordingsDao.filesForOwner('1');
      expect(files.map((f) => f.id), ['rec_local_x']);
      // Still scoped — never leaks to another owner.
      expect(await db.recordingsDao.filesForOwner('2'), isEmpty);
    });

    test('NEVER overwrites a row that already has a real owner', () async {
      await db.recordingsDao.upsertRecordingWithMatome(
        recordingToCompanion(_coreRecording(id: 5, ownerId: '2')),
      );
      // Backfilling as owner "1" must NOT steal owner 2's row.
      final n = await db.recordingsDao.backfillNullOwner('1');
      expect(n, 0);
      final row = await db.recordingsDao.getRecordingById('5');
      expect(row!.ownerId, '2');
      expect(await db.recordingsDao.filesForOwner('1'), isEmpty);
      expect((await db.recordingsDao.filesForOwner('2')).map((f) => f.id), ['5']);
    });
  });
}
