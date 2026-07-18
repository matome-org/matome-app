import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:meeting_capture_windows/meeting_capture_windows.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const methodChannel = MethodChannel('matome.meeting_capture/methods');

  tearDown(() => messenger.setMockMethodCallHandler(methodChannel, null));

  test('registerWith installs MeetingCaptureWindows as the platform instance',
      () {
    MeetingCaptureWindows.registerWith();
    expect(MeetingCapturePlatform.instance, isA<MeetingCaptureWindows>());
  });

  test('createBackend returns the shared channel backend with the wasapi id',
      () {
    final backend = MeetingCaptureWindows().createBackend();
    expect(backend, isA<MethodChannelMeetingCaptureBackend>());
    expect(backend.backendId, 'windows-wasapi');
  });

  test('probe delegates to the native method channel', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'probe') {
        return {'supported': true, 'backendId': 'windows-wasapi'};
      }
      return null;
    });
    final capability = await MeetingCaptureWindows().probe();
    expect(capability.supported, isTrue);
    expect(capability.backendId, 'windows-wasapi');
  });

  test('createArtifactInspector is channel-backed', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'inspect') {
        return {
          'decodable': true,
          'sampleRate': 48000,
          'channels': 1,
          'durationUs': 1000000,
          'byteSize': 2048,
        };
      }
      return null;
    });
    final inspect = MeetingCaptureWindows().createArtifactInspector();
    final facts = await inspect('/tmp/x.m4a');
    expect(facts.decodable, isTrue);
    expect(facts.sampleRate, 48000);
  });
}
