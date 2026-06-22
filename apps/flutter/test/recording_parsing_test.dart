import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

void main() {
  group('Recording.fromJson', () {
    test('parses a fully-populated recording', () {
      final json = <String, dynamic>{
        'id': 1,
        'owner_id': 1,
        'title': 'Standup notes',
        'summary': 'Short AI summary',
        'transcript': 'Full transcript',
        'media_type': 'audio/m4a',
        'storage_key': 'recordings/abc',
        'status': 'done',
        'error_reason': null,
        'duration': 132,
        'badge': 'work',
        'workspace_id': null,
        'inserted_at': '2026-06-08T12:00:00Z',
        'updated_at': '2026-06-08T12:00:00Z',
      };

      json['notes'] = 'User-edited notes';

      final r = Recording.fromJson(json);

      expect(r.id, 1);
      expect(r.ownerId, '1'); // #1469: parsed as the TEXT id it is
      expect(r.title, 'Standup notes');
      expect(r.status, RecordingStatus.done);
      expect(r.summary, 'Short AI summary');
      expect(r.transcript, 'Full transcript');
      // #1434: `notes` is parsed independently of `transcript`.
      expect(r.notes, 'User-edited notes');
      expect(r.mediaType, 'audio/m4a');
      expect(r.duration, 132);
      expect(r.badge, 'work');
      expect(r.workspaceId, isNull);
      expect(r.insertedAt, DateTime.utc(2026, 6, 8, 12, 0, 0));
    });

    test('tolerates null optionals (pre-processing recording)', () {
      final json = <String, dynamic>{
        'id': 2,
        'owner_id': 1,
        'title': 'Untitled',
        'summary': null,
        'transcript': null,
        'media_type': null,
        'storage_key': null,
        'status': 'pending',
        'error_reason': null,
        'duration': null,
        'badge': null,
        'workspace_id': null,
        'inserted_at': null,
        'updated_at': null,
      };

      final r = Recording.fromJson(json);

      expect(r.id, 2);
      expect(r.status, RecordingStatus.pending);
      expect(r.summary, isNull);
      expect(r.duration, isNull);
      expect(r.insertedAt, isNull);
    });

    test('maps unknown status to RecordingStatus.unknown', () {
      final r = Recording.fromJson({
        'id': 3,
        'owner_id': 1,
        'title': 't',
        'status': 'archived',
      });
      expect(r.status, RecordingStatus.unknown);
    });

    test('coerces numeric-string ids and durations', () {
      final r = Recording.fromJson({
        'id': '7',
        'owner_id': '1',
        'title': 't',
        'status': 'failed',
        'duration': '90',
        'error_reason': 'transcode_failed',
      });
      expect(r.id, 7);
      expect(r.duration, 90);
      expect(r.status, RecordingStatus.failed);
      expect(r.errorReason, 'transcode_failed');
    });

    // #1469 (SECURITY, A01): owner_id is the TEXT scope for the Files view. It
    // must be parsed as a STRING, never coerced through asInt (which would turn a
    // missing value into 0 — a cross-owner poison). A missing/blank owner_id must
    // parse to null so the write path can REJECT it rather than default it.
    test('parses a numeric owner_id as its string form', () {
      final r = Recording.fromJson({
        'id': 1,
        'owner_id': 42,
        'title': 't',
        'status': 'done',
      });
      expect(r.ownerId, '42');
    });

    test('parses a string owner_id verbatim', () {
      final r = Recording.fromJson({
        'id': 1,
        'owner_id': 'usr_abc',
        'title': 't',
        'status': 'done',
      });
      expect(r.ownerId, 'usr_abc');
    });

    test('a MISSING owner_id parses to null (never coerced to 0)', () {
      final r = Recording.fromJson({
        'id': 1,
        'title': 't',
        'status': 'done',
      });
      expect(r.ownerId, isNull);
    });

    test('a NULL owner_id parses to null', () {
      final r = Recording.fromJson({
        'id': 1,
        'owner_id': null,
        'title': 't',
        'status': 'done',
      });
      expect(r.ownerId, isNull);
    });

    test('a BLANK/whitespace owner_id parses to null (rejected, not "")', () {
      final r = Recording.fromJson({
        'id': 1,
        'owner_id': '   ',
        'title': 't',
        'status': 'done',
      });
      expect(r.ownerId, isNull);
    });
  });

  group('Recording.listFromEnvelope', () {
    test('parses the { recordings: [...] } envelope', () {
      final envelope = <String, dynamic>{
        'recordings': [
          {'id': 1, 'owner_id': 1, 'title': 'A', 'status': 'done'},
          {'id': 2, 'owner_id': 1, 'title': 'B', 'status': 'processing'},
        ],
      };

      final list = Recording.listFromEnvelope(envelope);

      expect(list, hasLength(2));
      expect(list[0].title, 'A');
      expect(list[1].status, RecordingStatus.processing);
    });

    test('returns empty list when key missing or not a list', () {
      expect(Recording.listFromEnvelope({}), isEmpty);
      expect(Recording.listFromEnvelope({'recordings': 'nope'}), isEmpty);
    });
  });
}
