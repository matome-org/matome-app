import 'package:flutter/foundation.dart';

import 'audio_playback.dart';
import 'just_audio_playback.dart';

/// Per-platform [AudioPlayback] selection for non-web targets (#870).
///
/// Keyed on [defaultTargetPlatform] so future device builds can swap the engine
/// here WITHOUT touching call sites:
///   * Linux / Windows → just_audio routed onto media_kit (libmpv) via
///     just_audio_media_kit's endorsement (init'd in main.dart). Resolves the
///     desktop "no audio" bug — just_audio 0.9.x has no native desktop backend.
///   * Android / iOS / macOS → just_audio native.
///
/// All branches currently return [JustAudioPlayback] because just_audio_media_kit
/// endorses just_audio (so one wrapper serves desktop too). The switch is kept
/// explicit and exhaustive so swapping any single platform to a different engine
/// is a one-line change with no call-site churn.
AudioPlayback createAudioPlayback() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      // media_kit via just_audio endorsement.
      return JustAudioPlayback();
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.fuchsia:
      return JustAudioPlayback();
  }
}
