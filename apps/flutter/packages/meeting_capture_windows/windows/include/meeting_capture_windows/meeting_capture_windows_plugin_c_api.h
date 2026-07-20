#ifndef FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Entry point invoked by the Flutter-generated Windows plugin registrant. The
// symbol name must be "<pluginClass>RegisterWithRegistrar" where pluginClass is
// the `pluginClass` declared in pubspec.yaml (MeetingCaptureWindowsPluginCApi).
FLUTTER_PLUGIN_EXPORT void MeetingCaptureWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_MEETING_CAPTURE_WINDOWS_PLUGIN_C_API_H_
