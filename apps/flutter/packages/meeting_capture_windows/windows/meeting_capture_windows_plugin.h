#ifndef FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <string>

#include "event_stream_handler.h"

namespace meeting_capture_windows {

// Forward declaration; the WASAPI capture session lives in the .cpp so the
// header stays free of the Core Audio / Media Foundation headers.
class CaptureSession;

class MeetingCaptureWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  explicit MeetingCaptureWindowsPlugin(
      flutter::PluginRegistrarWindows* registrar);

  ~MeetingCaptureWindowsPlugin() override;

  MeetingCaptureWindowsPlugin(const MeetingCaptureWindowsPlugin&) = delete;
  MeetingCaptureWindowsPlugin& operator=(const MeetingCaptureWindowsPlugin&) =
      delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Real WASAPI enumeration: default render (loopback source) + default capture
  // (microphone) must both exist for meeting capture to be supported.
  flutter::EncodableValue Probe();

  flutter::PluginRegistrarWindows* registrar_;

  // One capture session per sessionId + the EventChannel that streams its
  // state/level/failure events to Dart.
  std::map<std::string, std::unique_ptr<CaptureSession>> sessions_;
  std::map<std::string,
           std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>>
      event_channels_;
  std::map<std::string, EventStreamHandler<flutter::EncodableValue>*>
      event_handlers_;
};

}  // namespace meeting_capture_windows

#endif  // FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_PLUGIN_H_
