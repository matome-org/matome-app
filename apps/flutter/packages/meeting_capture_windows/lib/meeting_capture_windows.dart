/// Windows (WASAPI) implementation of the meeting_capture contract.
///
/// The Flutter-generated Windows registrant imports this library and calls
/// [MeetingCaptureWindows.registerWith]; the native plugin
/// (`MeetingCaptureWindowsPluginCApi`) handles the method/event channels. App and
/// facade source must never import this package — only the generated Windows
/// registrant may — which is what keeps its code out of Linux/macOS bundles.
library;

export 'src/meeting_capture_windows.dart';
