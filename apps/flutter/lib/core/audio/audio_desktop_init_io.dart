import 'dart:io' show Platform;

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// Native (dart:io) [initDesktopAudioBackend]: on Linux/Windows, register
/// media_kit as the just_audio backend so playback + the duration probe work
/// (just_audio 0.9.x has no native desktop backend). On Android/iOS/macOS the
/// just_audio native backend already works, so we DON'T initialize media_kit
/// there — avoiding an extra native engine where it isn't needed.
///
/// RUNTIME DEP: media_kit needs libmpv at runtime on Linux (Arch: `mpv`); the
/// shared libs are bundled by media_kit_libs_linux / media_kit_libs_windows_audio.
void initDesktopAudioBackend() {
  if (Platform.isLinux || Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(
      linux: true,
      windows: true,
      // Leave mobile/macOS to just_audio's native backend.
      android: false,
      iOS: false,
      macOS: false,
    );
  }
}
