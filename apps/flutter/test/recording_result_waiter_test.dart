import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';

Recording _item(String runId, ProcessingState state, {String? errorCode}) {
  return Recording.fromItemJson(<String, dynamic>{
    'id': 6,
    'owner_id': 1,
    'item_type': 'file',
    'title': 'Item 6',
    'processing_state': state.wireName,
    'processing_run_id': runId,
    'processing_attempt': 1,
    'processing_requested_outputs': const ['transcript'],
    'processing_outputs': const <String, dynamic>{},
    'processing_error': errorCode == null
        ? null
        : <String, dynamic>{
            'code': errorCode,
            'message': 'Processing failed.',
            'retryable': true,
          },
    'file': const <String, dynamic>{'media_type': 'audio'},
  });
}

void main() {
  group('RecordingResultWaiter', () {
    test('polls the explicit current run to succeeded', () async {
      var calls = 0;
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        runId: 'run-current',
        poll: () async {
          calls++;
          return _item(
            'run-current',
            calls == 1 ? ProcessingState.processing : ProcessingState.succeeded,
          );
        },
        initialPollInterval: const Duration(milliseconds: 1),
        maxPollInterval: const Duration(milliseconds: 2),
      );

      final result = await waiter.wait();

      expect(result.outcome, RecordingWaitOutcome.terminal);
      expect(result.recording?.processing.state, ProcessingState.succeeded);
      expect(calls, 2);
    });

    test('ignores a stale terminal response from a previous run', () async {
      var calls = 0;
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        runId: 'run-current',
        poll: () async {
          calls++;
          return calls == 1
              ? _item('run-stale', ProcessingState.succeeded)
              : _item('run-current', ProcessingState.partial);
        },
        initialPollInterval: const Duration(milliseconds: 1),
      );

      final result = await waiter.wait();

      expect(calls, 2);
      expect(result.recording?.processing.runId, 'run-current');
      expect(result.recording?.processing.state, ProcessingState.partial);
    });

    test('never overlaps polls while a request is in flight', () async {
      final firstPoll = Completer<Recording?>();
      var active = 0;
      var maxActive = 0;
      var calls = 0;
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        runId: 'run-current',
        poll: () async {
          calls++;
          active++;
          if (active > maxActive) maxActive = active;
          final value = calls == 1
              ? await firstPoll.future
              : _item('run-current', ProcessingState.succeeded);
          active--;
          return value;
        },
        initialPollInterval: const Duration(milliseconds: 1),
      );

      final resultFuture = waiter.wait();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 1);
      firstPoll.complete(_item('run-current', ProcessingState.processing));
      final result = await resultFuture;

      expect(result.outcome, RecordingWaitOutcome.terminal);
      expect(maxActive, 1);
    });

    test('backs off to the configured bound after transient failures', () {
      fakeAsync((async) {
        var calls = 0;
        RecordingResult? captured;
        final waiter = RecordingResultWaiter(
          recordingId: 6,
          runId: 'run-current',
          poll: () async {
            calls++;
            throw Exception('network blip');
          },
          initialPollInterval: const Duration(seconds: 1),
          maxPollInterval: const Duration(seconds: 4),
          observationTimeout: const Duration(seconds: 20),
        );

        waiter.wait().then((value) => captured = value);
        async.flushMicrotasks();
        expect(calls, 1);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(calls, 2);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(calls, 3);
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(calls, 4);
        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(calls, 5);
        expect(captured, isNull);
        waiter.cancel();
      });
    });

    test('timeout is observational and does not report Core failure', () {
      fakeAsync((async) {
        RecordingResult? captured;
        RecordingResultWaiter(
          recordingId: 6,
          runId: 'run-current',
          poll: () async => _item('run-current', ProcessingState.processing),
          initialPollInterval: const Duration(seconds: 1),
          observationTimeout: const Duration(seconds: 5),
        ).wait().then((value) => captured = value);

        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();

        expect(captured?.outcome, RecordingWaitOutcome.observationTimedOut);
        expect(captured?.recording, isNull);
        expect(captured?.errorCode, isNull);
      });
    });

    test('returns an explicit failed terminal error', () async {
      final result = await RecordingResultWaiter(
        recordingId: 6,
        runId: 'run-current',
        poll: () async => _item(
          'run-current',
          ProcessingState.failed,
          errorCode: 'processor_unavailable',
        ),
        initialPollInterval: const Duration(milliseconds: 1),
      ).wait();

      expect(result.outcome, RecordingWaitOutcome.terminal);
      expect(result.errorCode, 'processor_unavailable');
    });
  });
}
