import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:meeting_capture_macos/meeting_capture_macos.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const methodChannel = MethodChannel('matome.meeting_capture/methods');

  tearDown(() => messenger.setMockMethodCallHandler(methodChannel, null));

  test('registerWith installs MeetingCaptureMacos as the platform instance', () {
    MeetingCaptureMacos.registerWith();
    expect(MeetingCapturePlatform.instance, isA<MeetingCaptureMacos>());
  });

  test('createBackend returns the shared channel backend with the sck id', () {
    final backend = MeetingCaptureMacos().createBackend();
    expect(backend, isA<MethodChannelMeetingCaptureBackend>());
    expect(backend.backendId, 'macos-screencapturekit');
  });

  test('probe delegates to the native method channel', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'probe') {
        return {'supported': true, 'backendId': 'macos-screencapturekit'};
      }
      return null;
    });
    final capability = await MeetingCaptureMacos().probe();
    expect(capability.supported, isTrue);
    expect(capability.backendId, 'macos-screencapturekit');
  });
}
