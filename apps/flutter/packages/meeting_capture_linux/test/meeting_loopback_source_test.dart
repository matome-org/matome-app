import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:meeting_capture_linux/meeting_capture_linux.dart';

CommandRunner fakeRunner(
  Map<String, CommandResult> responses, {
  CommandResult fallback = const CommandResult(exitCode: 1, stdout: ''),
}) {
  return (executable, arguments) async =>
      responses['$executable ${arguments.join(' ')}'.trim()] ?? fallback;
}

const _sources = '''
46\talsa_input.mic\tPipeWire\ts16le 1ch 48000Hz\tSUSPENDED
57\talsa_output.speaker.monitor\tPipeWire\ts32le 2ch 48000Hz\tIDLE
''';

Map<String, CommandResult> supportedHost() => {
  'which ffmpeg': const CommandResult(exitCode: 0, stdout: '/usr/bin/ffmpeg\n'),
  'which ffprobe': const CommandResult(
    exitCode: 0,
    stdout: '/usr/bin/ffprobe\n',
  ),
  'which pactl': const CommandResult(exitCode: 0, stdout: '/usr/bin/pactl\n'),
  'pactl info': const CommandResult(exitCode: 0, stdout: 'Server: PipeWire'),
  'pactl get-default-sink': const CommandResult(
    exitCode: 0,
    stdout: 'alsa_output.speaker\n',
  ),
  'pactl get-default-source': const CommandResult(
    exitCode: 0,
    stdout: 'alsa_input.mic\n',
  ),
  'pactl list short sources': const CommandResult(
    exitCode: 0,
    stdout: _sources,
  ),
};

void main() {
  test('probe requires Linux and every runtime dependency', () async {
    final offLinux = MeetingLoopbackSource(
      isLinux: () => false,
      runner: fakeRunner(supportedHost()),
    );
    expect((await offLinux.probe()).reason, 'linux-required');

    final missing = supportedHost()..remove('which ffprobe');
    final noFfprobe = MeetingLoopbackSource(
      isLinux: () => true,
      runner: fakeRunner(missing),
    );
    expect((await noFfprobe.probe()).reason, 'ffprobe-required');
  });

  test('selects the exact default sink monitor and microphone', () async {
    final source = MeetingLoopbackSource(
      isLinux: () => true,
      runner: fakeRunner(supportedHost()),
    );

    final devices = await source.resolveDevices();

    expect(devices?.monitorSource, 'alsa_output.speaker.monitor');
    expect(devices?.microphoneSource, 'alsa_input.mic');
    expect((await source.probe()).supported, isTrue);
  });

  test('does not fall back to an unrelated monitor', () async {
    final responses = supportedHost();
    responses['pactl get-default-sink'] = const CommandResult(
      exitCode: 0,
      stdout: 'alsa_output.missing\n',
    );
    final source = MeetingLoopbackSource(
      isLinux: () => true,
      runner: fakeRunner(responses),
    );

    expect(await source.resolveDevices(), isNull);
  });

  test('rejects a monitor selected as the default microphone', () async {
    final responses = supportedHost();
    responses['pactl get-default-source'] = const CommandResult(
      exitCode: 0,
      stdout: 'alsa_output.speaker.monitor\n',
    );
    final source = MeetingLoopbackSource(
      isLinux: () => true,
      runner: fakeRunner(responses),
    );

    expect(await source.resolveDevices(), isNull);
  });

  test('builds the fixed AAC-LC mix and limiter contract', () {
    const request = MeetingCaptureRequest(
      sessionId: 'meeting_test',
      stagingPath: '/tmp/meeting.partial.m4a',
    );

    final args = MeetingRecorderBackend.buildFfmpegArgs(
      request: request,
      monitorSource: 'sink.monitor',
      microphoneSource: 'mic.source',
    );

    final filter = args[args.indexOf('-filter_complex') + 1];
    expect(args.indexOf('sink.monitor'), lessThan(args.indexOf('mic.source')));
    expect(filter, contains('[sysmix]volume=-6.0dB'));
    expect(filter, contains('[micmix]volume=-6.0dB'));
    expect(filter, contains('normalize=0'));
    expect(filter, contains('limit=0.891250938:level=disabled'));
    expect(args, containsAllInOrder(['-c:a', 'aac', '-profile:a', 'aac_low']));
    expect(args, containsAllInOrder(['-b:a', '96000']));
    expect(args.last, request.stagingPath);
  });
}
