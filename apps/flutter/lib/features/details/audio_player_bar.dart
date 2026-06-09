import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' hide AudioSource;

import '../../core/theme/app_theme.dart';
import 'details_controller.dart';

/// Compact audio player for the Details screen (S2): a play/pause button, a
/// scrubbable progress bar, current position / total duration and the file size
/// when known. Loads from a local file path or a Core presigned URL via
/// [AudioSource]. Mirrors the apps/mobile Details player (play/pause + progress
/// + time + file size) using a Material slider in place of the RN waveform.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({super.key, required this.source, this.player});

  final AudioSource source;

  /// Injectable for tests (a fake [AudioPlayer]); production builds its own.
  final AudioPlayer? player;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  late final AudioPlayer _player;
  bool _ownsPlayer = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _player = widget.player ?? AudioPlayer();
    _ownsPlayer = widget.player == null;
    _load();
  }

  Future<void> _load() async {
    final source = widget.source;
    if (source.kind == AudioSourceKind.none || source.value == null) return;
    try {
      switch (source.kind) {
        case AudioSourceKind.localFile:
          await _player.setFilePath(source.value!);
        case AudioSourceKind.remoteUrl:
          await _player.setUrl(source.value!);
        case AudioSourceKind.none:
          break;
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    if (_ownsPlayer) _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        final pos = _player.position;
        final dur = _player.duration;
        if (dur != null && pos >= dur) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
    } catch (_) {
      // Swallow transient playback errors (matches RN toast-then-ignore).
    }
  }

  static String _fmt(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.source.kind == AudioSourceKind.none || _loadError != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, stateSnap) {
          final playing = stateSnap.data?.playing ?? false;
          return Column(
            children: [
              Row(
                children: [
                  _PlayButton(
                    playing: playing,
                    onPressed: disabled ? null : _togglePlay,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, posSnap) {
                        final position = posSnap.data ?? Duration.zero;
                        final duration = _player.duration ?? Duration.zero;
                        final max = duration.inMilliseconds.toDouble();
                        final value = position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble();
                        return SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: AppColors.border,
                            thumbColor: AppColors.accent,
                          ),
                          child: Slider(
                            value: max > 0 ? value : 0,
                            max: max > 0 ? max : 1,
                            onChanged: (disabled || max <= 0)
                                ? null
                                : (v) => _player.seek(
                                      Duration(milliseconds: v.round()),
                                    ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, posSnap) {
                  final position = posSnap.data ?? Duration.zero;
                  final duration = _player.duration ?? Duration.zero;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(position),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _fmt(duration),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: onPressed == null ? AppColors.border : AppColors.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: AppColors.textPrimary,
            size: 26,
          ),
        ),
      ),
    );
  }
}
