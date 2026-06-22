import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';

void main() {
  group('RecordingStatusEvent.tryParse', () {
    test('parses a full processing-done payload from the channel', () {
      // Exact shape broadcast by MatomeApi.Content.broadcast_recording_status/2.
      final payload = <String, dynamic>{
        'recording_id': 6,
        'status': 'done',
        'summary': 'Canned local summary for audio recording 6.',
        'transcript': 'the transcript',
        'error_reason': null,
        'duration': 3,
        'badge': 'test',
        'updated_at': '2026-06-09T00:55:20Z',
      };

      final event = RecordingStatusEvent.tryParse(payload);

      expect(event, isNotNull);
      expect(event!.recordingId, 6);
      expect(event.status, RecordingStatus.done);
      expect(event.summary, contains('Canned local summary'));
      expect(event.transcript, 'the transcript');
      expect(event.errorReason, isNull);
      expect(event.duration, 3);
      expect(event.badge, 'test');
      expect(event.updatedAt, DateTime.parse('2026-06-09T00:55:20Z'));
    });

    test('parses a failed payload with error_reason', () {
      final event = RecordingStatusEvent.tryParse(<String, dynamic>{
        'recording_id': 9,
        'status': 'failed',
        'error_reason': 'transcription_error',
      });

      expect(event!.status, RecordingStatus.failed);
      expect(event.errorReason, 'transcription_error');
    });

    test('treats unknown status string as RecordingStatus.unknown', () {
      final event = RecordingStatusEvent.tryParse(<String, dynamic>{
        'recording_id': 1,
        'status': 'something_new',
      });
      expect(event!.status, RecordingStatus.unknown);
    });

    test('coerces a stringified recording_id (tolerant parsing)', () {
      final event = RecordingStatusEvent.tryParse(<String, dynamic>{
        'recording_id': '42',
        'status': 'processing',
      });
      expect(event!.recordingId, 42);
      expect(event.status, RecordingStatus.processing);
    });

    test('returns null when payload is not a map', () {
      expect(RecordingStatusEvent.tryParse(null), isNull);
      expect(RecordingStatusEvent.tryParse('nope'), isNull);
      expect(RecordingStatusEvent.tryParse(<dynamic>[]), isNull);
    });

    test('returns null when recording_id is absent', () {
      expect(
        RecordingStatusEvent.tryParse(<String, dynamic>{'status': 'done'}),
        isNull,
      );
    });

    test('applyTo folds event onto a base recording, preserving title/owner',
        () {
      const base = Recording(
        id: 6,
        ownerId: '1',
        title: 'Standup',
        status: RecordingStatus.processing,
        mediaType: 'audio',
        storageKey: 'owners/1/recordings/6/media',
      );
      final event = RecordingStatusEvent.tryParse(<String, dynamic>{
        'recording_id': 6,
        'status': 'done',
        'summary': 'done summary',
        'transcript': 'done transcript',
      })!;

      final merged = event.applyTo(base);

      expect(merged.status, RecordingStatus.done);
      expect(merged.summary, 'done summary');
      expect(merged.transcript, 'done transcript');
      // Fields not carried by the event survive.
      expect(merged.title, 'Standup');
      expect(merged.ownerId, '1');
      expect(merged.storageKey, 'owners/1/recordings/6/media');
    });
  });
}
