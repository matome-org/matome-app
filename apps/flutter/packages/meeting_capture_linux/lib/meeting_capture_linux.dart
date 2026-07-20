/// Linux ffmpeg/PulseAudio implementation of the meeting_capture contract.
///
/// The Flutter-generated Linux plugin registrant imports this library and calls
/// [MeetingCaptureLinux.registerWith]. Tests import it for the concrete impl
/// types. App and facade source must NEVER import this package (only the
/// generated Linux registrant may) — that import boundary is what keeps this
/// code out of Windows/macOS bundles.
library;

export 'src/meeting_artifact_inspector.dart';
export 'src/meeting_capture_linux.dart';
export 'src/meeting_loopback_source.dart';
export 'src/meeting_recorder_backend.dart';
