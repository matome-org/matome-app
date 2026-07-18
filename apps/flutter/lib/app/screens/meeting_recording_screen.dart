import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/recording/audio_recording_service.dart';
import 'package:meeting_capture/meeting_capture.dart';
import '../../features/recording/meeting_capture_finish.dart';
import '../../features/recording/meeting_capture_service.dart';
import '../../features/recording/meeting_recorder.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/loading_indicator.dart';

enum _MeetingPhase {
  loading,
  unsupported,
  recovery,
  idle,
  recording,
  saving,
  failed,
}

class MeetingRecordingBinding {
  MeetingRecordingBinding({
    FutureProvider<MeetingCaptureCapability>? capabilityProvider,
    Provider<MeetingCaptureService>? serviceProvider,
    Provider<MeetingCaptureFinisher>? finisherProvider,
  }) : capabilityProvider =
           capabilityProvider ?? meetingCaptureCapabilityProvider,
       serviceProvider = serviceProvider ?? meetingCaptureServiceProvider,
       finisherProvider = finisherProvider ?? meetingCaptureFinisherProvider;

  final FutureProvider<MeetingCaptureCapability> capabilityProvider;
  final Provider<MeetingCaptureService> serviceProvider;
  final Provider<MeetingCaptureFinisher> finisherProvider;
}

class MeetingRecordingScreen extends ConsumerStatefulWidget {
  MeetingRecordingScreen({super.key, MeetingRecordingBinding? binding})
    : binding = binding ?? MeetingRecordingBinding();

  final MeetingRecordingBinding binding;

  @override
  ConsumerState<MeetingRecordingScreen> createState() =>
      _MeetingRecordingScreenState();
}

