import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/recording/meeting_loopback_source.dart';
import 'package:matome_flutter/features/recording/meeting_recorder_backend.dart';

// ---------------------------------------------------------------------------
// Unit tests for the desktop meeting recorder's host-resolution seam: the
// PipeWire/Pulse `.monitor` loopback source resolver + capability gate. No real
// `pactl`/`which`/ffmpeg — every host call is funnelled through an injected
// CommandRunner with canned output, so the resolution logic is deterministic.
// ---------------------------------------------------------------------------

/// Canned command runner: maps `<exe> <args...>` to a [CommandResult].
CommandRunner fakeRunner(
  Map<String, CommandResult> responses, {
  CommandResult fallback = const CommandResult(exitCode: 1, stdout: ''),
}) {
  return (executable, arguments) async {
    final key = '$executable ${arguments.join(' ')}'.trim();
    return responses[key] ?? fallback;
  };
}

/// A realistic `pactl list short sources` dump (tab-separated) with two output
/// monitors + a real mic input.
const _pactlSources = '''
46\talsa_input.pci-0000_c1_00.6.HiFi__Mic1__source\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED
57\talsa_output.pci-0000_c1_00.6.HiFi__Speaker__sink.monitor\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED
1201\talsa_output.usb-Logitech_G522.analog-stereo.monitor\tPipeWire\ts24le 2ch 48000Hz\tSUSPENDED
''';

void main() {
  group('parseMonitorSources', () {
    test('extracts only .monitor names, in order', () {
      final names = MeetingLoopbackSource.parseMonitorSources(_pactlSources);
      expect(names, [
        'alsa_output.pci-0000_c1_00.6.HiFi__Speaker__sink.monitor',
        'alsa_output.usb-Logitech_G522.analog-stereo.monitor',
      ]);
    });

    test('ignores blank lines and malformed rows', () {
      final names = MeetingLoopbackSource.parseMonitorSources(
        '\n  \nbad-row-no-tabs\n5\tfoo.monitor\tx\n',
      );
      expect(names, ['foo.monitor']);
    });

    test('returns empty when no monitor sources present', () {
      final names = MeetingLoopbackSource.parseMonitorSources(
        '46\talsa_input.mic\tPipeWire\tx\n',
      );
      expect(names, isEmpty);
    });
  });

  group('resolveMonitorSource', () {
    test('prefers the default sink\'s own .monitor', () async {
      final src = MeetingLoopbackSource(
        isLinux: () => true,
        runner: fakeRunner({
          'pactl get-default-sink': const CommandResult(
            exitCode: 0,
            stdout: 'alsa_output.usb-Logitech_G522.analog-stereo\n',
          ),
          'pactl list short sources':
              const CommandResult(exitCode: 0, stdout: _pactlSources),
        }),
      );
      expect(
        await src.resolveMonitorSource(),
        'alsa_output.usb-Logitech_G522.analog-stereo.monitor',
      );
    });

    test('falls back to the first monitor when default sink has no monitor row',
        () async {
      final src = MeetingLoopbackSource(
        isLinux: () => true,
        runner: fakeRunner({
          'pactl get-default-sink': const CommandResult(
            exitCode: 0,
            stdout: 'some_other_sink_without_a_monitor\n',
          ),
          'pactl list short sources':
              const CommandResult(exitCode: 0, stdout: _pactlSources),
        }),
      );
      expect(
        await src.resolveMonitorSource(),
        'alsa_output.pci-0000_c1_00.6.HiFi__Speaker__sink.monitor',
      );
    });

    test('returns null when there are no monitor sources', () async {
      final src = MeetingLoopbackSource(
        isLinux: () => true,
        runner: fakeRunner({
          'pactl get-default-sink':
              const CommandResult(exitCode: 0, stdout: 'sink\n'),
          'pactl list short sources': const CommandResult(
            exitCode: 0,
            stdout: '46\talsa_input.mic\tPipeWire\tx\n',
          ),
        }),
      );
      expect(await src.resolveMonitorSource(), isNull);
    });

    test('returns null off Linux (out of MVP scope)', () async {
      final src = MeetingLoopbackSource(
        isLinux: () => false,
        runner: fakeRunner({
          'pactl list short sources':
              const CommandResult(exitCode: 0, stdout: _pactlSources),
        }),
      );
      expect(await src.resolveMonitorSource(), isNull);
    });
  });

  group('isSupported (capability gate)', () {
    MeetingLoopbackSource gate({
      required bool linux,
      required bool ffmpeg,
      required bool pactl,
      String sources = _pactlSources,
    }) {
      return MeetingLoopbackSource(
        isLinux: () => linux,
        runner: fakeRunner({
          'which ffmpeg': CommandResult(exitCode: ffmpeg ? 0 : 1, stdout: ''),
          'which pactl': CommandResult(exitCode: pactl ? 0 : 1, stdout: ''),
          'pactl get-default-sink': const CommandResult(
            exitCode: 0,
            stdout: 'alsa_output.usb-Logitech_G522.analog-stereo\n',
          ),
          'pactl list short sources':
              CommandResult(exitCode: 0, stdout: sources),
        }),
      );
    }

    test('supported: Linux + ffmpeg + pactl + a monitor source', () async {
      expect(
        await gate(linux: true, ffmpeg: true, pactl: true).isSupported(),
        isTrue,
      );
    });

    test('unsupported off Linux', () async {
      expect(
        await gate(linux: false, ffmpeg: true, pactl: true).isSupported(),
        isFalse,
      );
    });

    test('unsupported without ffmpeg', () async {
      expect(
        await gate(linux: true, ffmpeg: false, pactl: true).isSupported(),
        isFalse,
      );
    });

    test('unsupported without pactl', () async {
      expect(
        await gate(linux: true, ffmpeg: true, pactl: false).isSupported(),
        isFalse,
      );
    });

    test('unsupported when no monitor source exists', () async {
      expect(
        await gate(
          linux: true,
          ffmpeg: true,
          pactl: true,
          sources: '46\talsa_input.mic\tPipeWire\tx\n',
        ).isSupported(),
        isFalse,
      );
    });
  });

  group('buildFfmpegArgs (capture command)', () {
    test('mixes monitor + mic into one WAV with the loopback first', () {
      final args = MeetingRecorderBackend.buildFfmpegArgs(
        monitorSource: 'sink.monitor',
        outputPath: '/tmp/meeting.wav',
      );
      // Two pulse inputs: loopback monitor THEN mic.
      final firstInput = args.indexOf('sink.monitor');
      final secondInput = args.indexOf('default');
      expect(firstInput, greaterThan(0));
      expect(secondInput, greaterThan(firstInput));
      // Mixed (not two tracks) via amix of 2 inputs.
      expect(
        args,
        containsAllInOrder(['-filter_complex', 'amix=inputs=2:duration=longest:normalize=0']),
      );
      // Single WAV (pcm_s16le) at the requested path.
      expect(args, containsAllInOrder(['-c:a', 'pcm_s16le']));
      expect(args.last, '/tmp/meeting.wav');
    });

    test('honours a custom mic source', () {
      final args = MeetingRecorderBackend.buildFfmpegArgs(
        monitorSource: 'sink.monitor',
        outputPath: '/tmp/m.wav',
        micSource: 'alsa_input.custom',
      );
      expect(args, contains('alsa_input.custom'));
    });
  });
}
