import 'package:meeting_capture/meeting_capture.dart';

/// macOS endorsement of [MeetingCapturePlatform]. Registered by the Flutter
/// generated macOS registrant (dartPluginClass), which calls [registerWith].
/// Capture runs in the native Swift plugin (pluginClass `MeetingCaptureMacosPlugin`)
/// via ScreenCaptureKit behind the shared meeting-capture channels.
class MeetingCaptureMacos extends MeetingCapturePlatform {
  static const String backendId = 'macos-screencapturekit';

  /// Must be `static` with no arguments (Dart-only plugin-class contract).
  static void registerWith() {
    MeetingCapturePlatform.instance = MeetingCaptureMacos();
  }

  MethodChannelMeetingCaptureBackend _backend() =>
      MethodChannelMeetingCaptureBackend(backendId: backendId);

  @override
  Future<MeetingCaptureCapability> probe() async {
    final backend = _backend();
    try {
      return await backend.probe();
    } finally {
      await backend.dispose();
    }
  }

  @override
  MeetingCaptureBackend createBackend() => _backend();

  @override
  MeetingArtifactInspector createArtifactInspector() =>
      channelMeetingArtifactInspector();
}