class _MeetingRecordingScreenState
    extends ConsumerState<MeetingRecordingScreen> {
  _MeetingPhase _phase = _MeetingPhase.loading;
  MeetingCaptureArtifact? _recovered;
  String? _unsupportedReason;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  double _systemLevel = -160;
  double _microphoneLevel = -160;
  Timer? _clock;
  StreamSubscription<MeetingCaptureEvent>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _events?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final capability = await ref.read(widget.binding.capabilityProvider.future);
    if (!mounted) return;
    if (!capability.supported) {
      setState(() {
        _unsupportedReason = _capabilityReason(capability.reason);
        _phase = _MeetingPhase.unsupported;
      });
      return;
    }
    final service = ref.read(widget.binding.serviceProvider);
    _events = service.events.listen(_handleEvent);
    try {
      final recovered = await service.recover();
      if (!mounted) return;
      setState(() {
        _recovered = recovered;
        _phase = recovered == null
            ? _MeetingPhase.idle
            : _MeetingPhase.recovery;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _MeetingPhase.idle);
    }
  }

  void _handleEvent(MeetingCaptureEvent event) {
    if (!mounted) return;
    if (event.levelDb != null) {
      setState(() {
        if (event.source == MeetingCaptureSource.system) {
          _systemLevel = event.levelDb!;
        } else if (event.source == MeetingCaptureSource.microphone) {
          _microphoneLevel = event.levelDb!;
        }
      });
    }
    if (event.state == MeetingCaptureState.failed ||
        (event.state == MeetingCaptureState.unavailable &&
            event.source != null)) {
      _clock?.cancel();
      setState(() => _phase = _MeetingPhase.failed);
    }
  }

  Future<void> _start() async {
    try {
      await ref.read(widget.binding.serviceProvider).start();
      if (!mounted) return;
      _startedAt = DateTime.now();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
      setState(() => _phase = _MeetingPhase.recording);
    } catch (_) {
      if (mounted) _snack(t.meetingRecording.startFailed);
    }
  }

  Future<void> _finish() async {
    _clock?.cancel();
    setState(() => _phase = _MeetingPhase.saving);
    try {
      await ref.read(widget.binding.finisherProvider).finish();
      if (mounted) _close();
    } catch (_) {
      if (!mounted) return;
      _snack(t.meetingRecording.saveFailed);
      setState(() => _phase = _MeetingPhase.failed);
    }
  }

  Future<void> _saveRecovered() async {
    final artifact = _recovered;
    if (artifact == null) return;
    setState(() => _phase = _MeetingPhase.saving);
    try {
      await ref
          .read(widget.binding.finisherProvider)
          .persistRecovered(artifact);
      if (mounted) _close();
    } catch (_) {
      if (!mounted) return;
      _snack(t.meetingRecording.saveFailed);
      setState(() => _phase = _MeetingPhase.recovery);
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: Text(t.meetingRecording.discardTitle),
        content: Text(t.meetingRecording.discardBody),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.meetingRecording.keep),
          ),
          PrimaryButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.meetingRecording.discard),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final service = ref.read(widget.binding.serviceProvider);
      if (_phase == _MeetingPhase.recovery) {
        await service.discardRecovered();
      } else if (_phase == _MeetingPhase.recording) {
        await service.cancel();
      }
      if (mounted) _close();
    } catch (_) {
      if (mounted) _snack(t.meetingRecording.saveFailed);
    }
  }

  String _capabilityReason(String? reason) => switch (reason) {
    'linux-required' => t.meetingRecording.linuxRequired,
    'ffmpeg-required' => t.meetingRecording.ffmpegRequired,
    'ffprobe-required' => t.meetingRecording.ffprobeRequired,
    'pactl-required' => t.meetingRecording.pactlRequired,
    'audio-server-unavailable' => t.meetingRecording.audioServerUnavailable,
    'audio-devices-unavailable' => t.meetingRecording.audioDevicesUnavailable,
    _ => t.meetingRecording.probeFailed,
  };

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inbox');
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(spacing.xs),
                child: IconButton(
                  tooltip: t.common.cancel,
                  onPressed:
                      _phase == _MeetingPhase.recording ||
                          _phase == _MeetingPhase.recovery
                      ? _discard
                      : _close,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            Center(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    if (_phase == _MeetingPhase.loading || _phase == _MeetingPhase.saving) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoadingIndicator(),
          SizedBox(height: spacing.md),
          Text(
            _phase == _MeetingPhase.saving
                ? t.meetingRecording.processing
                : t.recording.loading,
          ),
        ],
      );
    }
    if (_phase == _MeetingPhase.unsupported) {
      return _Message(
        icon: Icons.headset_off,
        title: t.meetingRecording.unsupportedTitle,
        body: _unsupportedReason ?? t.meetingRecording.probeFailed,
      );
    }
    if (_phase == _MeetingPhase.failed) {
      return _Message(
        icon: Icons.usb_off,
        title: t.meetingRecording.deviceLost,
        body: t.meetingRecording.saveFailed,
      );
    }
    if (_phase == _MeetingPhase.recovery) {
      return _Message(
        icon: Icons.restore,
        title: t.meetingRecording.recoveryTitle,
        body: t.meetingRecording.recoveryHint,
        action: PrimaryButton(
          onPressed: _saveRecovered,
          child: Text(t.meetingRecording.saveRecovered),
        ),
      );
    }
    final recording = _phase == _MeetingPhase.recording;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            recording ? t.meetingRecording.recording : t.meetingRecording.ready,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            recording
                ? t.meetingRecording.recordingHint
                : t.meetingRecording.startHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: spacing.xl),
          Text(
            AudioRecordingService.formatDuration(
              _elapsed.inMilliseconds / 1000,
            ),
            key: const Key('meeting-recording-timer'),
            style: theme.textTheme.displaySmall,
          ),
          SizedBox(height: spacing.lg),
          _LevelRow(label: t.meetingRecording.systemAudio, level: _systemLevel),
          SizedBox(height: spacing.sm),
          _LevelRow(
            label: t.meetingRecording.microphone,
            level: _microphoneLevel,
          ),
          SizedBox(height: spacing.xl),
          PrimaryButton(
            key: Key(
              recording ? 'meeting-finish-button' : 'meeting-start-button',
            ),
            onPressed: recording ? _finish : _start,
            child: Text(
              recording ? t.meetingRecording.finish : t.meetingRecording.start,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.label, required this.level});
  final String label;
  final double level;

  @override
  Widget build(BuildContext context) {
    final normalized = ((level + 60) / 60).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(width: 112, child: Text(label)),
        Expanded(child: LinearProgressIndicator(value: normalized)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: colors.accent),
          SizedBox(height: spacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: spacing.xs),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...[SizedBox(height: spacing.lg), action!],
        ],
      ),
    );
  }
}
