import 'package:flutter/material.dart';

import '../../core/audio/audio_playback.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import 'details_controller.dart';

/// Compact audio player for the Details screen (S2): a play/pause button, a
/// scrubbable progress bar, current position / total duration and the file size
/// when known. Loads from a local file path or a Core presigned URL via
/// [AudioSource]. Mirrors the apps/mobile Details player (play/pause + progress
/// + time + file size) using a Material slider in place of the RN waveform.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({super.key, required this.source, this.player});

  final AudioSource source;

  /// Injectable for tests (a fake [AudioPlayback]); production builds the
  /// platform-appropriate backend via [createAudioPlayback].
  final AudioPlayback? player;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  late final AudioPlayback _player;
  bool _ownsPlayer = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _player = widget.player ?? createAudioPlayback();
    _ownsPlayer = widget.player == null;
    _load();
  }

  @override
  void didUpdateWidget(covariant AudioPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the resolved source changes (e.g. a local file was missing on first
    // build and a Core presigned URL resolved later, or a retry produced a new
    // path), clear the stale `_loadError` and reload — otherwise a previously
    // failed source stays stuck on the "audio unavailable" surface forever.
    final old = oldWidget.source;
    final now = widget.source;
    if (old.kind != now.kind || old.value != now.value) {
      _loadError = null;
      _load();
    }
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

  /// Graceful "audio unavailable" state (plan #45 W1): shown when no playable
  /// source resolved — neither a local file nor a remote URL — so the user gets
  /// a clear, disabled affordance + message instead of a dead silent play
  /// button. Distinct surface (muted) so it reads as inert, not actionable.
  Widget _buildUnavailable(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: const ValueKey('audio-unavailable'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: spacing.xxl,
            height: spacing.xxl,
            child: Material(
              color: colors.border,
              shape: const CircleBorder(),
              child: Icon(
                Icons.music_off,
                color: colors.textMuted,
                size: spacing.lg,
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              t.details.audioUnavailable,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    // Plan #45 W1: when NEITHER a local file NOR a remote URL resolved (kind ==
    // none) — or the only resolved source failed to load — there is nothing to
    // play. Surface a graceful "audio unavailable" state instead of a dead,
    // silent play button the user can tap to no effect.
    final unavailable =
        widget.source.kind == AudioSourceKind.none || _loadError != null;
    if (unavailable) return _buildUnavailable(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: StreamBuilder<PlaybackState>(
        stream: _player.playerStateStream,
        builder: (context, stateSnap) {
          final playing = stateSnap.data?.playing ?? false;
          return Column(
            children: [
              Row(
                children: [
                  _PlayButton(playing: playing, onPressed: _togglePlay),
                  SizedBox(width: spacing.sm),
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
                            activeTrackColor: colors.accent,
                            inactiveTrackColor: colors.border,
                            thumbColor: colors.accent,
                          ),
                          child: Slider(
                            value: max > 0 ? value : 0,
                            max: max > 0 ? max : 1,
                            onChanged: max <= 0
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
              SizedBox(height: spacing.xxs),
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
                        style: typography.label.copyWith(
                          color: colors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _fmt(duration),
                        style: typography.label.copyWith(
                          color: colors.textSecondary,
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
    final colors = context.colors;
    final spacing = context.spacing;
    // Icon-only control — give it a screen-reader label + tooltip that tracks
    // the current action (plan #45, W3). 48×48 already meets the tap target.
    final label = playing ? t.a11y.pause : t.a11y.play;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        enabled: onPressed != null,
        child: SizedBox(
          width: spacing.xxl,
          height: spacing.xxl,
          child: Material(
            color: onPressed == null ? colors.border : colors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                color: colors.textPrimary,
                size: spacing.lg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
