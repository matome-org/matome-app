import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/audio/audio_playback.dart';
import 'package:matome_flutter/features/details/audio_player_bar.dart';
import 'package:matome_flutter/features/details/details_controller.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// In-memory [AudioPlayback] fake (#870). Proves the platform-swappable
/// abstraction stays trivially fakeable — the bar drives THIS instead of a real
/// just_audio/media_kit engine in tests, with no native backend required.
class FakeAudioPlayback implements AudioPlayback {
  FakeAudioPlayback({this.fileDuration = const Duration(seconds: 30)});

  final Duration fileDuration;

  final List<String> calls = [];
  final _stateCtrl = StreamController<PlaybackState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool disposed = false;

  @override
  Future<Duration?> setFilePath(String path) async {
    calls.add('setFilePath:$path');
    _duration = fileDuration;
    return _duration;
  }

  @override
  Future<Duration?> setUrl(String url) async {
    calls.add('setUrl:$url');
    _duration = fileDuration;
    return _duration;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
    _stateCtrl.add(PlaybackState(playing: _playing));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
    _stateCtrl.add(PlaybackState(playing: _playing));
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    _position = position;
    _posCtrl.add(_position);
  }

  @override
  bool get playing => _playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  Stream<PlaybackState> get playerStateStream => _stateCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _stateCtrl.close();
    await _posCtrl.close();
  }
}

/// Plan #45 W1 — when NEITHER a local file nor a remote URL resolved
/// ([AudioSourceKind.none]), the player must surface a graceful "audio
/// unavailable" state instead of a dead, silent play button.
void main() {
  Widget host(AudioSource source, {AudioPlayback? player}) {
    return TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: AudioPlayerBar(source: source, player: player),
        ),
      ),
    );
  }

  testWidgets(
      'AudioSourceKind.none renders the "audio unavailable" state, not a play '
      'button', (tester) async {
    await tester.pumpWidget(host(const AudioSource.none()));
    await tester.pump();

    // The graceful unavailable surface is shown…
    expect(find.byKey(const ValueKey('audio-unavailable')), findsOneWidget);
    expect(find.text(t.details.audioUnavailable), findsOneWidget);
    expect(find.byIcon(Icons.music_off), findsOneWidget);

    // …and there is NO active play affordance to tap to no effect.
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets(
      'local file routes load + play/pause through the injected AudioPlayback '
      'backend (fakeable abstraction)', (tester) async {
    final fake = FakeAudioPlayback();
    await tester.pumpWidget(
      host(const AudioSource(AudioSourceKind.localFile, '/tmp/clip.m4a'),
          player: fake),
    );
    await tester.pump();

    // The bar loaded the local file through the abstraction (not a real engine).
    expect(fake.calls, contains('setFilePath:/tmp/clip.m4a'));

    // Tapping play routes through the backend…
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(fake.calls, contains('play'));

    // …and the play/pause stream flips the control to pause.
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(fake.calls, contains('pause'));
  });

  testWidgets('remote url is loaded via the backend', (tester) async {
    final fake = FakeAudioPlayback();
    await tester.pumpWidget(
      host(const AudioSource(AudioSourceKind.remoteUrl, 'https://x/a.mp3'),
          player: fake),
    );
    await tester.pump();
    expect(fake.calls, contains('setUrl:https://x/a.mp3'));
  });
}
