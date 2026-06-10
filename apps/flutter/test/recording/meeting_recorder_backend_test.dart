import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recording/meeting_loopback_source.dart';
import 'package:matome_flutter/features/recording/meeting_recorder_backend.dart';

// ---------------------------------------------------------------------------
// W5 / audit #828 warning #1: stop() must ALWAYS return.
//
// A bare `await process.exitCode` hangs forever if ffmpeg (spawned without a
// TTY) never consumes the `q` on stdin. These tests drive a FAKE Process whose
// exitCode is controllable so the SIGINT → SIGKILL → give-up escalation runs
// under a tiny injected grace, without a real ffmpeg or real seconds.
// ---------------------------------------------------------------------------

/// A loopback source that resolves a monitor without touching the host, so the
/// backend can `start()` in a test. Linux + a canned `pactl` dump.
MeetingLoopbackSource _fakeLoopback() {
  return MeetingLoopbackSource(
    isLinux: () => true,
    runner: (executable, arguments) async {
      final cmd = '$executable ${arguments.join(' ')}'.trim();
      if (cmd == 'pactl get-default-sink') {
        return const CommandResult(exitCode: 0, stdout: 'sink0');
      }
      if (cmd == 'pactl list short sources') {
        return const CommandResult(
          exitCode: 0,
          stdout: '57\tsink0.monitor\tPipeWire\ts16le 2ch 48000Hz\tIDLE\n',
        );
      }
      return const CommandResult(exitCode: 0, stdout: '');
    },
  );
}

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('meeting_stop_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
      'stop() returns under timeout when ffmpeg never exits (SIGINT then '
      'SIGKILL escalation), with a non-empty file on disk', () async {
    final wav = File('${tmp.path}/meeting.wav');
    // A non-empty WAV is on disk (ffmpeg wrote audio) — the wedge is only on
    // process exit, so the on-disk file is the source of truth.
    await wav.writeAsBytes(List<int>.filled(64, 1));

    // exitCode never completes on its own → stop() MUST fall through to the
    // signal escalation and the time-boxed give-up, never hanging.
    final process = _FakeProcess();

    final backend = MeetingRecorderBackend(
      loopback: _fakeLoopback(),
      spawn: (exe, args) async => process,
      stopGrace: const Duration(milliseconds: 20),
    );

    await backend.start(wav.path);

    // Bound the whole call so a regression (real hang) fails loudly instead of
    // timing out the suite.
    final path = await backend.stop().timeout(const Duration(seconds: 2));

    expect(path, wav.path, reason: 'stop returns the captured path');
    // Escalation actually fired: SIGINT first, then SIGKILL.
    expect(process.signals, contains(ProcessSignal.sigint));
    expect(process.signals, contains(ProcessSignal.sigkill));
    await backend.dispose();
  });

  test('stop() takes the clean path when ffmpeg exits 0 on `q` (no kill)',
      () async {
    final wav = File('${tmp.path}/meeting.wav');
    await wav.writeAsBytes(List<int>.filled(64, 1));

    final process = _FakeProcess()..completeExit(0);

    final backend = MeetingRecorderBackend(
      loopback: _fakeLoopback(),
      spawn: (exe, args) async => process,
      stopGrace: const Duration(milliseconds: 20),
    );

    await backend.start(wav.path);
    final path = await backend.stop().timeout(const Duration(seconds: 2));

    expect(path, wav.path);
    // Clean exit on `q` → no escalation signals at all.
    expect(process.signals, isEmpty, reason: 'clean `q` exit needs no kill');
    await backend.dispose();
  });

  test('stop() throws when no audio was produced even after escalation',
      () async {
    final wav = File('${tmp.path}/empty.wav');
    // Zero-byte file: ffmpeg produced nothing; escalation still returns control,
    // and stop() surfaces a diagnosable failure rather than hanging.
    await wav.writeAsBytes(const <int>[]);

    final process = _FakeProcess();
    final backend = MeetingRecorderBackend(
      loopback: _fakeLoopback(),
      spawn: (exe, args) async => process,
      stopGrace: const Duration(milliseconds: 20),
    );

    await backend.start(wav.path);
    await expectLater(
      backend.stop().timeout(const Duration(seconds: 2)),
      throwsA(isA<MeetingCaptureFailedError>()),
    );
    await backend.dispose();
  });
}

/// A fake [Process] whose exit is controllable. By default [exitCode] never
/// completes (a wedged subprocess); [completeExit] resolves it. Records every
/// signal sent so the escalation order can be asserted.
class _FakeProcess implements Process {
  final Completer<int> _exit = Completer<int>();
  final List<ProcessSignal> signals = <ProcessSignal>[];

  void completeExit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    // A real SIGKILL terminates the process; mirror that so the final await
    // resolves and stop() completes (without it, a pure hang would still be
    // caught by the injected grace timeout — tested implicitly).
    if (signal == ProcessSignal.sigkill) completeExit(137);
    return true;
  }

  @override
  IOSink get stdin => IOSink(_NullStreamConsumer());

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  int get pid => 4242;
}

/// Swallows everything written to the fake stdin (the `q` flush).
class _NullStreamConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<void> close() async {}
}
