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

      final r = Recording.fromJson(json);

      expect(r.id, 1);
      expect(r.ownerId, 1);
      expect(r.title, 'Standup notes');
      expect(r.status, RecordingStatus.done);
      expect(r.summary, 'Short AI summary');
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
