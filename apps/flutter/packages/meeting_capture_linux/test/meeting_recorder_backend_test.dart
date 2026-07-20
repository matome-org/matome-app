import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:meeting_capture_linux/meeting_capture_linux.dart';

MeetingLoopbackSource fakeLoopback() => MeetingLoopbackSource(
  isLinux: () => true,
  runner: (executable, arguments) async {
    final command = '$executable ${arguments.join(' ')}'.trim();
    const responses = {
      'pactl get-default-sink': CommandResult(exitCode: 0, stdout: 'sink0'),
      'pactl get-default-source': CommandResult(exitCode: 0, stdout: 'mic0'),
      'pactl list short sources': CommandResult(
        exitCode: 0,
        stdout:
            '1\tsink0.monitor\tPipeWire\tx\tIDLE\n'
            '2\tmic0\tPipeWire\tx\tSUSPENDED\n',
      ),
    };
    return responses[command] ??
        const CommandResult(exitCode: 0, stdout: '/usr/bin/tool');
  },
);

const request = MeetingCaptureRequest(
  sessionId: 'meeting_test',
  stagingPath: '/tmp/meeting_test.partial.m4a',
);

void main() {
  test('start waits for real frames from both sources', () async {
    final process = FakeProcess();
    final backend = MeetingRecorderBackend(
      loopback: fakeLoopback(),
      prepareStaging: (_) async {},
      spawn: (_, _) async {
        scheduleMicrotask(() {
          process.emitSystem('[ebur128@system @ fake] t: 0.1 M: -20.5');
          process.emitMicrophone('[ebur128@microphone @ fake] t: 0.1 M: -inf');
        });
        return process;
      },
      startupGrace: const Duration(milliseconds: 100),
      stopGrace: const Duration(milliseconds: 20),
    );
    final events = <MeetingCaptureEvent>[];
    final subscription = backend.events.listen(events.add);

    await backend.start(request);
    await Future<void>.delayed(Duration.zero);

    expect(
      events
          .where((event) => event.source == MeetingCaptureSource.system)
          .single
          .levelDb,
      -20.5,
    );
    expect(
      events
          .where((event) => event.source == MeetingCaptureSource.microphone)
          .single
          .levelDb,
      -160,
    );
    await backend.cancel();
    await backend.dispose();
    await subscription.cancel();
  });

  test('stop proves graceful process and pipe termination', () async {
    final process = FakeProcess(exitOn: ProcessSignal.sigint, exitCode: 255);
    final backend = MeetingRecorderBackend(
      loopback: fakeLoopback(),
      prepareStaging: (_) async {},
      spawn: (_, _) async {
        scheduleMicrotask(process.emitReady);
        return process;
      },
      startupGrace: const Duration(milliseconds: 100),
      stopGrace: const Duration(milliseconds: 20),
    );
    await backend.start(request);

    final candidate = await backend.stop();

    expect(candidate.path, request.stagingPath);
    expect(process.signals, [ProcessSignal.sigint]);
    await backend.dispose();
  });

  test('stop never returns a candidate after forced kill', () async {
    final process = FakeProcess(exitOn: ProcessSignal.sigkill, exitCode: 137);
    final backend = MeetingRecorderBackend(
      loopback: fakeLoopback(),
      prepareStaging: (_) async {},
      spawn: (_, _) async {
        scheduleMicrotask(process.emitReady);
        return process;
      },
      startupGrace: const Duration(milliseconds: 100),
      stopGrace: const Duration(milliseconds: 10),
    );
    await backend.start(request);

    await expectLater(
      backend.stop(),
      throwsA(isA<MeetingCaptureProcessError>()),
    );

    expect(process.signals, [
      ProcessSignal.sigint,
      ProcessSignal.sigterm,
      ProcessSignal.sigkill,
    ]);
    await backend.dispose();
  });

  test('meter parser ignores diagnostics and clamps levels', () {
    expect(MeetingRecorderBackend.parseMeterLevel('ffmpeg warning'), isNull);
    expect(
      MeetingRecorderBackend.parseMeterLevel(
        'lavfi.astats.Overall.RMS_level=2.0',
      ),
      0,
    );
  });

  test(
    'device disappearance emits one source-specific unavailable event',
    () async {
      var sources =
          '1\tsink0.monitor\tPipeWire\tx\tIDLE\n'
          '2\tmic0\tPipeWire\tx\tSUSPENDED\n';
      final loopback = MeetingLoopbackSource(
        isLinux: () => true,
        runner: (executable, arguments) async {
          final command = '$executable ${arguments.join(' ')}'.trim();
          return switch (command) {
            'pactl get-default-sink' => const CommandResult(
              exitCode: 0,
              stdout: 'sink0',
            ),
            'pactl get-default-source' => const CommandResult(
              exitCode: 0,
              stdout: 'mic0',
            ),
            'pactl list short sources' => CommandResult(
              exitCode: 0,
              stdout: sources,
            ),
            _ => const CommandResult(exitCode: 0, stdout: '/usr/bin/tool'),
          };
        },
      );
      final process = FakeProcess();
      final backend = MeetingRecorderBackend(
        loopback: loopback,
        prepareStaging: (_) async {},
        spawn: (_, _) async {
          scheduleMicrotask(process.emitReady);
          return process;
        },
        startupGrace: const Duration(milliseconds: 100),
        stopGrace: const Duration(milliseconds: 20),
        devicePollInterval: const Duration(milliseconds: 5),
      );
      await backend.start(request);
      final unavailable = backend.events.firstWhere(
        (event) => event.state == MeetingCaptureState.unavailable,
      );

      sources = '2\tmic0\tPipeWire\tx\tSUSPENDED\n';

      expect((await unavailable).source, MeetingCaptureSource.system);
      await backend.cancel();
      await backend.dispose();
    },
  );

  test(
    'Linux host captures and independently validates both live sources',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meeting_backend_host_',
      );
      final path = '${directory.path}/meeting_host.partial.m4a';
      final backend = MeetingRecorderBackend();
      addTearDown(() async {
        await backend.dispose();
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      await backend.start(
        MeetingCaptureRequest(sessionId: 'meeting_host', stagingPath: path),
      );
      final fileMode = await Process.run('stat', ['-c', '%a', path]);
      final directoryMode = await Process.run('stat', [
        '-c',
        '%a',
        directory.path,
      ]);
      expect((fileMode.stdout as String).trim(), '600');
      expect((directoryMode.stdout as String).trim(), '700');
      await Future<void>.delayed(const Duration(seconds: 1));
      final candidate = await backend.stop();
      final facts = await const LinuxMeetingArtifactInspector().call(
        candidate.path,
      );

      expect(facts.decodable, isTrue);
      expect(facts.codec, MeetingAudioCodec.aacLc);
      expect(facts.sampleRate, 48000);
      expect(facts.channels, 1);
    },
    tags: 'linux_host',
  );

  test(
    'fixed filter preserves independent tones and enforces limiter ceiling',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meeting_mix_host_',
      );
      final path = '${directory.path}/controlled.m4a';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      const controlledRequest = MeetingCaptureRequest(
        sessionId: 'meeting_controlled',
        stagingPath: '/unused',
      );
      final generated = await runBoundedCommand('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000:duration=2,volume=20dB',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=880:sample_rate=48000:duration=2,volume=20dB',
        '-filter_complex',
        MeetingRecorderBackend.buildAudioFilter(controlledRequest),
        '-map',
        '[mixed]',
        '-ac',
        '1',
        '-ar',
        '48000',
        '-c:a',
        'aac',
        '-profile:a',
        'aac_low',
        '-b:a',
        '96k',
        '-f',
        'ipod',
        '-y',
        path,
      ], timeout: const Duration(seconds: 30));
      expect(generated.exitCode, 0, reason: generated.stderr);
      final facts = await const LinuxMeetingArtifactInspector().call(path);
      expect(facts.decodable, isTrue);

      for (final frequency in [440, 880]) {
        final analysis = await runBoundedCommand('ffmpeg', [
          '-hide_banner',
          '-i',
          path,
          '-af',
          'bandpass=f=$frequency:width_type=h:width=80,volumedetect',
          '-f',
          'null',
          '-',
        ], timeout: const Duration(seconds: 30));
        final max = RegExp(
          r'max_volume:\s*(-?\d+(?:\.\d+)?) dB',
        ).firstMatch(analysis.stderr);
        expect(max, isNotNull, reason: analysis.stderr);
        expect(double.parse(max!.group(1)!), greaterThan(-30));
      }
      final peak = await runBoundedCommand('ffmpeg', [
        '-hide_banner',
        '-i',
        path,
        '-af',
        'volumedetect',
        '-f',
        'null',
        '-',
      ], timeout: const Duration(seconds: 30));
      final maxPeak = RegExp(
        r'max_volume:\s*(-?\d+(?:\.\d+)?) dB',
      ).firstMatch(peak.stderr);
      expect(maxPeak, isNotNull, reason: peak.stderr);
      expect(double.parse(maxPeak!.group(1)!), lessThanOrEqualTo(0));
    },
    tags: 'linux_host',
  );
}

class FakeProcess implements Process {
  FakeProcess({this.exitOn = ProcessSignal.sigterm, int exitCode = 0})
    : exitCodeValue = exitCode;

  final ProcessSignal exitOn;
  final int exitCodeValue;
  final _exit = Completer<int>();
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final List<ProcessSignal> signals = [];

  void emitSystem(String line) => _stderr.add('$line\n'.codeUnits);
  void emitMicrophone(String line) => _stderr.add('$line\n'.codeUnits);
  void emitReady() {
    emitSystem('[ebur128@system @ fake] t: 0.1 M: -30.0');
    emitMicrophone('[ebur128@microphone @ fake] t: 0.1 M: -30.0');
  }

  Future<void> complete(int code) async {
    if (!_exit.isCompleted) _exit.complete(code);
    if (!_stdout.isClosed) await _stdout.close();
    if (!_stderr.isClosed) await _stderr.close();
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    if (signal == exitOn) unawaited(complete(exitCodeValue));
    return true;
  }

  @override
  IOSink get stdin => IOSink(NullStreamConsumer());

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  int get pid => 4242;
}

class NullStreamConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() async {}
}
