// On-device integration tests for the macOS (ScreenCaptureKit) backend.
//
// Run on a REAL macOS 15+ host (they exercise the native plugin):
//   cd apps/flutter/packages/meeting_capture_macos/example
//   flutter create --platforms=macos .          # generate the runner once
//   flutter test integration_test/capture_test.dart -d macos
//
// Requires Screen Recording + Microphone permission for the example app
// (System Settings → Privacy & Security). The `capture round-trip` group is the
// on-device TDD target for task #1280 and is EXPECTED TO FAIL until the SCStream
// capture + AVAssetWriter M4A encode are implemented.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('probe + permission (should pass once the plugin compiles)', () {
    test('probe reports a macos-screencapturekit backend', () async {
      final capability = await MeetingCapturePlatform.instance.probe();
      expect(capability.backendId, 'macos-screencapturekit');
      expect(capability.supported, isA<bool>());
    });

    test('requestPermission resolves', () async {
      final backend = MeetingCapturePlatform.instance.createBackend();
      addTearDown(backend.dispose);
      final permission = await backend.requestPermission();
      expect(permission, isA<MeetingCapturePermission>());
    });
  });

  group('capture round-trip (TDD target for #1280 — expected red)', () {
    test('records a playable M4A that passes the inspector', () async {
      final capability = await MeetingCapturePlatform.instance.probe();
      if (!capability.supported) {
        markTestSkipped('not permitted on this host: ${capability.reason}');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/meeting-itest.m4a';
      final backend = MeetingCapturePlatform.instance.createBackend();
      addTearDown(backend.dispose);

      final states = <MeetingCaptureState?>[];
      backend.events.listen((e) => states.add(e.state));

      await backend.start(
        MeetingCaptureRequest(sessionId: 'itest', stagingPath: path),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      final candidate = await backend.stop();

      expect(states, contains(MeetingCaptureState.recording));
      expect(File(candidate.path).existsSync(), isTrue);
      expect(await File(candidate.path).length(), greaterThan(1024));

      final facts =
          await MeetingCapturePlatform.instance.createArtifactInspector()(
        candidate.path,
      );
      expect(facts.decodable, isTrue);
      expect(facts.codec, MeetingAudioCodec.aacLc);
    });
  });
}
