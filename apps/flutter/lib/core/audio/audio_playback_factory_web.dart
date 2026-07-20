import 'audio_playback.dart';
import 'just_audio_playback.dart';

/// Web [AudioPlayback] selection (#870). just_audio's web backend
/// (just_audio_web, HTML5 audio) is used directly — no media_kit on web.
AudioPlayback createAudioPlayback() => JustAudioPlayback();
