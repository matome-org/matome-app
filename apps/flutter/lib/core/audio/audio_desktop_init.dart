/// Desktop audio backend initialization (#870, plan #46 W1).
///
/// Registers media_kit under the just_audio platform interface on Linux/Windows
/// (the platforms where just_audio 0.9.x has NO native backend). A conditional
/// import keeps the dart:io / native-only just_audio_media_kit out of web
/// builds; on web this resolves to a no-op.
library;

import 'audio_desktop_init_noop.dart'
    if (dart.library.io) 'audio_desktop_init_io.dart' as impl;

/// Initialize the desktop playback backend if the current platform needs it.
/// No-op on mobile (just_audio native already works) and web.
void initDesktopAudioBackend() => impl.initDesktopAudioBackend();
