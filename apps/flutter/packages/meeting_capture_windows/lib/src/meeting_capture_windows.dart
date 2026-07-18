import 'package:meeting_capture/meeting_capture.dart';

/// Windows endorsement of [MeetingCapturePlatform]. Registered by the Flutter
/// generated Windows registrant (dartPluginClass), which calls [registerWith].
/// The actual capture runs in the native C++ plugin (pluginClass
/// `MeetingCaptureWindowsPluginCApi`) behind the shared meeting-capture channels;
/// the Dart side is the platform-neutral [MethodChannelMeetingCaptureBackend].
class MeetingCaptureWindows extends MeetingCapturePlatform {
  static const String backendId = 'windows-wasapi';

  /// Must be `static` with no arguments (Dart-only plugin-class contract).
  static void registerWith() {
    MeetingCapturePlatform.instance = MeetingCaptureWindows();
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
