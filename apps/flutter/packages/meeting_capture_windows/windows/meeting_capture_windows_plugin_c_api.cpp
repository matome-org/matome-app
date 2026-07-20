#include "include/meeting_capture_windows/meeting_capture_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "meeting_capture_windows_plugin.h"

void MeetingCaptureWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  meeting_capture_windows::MeetingCaptureWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
