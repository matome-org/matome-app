import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meeting_capture/meeting_capture.dart';

final Logger _log = Logger('meeting_capture.loopback');

class LinuxMeetingDevices {
  const LinuxMeetingDevices({
    required this.monitorSource,
    required this.microphoneSource,
  });

  final String monitorSource;
  final String microphoneSource;
}

class MeetingHostProbe {
  const MeetingHostProbe.supported(this.devices)
    : supported = true,
      reason = null;

  const MeetingHostProbe.unsupported(this.reason)
    : supported = false,
      devices = null;

  final bool supported;
  final String? reason;
  final LinuxMeetingDevices? devices;
}

class MeetingLoopbackSource {
  const MeetingLoopbackSource({
    CommandRunner runner = defaultCommandRunner,
    bool Function()? isLinux,
  }) : _run = runner,
       // ignore: prefer_initializing_formals
       _isLinux = isLinux;

  final CommandRunner _run;
  final bool Function()? _isLinux;

  bool get _onLinux {
    final probe = _isLinux;
    if (probe != null) return probe();
    try {
      return Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasFfmpeg() => _hasExecutable('ffmpeg');
  Future<bool> hasFfprobe() => _hasExecutable('ffprobe');
  Future<bool> hasPactl() => _hasExecutable('pactl');

  Future<bool> _hasExecutable(String executable) async {
    try {
      final result = await _run('which', [executable]);
      return result.exitCode == 0 && result.stdout.trim().isNotEmpty;
    } catch (error, stackTrace) {
      _log.warning('meeting probe: which $executable failed', error, stackTrace);
      return false;
    }
  }

  Future<bool> isSupported() async => (await probe()).supported;

  Future<MeetingHostProbe> probe() async {
    if (!_onLinux) {
      return const MeetingHostProbe.unsupported('linux-required');
    }
    if (!await hasFfmpeg()) {
      return const MeetingHostProbe.unsupported('ffmpeg-required');
    }
    if (!await hasFfprobe()) {
      return const MeetingHostProbe.unsupported('ffprobe-required');
    }
    if (!await hasPactl()) {
      return const MeetingHostProbe.unsupported('pactl-required');
    }
    try {
      final info = await _run('pactl', ['info']);
      if (info.exitCode != 0) {
        return const MeetingHostProbe.unsupported('audio-server-unavailable');
      }
      final devices = await resolveDevices();
      if (devices == null) {
        return const MeetingHostProbe.unsupported('audio-devices-unavailable');
      }
      return MeetingHostProbe.supported(devices);
    } catch (error, stackTrace) {
      _log.warning('meeting probe failed', error, stackTrace);
      return const MeetingHostProbe.unsupported('probe-failed');
    }
  }

  Future<LinuxMeetingDevices?> resolveDevices() async {
    if (!_onLinux) return null;
    final results = await Future.wait([
      _run('pactl', ['get-default-sink']),
      _run('pactl', ['get-default-source']),
      _run('pactl', ['list', 'short', 'sources']),
    ]);
    if (results.any((result) => result.exitCode != 0)) return null;
    final sink = results[0].stdout.trim();
    final microphone = results[1].stdout.trim();
    if (sink.isEmpty || microphone.isEmpty || microphone.endsWith('.monitor')) {
      return null;
    }
    final sources = parseSources(results[2].stdout);
    final monitor = '$sink.monitor';
    if (!sources.contains(monitor) || !sources.contains(microphone)) {
      return null;
    }
    return LinuxMeetingDevices(
      monitorSource: monitor,
      microphoneSource: microphone,
    );
  }

  Future<({bool system, bool microphone})?> availability(
    LinuxMeetingDevices devices,
  ) async {
    try {
      final result = await _run('pactl', ['list', 'short', 'sources']);
      if (result.exitCode != 0) return null;
      final sources = parseSources(result.stdout);
      return (
        system: sources.contains(devices.monitorSource),
        microphone: sources.contains(devices.microphoneSource),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> resolveMonitorSource() async =>
      (await resolveDevices())?.monitorSource;

  static Set<String> parseSources(String pactlShortOutput) {
    final names = <String>{};
    for (final line in pactlShortOutput.split('\n')) {
      if (line.trim().isEmpty) continue;
      final columns = line.split('\t');
      if (columns.length < 2) continue;
      final name = columns[1].trim();
      if (name.isNotEmpty) names.add(name);
    }
    return names;
  }

  static List<String> parseMonitorSources(String pactlShortOutput) =>
      parseSources(
        pactlShortOutput,
      ).where((name) => name.endsWith('.monitor')).toList(growable: false);
}
