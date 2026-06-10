import 'package:just_audio/just_audio.dart' as ja;

import 'audio_playback.dart';

/// [AudioPlayback] backed by `just_audio`.
///
/// On Android/iOS/macOS/web this drives just_audio's native engine directly.
/// On Linux/Windows the SAME wrapper drives media_kit (libmpv) transparently,
/// because `just_audio_media_kit` ENDORSES just_audio there — once
/// `JustAudioMediaKit.ensureInitialized()` has run (main.dart), the just_audio
/// platform interface routes to media_kit, so this wrapper needs no desktop
/// special-casing. That endorsement is the whole reason a single just_audio
/// wrapper can serve every platform; the per-platform decision lives in the
/// factory (so a future build can swap to a hand-wrapped engine) and in the
/// startup init.
class JustAudioPlayback implements AudioPlayback {
  JustAudioPlayback() : _player = ja.AudioPlayer();

  final ja.AudioPlayer _player;

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<Duration?> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  bool get playing => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Stream<PlaybackState> get playerStateStream => _player.playerStateStream
      .map((s) => PlaybackState(playing: s.playing));

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> dispose() => _player.dispose();
}
