import 'package:meeting_capture/meeting_capture.dart';

import 'meeting_artifact_inspector.dart';
import 'meeting_loopback_source.dart';
import 'meeting_recorder_backend.dart';

/// Linux endorsement of [MeetingCapturePlatform]. Registered automatically by
/// the Flutter-generated Linux plugin registrant, which imports this package
/// and calls [registerWith]. Never imported by app or facade source, so its
/// ffmpeg/pactl code stays out of Windows/macOS AOT snapshots.
class MeetingCaptureLinux extends MeetingCapturePlatform {
  /// Must be `static` and take no arguments — the contract for a Dart-only
  /// federated plugin class.
  static void registerWith() {
    MeetingCapturePlatform.instance = MeetingCaptureLinux();
  }

  @override
  Future<MeetingCaptureCapability> probe() async {
    final backend = MeetingRecorderBackend(
      loopback: const MeetingLoopbackSource(),
    );
    try {
      return await backend.probe();
    } finally {
      await backend.dispose();
    }
  }

  @override
  MeetingCaptureBackend createBackend() =>
      MeetingRecorderBackend(loopback: const MeetingLoopbackSource());

  @override
  MeetingArtifactInspector createArtifactInspector() =>
      const LinuxMeetingArtifactInspector().call;
}
