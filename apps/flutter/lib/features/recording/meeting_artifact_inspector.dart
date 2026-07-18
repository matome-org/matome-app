import 'dart:convert';
import 'dart:io';

import 'meeting_capture_backend.dart';
import 'meeting_loopback_source.dart';

Future<CommandResult> _defaultInspectionRunner(
  String executable,
  List<String> arguments,
) => runBoundedCommand(
  executable,
  arguments,
  timeout: executable == 'ffmpeg'
      ? const Duration(seconds: 60)
      : const Duration(seconds: 10),
  outputLimit: 256 * 1024,
);

class LinuxMeetingArtifactInspector {
  const LinuxMeetingArtifactInspector({
    CommandRunner runner = _defaultInspectionRunner,
  }) : _run = runner;

  final CommandRunner _run;

  Future<MeetingArtifactFacts> call(String path) async {
    final probe = await _run('ffprobe', [
      '-v',
      'error',
      '-select_streams',
      'a',
      '-show_entries',
      'stream=codec_name,profile,sample_rate,channels:'
          'format=format_name,duration,size',
      '-of',
      'json',
      path,
    ]);
    if (probe.exitCode != 0) {
      throw const MeetingArtifactInvalidError('ffprobe rejected artifact');
    }
    final Map<String, Object?> document;
    try {
      document = (jsonDecode(probe.stdout) as Map).cast<String, Object?>();
    } catch (_) {
      throw const MeetingArtifactInvalidError('Invalid ffprobe response');
    }
    final streams = document['streams'];
    final format = document['format'];
    if (streams is! List || streams.length != 1 || format is! Map) {
      throw const MeetingArtifactInvalidError('Expected one audio stream');
    }
    final stream = (streams.single as Map).cast<String, Object?>();
    final metadata = format.cast<String, Object?>();
    final durationSeconds = double.tryParse('${metadata['duration']}');
    final byteSize = int.tryParse('${metadata['size']}');
    final actualBytes = await File(path).length();
    final formatName = '${metadata['format_name']}';
    if (stream['codec_name'] != 'aac' ||
        stream['profile'] != 'LC' ||
        stream['sample_rate'] != '48000' ||
        stream['channels'] != 1 ||
        !formatName
            .split(',')
            .any(
              (name) => const {
                'mov',
                'mp4',
                'm4a',
                '3gp',
                '3g2',
                'mj2',
              }.contains(name),
            ) ||
        durationSeconds == null ||
        !durationSeconds.isFinite ||
        durationSeconds <= 0 ||
        byteSize == null ||
        byteSize <= 0 ||
        byteSize != actualBytes) {
      throw const MeetingArtifactInvalidError(
        'Artifact does not match the meeting audio contract',
      );
    }
    final decode = await _run('ffmpeg', [
      '-v',
      'error',
      '-xerror',
      '-i',
      path,
      '-map',
      '0:a:0',
      '-f',
      'null',
      '-',
    ]);
    return MeetingArtifactFacts(
      decodable: decode.exitCode == 0,
      container: MeetingContainer.m4a,
      codec: MeetingAudioCodec.aacLc,
      sampleRate: 48000,
      channels: 1,
      duration: Duration(
        microseconds: (durationSeconds * Duration.microsecondsPerSecond)
            .round(),
      ),
      byteSize: byteSize,
    );
  }
}
