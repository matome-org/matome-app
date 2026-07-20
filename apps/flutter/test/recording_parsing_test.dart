import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

void main() {
  group('Recording.fromJson', () {
    test('parses a fully-populated recording', () {
      final json = <String, dynamic>{
        'id': 1,
        'owner_id': 1,
        'title': 'Standup notes',
        'processing_state': 'succeeded',
        'processing_run_id': 'run-1',
        'processing_attempt': 1,
        'processing_requested_outputs': ['summary', 'transcript'],
        'processing_outputs': {
          'summary': {'type': 'summary', 'markdown': 'Short AI summary'},
          'transcript': {'type': 'transcript', 'text': 'Full transcript'},
        },
        'file': {
          'media_type': 'audio/m4a',
          'storage_key': 'recordings/abc',
          'duration': 132,
          'upload_state': 'uploaded',
        },
        'metadata': {'badge': 'work'},
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
        'processing_state': 'queued',
        'processing_run_id': 'run-2',
        'processing_attempt': 1,
        'processing_requested_outputs': const <String>[],
        'processing_outputs': const <String, dynamic>{},
        'file': {'media_type': null, 'storage_key': null, 'duration': null},
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
        'processing_state': 'archived',
      });
      expect(r.status, RecordingStatus.unknown);
    });

    test('coerces numeric-string ids and durations', () {
      final r = Recording.fromJson({
        'id': '7',
        'owner_id': '1',
        'title': 't',
        'processing_state': 'failed',
        'processing_run_id': 'run-7',
        'processing_attempt': 1,
        'processing_error': {'code': 'transcode_failed', 'retryable': true},
        'file': {'duration': '90'},
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
      final r = Recording.fromJson({'id': 1, 'title': 't', 'status': 'done'});
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
          {
            'id': 1,
            'owner_id': 1,
            'title': 'A',
            'processing_state': 'succeeded',
            'processing_run_id': 'run-1',
            'processing_attempt': 1,
          },
          {
            'id': 2,
            'owner_id': 1,
            'title': 'B',
            'processing_state': 'processing',
            'processing_run_id': 'run-2',
            'processing_attempt': 1,
          },
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
