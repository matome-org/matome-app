import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';

Recording _rec(int id, RecordingStatus status, {String? errorReason}) =>
    Recording(
      id: id,
      ownerId: '1',
      title: 'rec $id',
      status: status,
      errorReason: errorReason,
    );

RecordingStatusEvent _evt(int id, RecordingStatus status, {String? error}) =>
    RecordingStatusEvent(recordingId: id, status: status, errorReason: error);

void main() {
  group('RecordingResultWaiter', () {
    test('resolves done from the socket event (primary path)', () async {
      final events = StreamController<RecordingStatusEvent>();
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        statusEvents: events.stream,
        // Poll never returns a terminal status — socket must win.
        poll: () async => _rec(6, RecordingStatus.processing),
        pollInterval: const Duration(milliseconds: 50),
      );

      final future = waiter.wait();
      events.add(_evt(6, RecordingStatus.done));

      final result = await future;
      expect(result.failed, isFalse);
      expect(result.recording!.status, RecordingStatus.done);
      await events.close();
    });

    test('ignores events for a different recording id', () async {
      final events = StreamController<RecordingStatusEvent>();
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        statusEvents: events.stream,
        poll: () async => null,
        pollInterval: const Duration(milliseconds: 50),
      );

      final future = waiter.wait();
      events.add(_evt(999, RecordingStatus.done)); // not ours
      events.add(_evt(6, RecordingStatus.done)); // ours

      final result = await future;
      expect(result.failed, isFalse);
      expect(result.recording!.id, 6);
      await events.close();
    });

    test('falls back to poll when the socket never emits', () async {
      // Empty/never-emitting socket stream simulates "socket down".
      final events = StreamController<RecordingStatusEvent>();
      var calls = 0;
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        statusEvents: events.stream,
        poll: () async {
          calls++;
          // First poll still processing, second poll done.
          return calls < 2
              ? _rec(6, RecordingStatus.processing)
              : _rec(6, RecordingStatus.done);
        },
        pollInterval: const Duration(milliseconds: 10),
      );

      final result = await waiter.wait();
      expect(result.failed, isFalse);
      expect(result.recording!.status, RecordingStatus.done);
      expect(calls, greaterThanOrEqualTo(2));
      await events.close();
    });

    test('resolves failed from poll with error_reason', () async {
      final events = StreamController<RecordingStatusEvent>();
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        statusEvents: events.stream,
        poll: () async => _rec(6, RecordingStatus.failed, errorReason: 'boom'),
        pollInterval: const Duration(milliseconds: 10),
      );

      final result = await waiter.wait();
      expect(result.failed, isTrue);
      expect(result.errorReason, 'boom');
      await events.close();
    });

    test('transient poll errors are swallowed; socket still resolves',
        () async {
      final events = StreamController<RecordingStatusEvent>();
      final waiter = RecordingResultWaiter(
        recordingId: 6,
        statusEvents: events.stream,
        poll: () async => throw Exception('network blip'),
        pollInterval: const Duration(milliseconds: 10),
      );

      final future = waiter.wait();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      events.add(_evt(6, RecordingStatus.done));

      final result = await future;
      expect(result.failed, isFalse);
      await events.close();
    });

    test('times out as failed("timeout") when nothing resolves', () {
      fakeAsync((async) {
        final events = StreamController<RecordingStatusEvent>();
        RecordingResult? captured;
        RecordingResultWaiter(
          recordingId: 6,
          statusEvents: events.stream,
          poll: () async => _rec(6, RecordingStatus.processing),
          pollInterval: const Duration(seconds: 2),
          timeout: const Duration(minutes: 10),
        ).wait().then((r) => captured = r);

        async.elapse(const Duration(minutes: 10, seconds: 1));
        async.flushMicrotasks();

        expect(captured, isNotNull);
        expect(captured!.failed, isTrue);
        expect(captured!.errorReason, 'timeout');
        events.close();
      });
    });
  });
}
