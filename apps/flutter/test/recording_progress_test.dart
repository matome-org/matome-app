import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_progress.dart';

void main() {
  const uploading = RecordingProgress(
    phase: RecordingPhase.uploading,
    recordingId: 6,
  );
  const processing = RecordingProgress(
    phase: RecordingPhase.processing,
    recordingId: 6,
  );

  group('advanceOnStatus state machine', () {
    test('done -> done phase, attaches recording', () {
      const done = Recording(
        id: 6,
        ownerId: '1',
        title: 't',
        status: RecordingStatus.done,
      );
      final next = advanceOnStatus(
        current: processing,
        status: RecordingStatus.done,
        recording: done,
      );
      expect(next!.phase, RecordingPhase.done);
      expect(next.recording, same(done));
      expect(next.isTerminal, isTrue);
    });

    test('failed -> failed phase with error reason', () {
      final next = advanceOnStatus(
        current: processing,
        status: RecordingStatus.failed,
        errorReason: 'asr_timeout',
      );
      expect(next!.phase, RecordingPhase.failed);
      expect(next.errorReason, 'asr_timeout');
      expect(next.isTerminal, isTrue);
    });

    test('failed without reason falls back to default reason', () {
      final next = advanceOnStatus(
        current: processing,
        status: RecordingStatus.failed,
      );
      expect(next!.errorReason, 'recording_processing_failed');
    });

    test('processing moves uploading -> processing', () {
      final next = advanceOnStatus(
        current: uploading,
        status: RecordingStatus.processing,
      );
      expect(next!.phase, RecordingPhase.processing);
    });

    test('processing is a no-op when already processing', () {
      final next = advanceOnStatus(
        current: processing,
        status: RecordingStatus.processing,
      );
      expect(next, isNull);
    });

    test('pending and unknown are no-ops (stay in current phase)', () {
      expect(
        advanceOnStatus(current: processing, status: RecordingStatus.pending),
        isNull,
      );
      expect(
        advanceOnStatus(current: processing, status: RecordingStatus.unknown),
        isNull,
      );
    });
  });

  group('RecordingProgress', () {
    test('idle is non-terminal', () {
      expect(RecordingProgress.idle.phase, RecordingPhase.idle);
      expect(RecordingProgress.idle.isTerminal, isFalse);
    });

    test('copyWith overrides only provided fields', () {
      final updated = uploading.copyWith(phase: RecordingPhase.processing);
      expect(updated.phase, RecordingPhase.processing);
      expect(updated.recordingId, 6);
    });
  });
}
