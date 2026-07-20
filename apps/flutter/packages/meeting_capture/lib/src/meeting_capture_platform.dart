import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'meeting_capture_backend.dart';

/// Federated entry point. The app composition root resolves the meeting-capture
/// backend and artifact inspector exclusively through
/// [MeetingCapturePlatform.instance], so it never names a platform-specific
/// type. A platform implementation package (e.g. `meeting_capture_linux`)
/// registers itself via [registerWith] at startup. On a platform with no
/// registered implementation the default [_UnsupportedMeetingCapturePlatform]
/// stays in place and capability probing reports `platform-unsupported`, which
/// the UI uses to hide/disable the Meeting entry points.
abstract class MeetingCapturePlatform extends PlatformInterface {
  MeetingCapturePlatform() : super(token: _token);

  static final Object _token = Object();

  static MeetingCapturePlatform _instance =
      _UnsupportedMeetingCapturePlatform();

  static MeetingCapturePlatform get instance => _instance;

  static set instance(MeetingCapturePlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  /// Cheap capability gate for the UI. Never throws.
  Future<MeetingCaptureCapability> probe() {
    throw UnimplementedError('probe() has not been implemented.');
  }

  /// Constructs a fresh capture backend. Callers own its lifecycle (dispose).
  MeetingCaptureBackend createBackend() {
    throw UnimplementedError('createBackend() has not been implemented.');
  }

  /// Returns the platform artifact inspector (validates the recorded file).
  MeetingArtifactInspector createArtifactInspector() {
    throw UnimplementedError(
      'createArtifactInspector() has not been implemented.',
    );
  }
}

/// Default when no implementation is registered for the running platform.
class _UnsupportedMeetingCapturePlatform extends MeetingCapturePlatform {
  @override
  Future<MeetingCaptureCapability> probe() async =>
      const MeetingCaptureCapability.unsupported(
        backendId: 'unsupported',
        reason: 'platform-unsupported',
      );

  @override
  MeetingCaptureBackend createBackend() => const _UnsupportedBackend();

  @override
  MeetingArtifactInspector createArtifactInspector() =>
      (path) async =>
          throw const MeetingCaptureUnsupportedError('platform-unsupported');
}

/// Degrades gracefully if the app ever builds a backend on a platform without a
/// registered implementation: probe reports unsupported and every capture verb
/// fails closed rather than pretending to record.
class _UnsupportedBackend implements MeetingCaptureBackend {
  const _UnsupportedBackend();

  @override
  String get backendId => 'unsupported';

  @override
  Stream<MeetingCaptureEvent> get events => const Stream.empty();

  @override
  Future<MeetingCaptureCapability> probe() async =>
      const MeetingCaptureCapability.unsupported(
        backendId: 'unsupported',
        reason: 'platform-unsupported',
      );

  @override
  Future<MeetingCapturePermission> requestPermission() async =>
      MeetingCapturePermission.denied;

  @override
  Future<void> start(MeetingCaptureRequest request) async =>
      throw const MeetingCaptureUnsupportedError('platform-unsupported');

  @override
  Future<MeetingCaptureCandidate> stop() async =>
      throw const MeetingCaptureUnsupportedError('platform-unsupported');

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
