/// Platform-swappable audio playback abstraction (#870, plan #46 W1).
///
/// WHY: `just_audio` 0.9.x ships NO Linux/Windows desktop backend, so on Linux
/// desktop `setFilePath`/`setUrl`/`play` AND the duration probe silently no-op —
/// the user heard no audio at all. The fix can't be a hard swap to one engine,
/// because the right engine differs per platform (just_audio is great on
/// mobile/web; desktop needs media_kit/libmpv). So we hide the engine behind an
/// [AudioPlayback] interface and pick the backend per platform via a factory
/// ([createAudioPlayback]) — future device builds swap the engine without
/// touching any call site.
///
/// This interface exposes EXACTLY what the Details audio player
/// (`features/details/audio_player_bar.dart`) and the duration-probe helper
/// (`AudioRecordingService.getAudioDurationSeconds`) need from the underlying
/// engine — no more. It stays trivially FAKEABLE so the widget/service tests
/// keep injecting a fake instead of a real engine.
library;

import 'audio_playback_factory.dart'
    if (dart.library.html) 'audio_playback_factory_web.dart' as factory_impl;

/// What the player can be told to load: a local file path or a remote URL.
enum PlaybackSourceKind { localFile, remoteUrl }

/// A coarse play/pause snapshot, streamed so the UI can rebuild on transitions.
/// Intentionally minimal — the bar only reads `playing`.
class PlaybackState {
  const PlaybackState({required this.playing});

  final bool playing;
}

/// Engine-agnostic audio playback surface.
///
/// Implementations wrap a concrete engine (just_audio on mobile/web, media_kit
/// on desktop). Mirrors the slice of `just_audio.AudioPlayer` the app actually
/// uses, so the just_audio-backed implementation is a thin pass-through and the
/// media_kit-backed one (via just_audio_media_kit's endorsement) is identical.
abstract class AudioPlayback {
  /// Load a local file. Resolves with the clip duration when the engine can
  /// determine it (null otherwise). Used both to prime the player AND as the
  /// duration probe.
  Future<Duration?> setFilePath(String path);

  /// Load a remote URL (e.g. a Core presigned link). Resolves with the clip
  /// duration when known.
  Future<Duration?> setUrl(String url);

  /// Begin / resume playback.
  Future<void> play();

  /// Pause playback (position is retained).
  Future<void> pause();

  /// Seek to [position].
  Future<void> seek(Duration position);

  /// True while audio is actively playing.
  bool get playing;

  /// Current playback head (or null before load).
  Duration get position;

  /// Total clip duration once known (null until loaded / if indeterminate).
  Duration? get duration;

  /// Play/pause transitions.
  Stream<PlaybackState> get playerStateStream;

  /// Position ticks while playing / on seek.
  Stream<Duration> get positionStream;

  /// Release native resources. Safe to call once.
  Future<void> dispose();
}

/// Build the platform-appropriate [AudioPlayback].
///
/// Backend mapping (see `audio_playback_factory.dart`):
///   * Linux / Windows desktop → media_kit (via just_audio_media_kit endorsing
///     just_audio). REQUIRES `JustAudioMediaKit.ensureInitialized()` to have run
///     once at startup (done in main.dart).
///   * Android / iOS / macOS / web → just_audio native.
AudioPlayback createAudioPlayback() => factory_impl.createAudioPlayback();
