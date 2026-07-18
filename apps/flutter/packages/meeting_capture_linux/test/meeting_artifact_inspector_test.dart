import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:meeting_capture_linux/meeting_capture_linux.dart';

void main() {
  late Directory directory;
  late File artifact;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('meeting_inspector_');
    artifact = File('${directory.path}/meeting.m4a');
    await artifact.writeAsBytes(List<int>.filled(128, 1));
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('accepts one AAC-LC mono 48 kHz M4A after full decode', () async {
    final inspector = LinuxMeetingArtifactInspector(
      runner: (executable, arguments) async => executable == 'ffprobe'
          ? const CommandResult(
              exitCode: 0,
              stdout:
                  '''{"streams":[{"codec_name":"aac","profile":"LC","sample_rate":"48000","channels":1}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2.5","size":"128"}}''',
            )
          : const CommandResult(exitCode: 0, stdout: ''),
    );

    final facts = await inspector.call(artifact.path);

    expect(facts.duration, const Duration(milliseconds: 2500));
    expect(facts.byteSize, 128);
    expect(facts.decodable, isTrue);
  });

  test('rejects malformed metadata and decode failures', () async {
    final malformed = LinuxMeetingArtifactInspector(
      runner: (_, _) async =>
          const CommandResult(exitCode: 0, stdout: 'not-json'),
    );
    await expectLater(
      malformed.call(artifact.path),
      throwsA(isA<MeetingArtifactInvalidError>()),
    );

    final decodeFailure = LinuxMeetingArtifactInspector(
      runner: (executable, _) async => executable == 'ffprobe'
          ? const CommandResult(
              exitCode: 0,
              stdout:
                  '''{"streams":[{"codec_name":"aac","profile":"LC","sample_rate":"48000","channels":1}],"format":{"format_name":"m4a","duration":"1","size":"128"}}''',
            )
          : const CommandResult(exitCode: 1, stdout: ''),
    );
    expect((await decodeFailure.call(artifact.path)).decodable, isFalse);
  });
}
