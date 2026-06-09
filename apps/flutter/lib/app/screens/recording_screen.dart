import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/recording/audio_recording_service.dart';
import '../../features/recording/recording_controller.dart';
import '../../features/recording/recording_finish.dart';
import '../../i18n/strings.g.dart';

/// Number of waveform bars driven by the F3 amplitude stream.
const int _waveformBars = 20;

/// UI-level phase wrapping F3's recorder phase. F3's [RecordingController] only
/// models idle/recording/paused/finished; the modal adds the entry
/// (draftCheck / draftPrompt), the terminal `processing` (upload in flight) and
/// the `unsupported` (no mic on this host) states — mirroring apps/mobile
/// `RecordingScreen`'s draft_check / draft_prompt / idle / recording / paused /
/// processing machine.
enum _ModalPhase {
  draftCheck,
  draftPrompt,
  idle,
  recording,
  paused,
  processing,
  unsupported,
}

/// Recording capture screen, presented as a fullscreen modal (route
/// `/recording`, pushed from the center mic FAB). Mirrors apps/mobile
/// `app/recording.tsx`: large duration timer, a 20-bar waveform driven by the
/// F3 amplitude stream, record/pause/resume/finish buttons, a crash-recovery
/// draft prompt on entry, and a graceful unsupported-mic state.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  _ModalPhase _phase = _ModalPhase.draftCheck;
  RecordingDraftDetection? _detection;

  /// Rolling 20-value waveform buffer, smoothed like apps/mobile (fast attack,
  /// slow decay). Heights are in logical px (5..45).
  final List<double> _bars = List<double>.filled(_waveformBars, 5);
  double _lastHeight = 5;
  ProviderSubscription<RecordingState>? _ampListener;

  @override
  void initState() {
    super.initState();
    // Defer to after first frame so provider reads happen off the build path.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _ampListener?.close();
    super.dispose();
  }

  /// Entry: probe mic support, then detect a crash-recovery draft (F3).
  Future<void> _bootstrap() async {
    final service = ref.read(audioRecordingServiceProvider);
    final supported = await service.isCaptureSupported();
    if (!mounted) return;
    if (!supported) {
      setState(() => _phase = _ModalPhase.unsupported);
      return;
    }

    final controller = ref.read(recordingControllerProvider.notifier);
    try {
      final detection = await controller.detectDraft();
      if (!mounted) return;
      if (detection.draft != null) {
        _detection = detection;
        setState(() => _phase = _ModalPhase.draftPrompt);
      } else {
        setState(() => _phase = _ModalPhase.idle);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _ModalPhase.idle);
    }
    _subscribeWaveform();
  }

  /// Drive the 20-bar waveform off the controller's amplitude stream while
  /// recording. Mirrors apps/mobile's normalize + fast-attack/slow-decay.
  ///
  /// Only reacts to genuine amplitude deltas (not phase/duration changes), and
  /// defers the rebuild to a post-frame callback so it never calls setState in
  /// the middle of a StateNotifier emission (which would otherwise throw
  /// "setState during build" / stream-conflict during a phase transition).
  void _subscribeWaveform() {
    _ampListener?.close();
    _ampListener = ref.listenManual<RecordingState>(
      recordingControllerProvider,
      (prev, next) {
        if (next.phase != RecordingPhase.recording) return;
        if (prev != null && prev.amplitude == next.amplitude) return;
        const minDb = -60.0;
        const maxDb = 0.0;
        var normalized = (next.amplitude - minDb) / (maxDb - minDb);
        normalized = normalized.clamp(0.0, 1.0);
        final target = normalized * 40 + 5;
        final next0 =
            target > _lastHeight ? target : _lastHeight * 0.7 + target * 0.3;
        _lastHeight = next0 < 5 ? 5 : next0;
        _bars
          ..removeAt(0)
          ..add(_lastHeight);
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      },
    );
  }

  void _resetBars() {
    _lastHeight = 5;
    for (var i = 0; i < _bars.length; i++) {
      _bars[i] = 5;
    }
  }

  // --- actions --------------------------------------------------------------

  Future<void> _start() async {
    try {
      await ref.read(recordingControllerProvider.notifier).start();
      if (mounted) setState(() => _phase = _ModalPhase.recording);
    } catch (_) {
      _snack(t.recording.startFailed);
    }
  }

  Future<void> _pause() async {
    try {
      await ref.read(recordingControllerProvider.notifier).pause();
      if (mounted) setState(() => _phase = _ModalPhase.paused);
    } catch (_) {
      _snack(t.recording.pauseFailed);
    }
  }

  Future<void> _resume() async {
    try {
      await ref.read(recordingControllerProvider.notifier).resume();
      if (mounted) setState(() => _phase = _ModalPhase.recording);
    } catch (_) {
      _snack(t.recording.resumeFailed);
    }
  }

  Future<void> _draftResume() async {
    final detection = _detection;
    if (detection == null) {
      setState(() => _phase = _ModalPhase.idle);
      return;
    }
    try {
      await ref
          .read(recordingControllerProvider.notifier)
          .resumeFromDraft(detection);
      if (mounted) setState(() => _phase = _ModalPhase.recording);
    } catch (_) {
      _snack(t.recording.resumeFailed);
      if (mounted) setState(() => _phase = _ModalPhase.idle);
    }
  }

  Future<void> _discard() async {
    await ref.read(recordingControllerProvider.notifier).discard();
    _resetBars();
    if (mounted) _close();
  }

  /// Draft prompt → Discard: clear segments + draft, then a fresh idle screen.
  Future<void> _draftDiscard() async {
    await ref.read(recordingControllerProvider.notifier).discard();
    _detection = null;
    _resetBars();
    if (mounted) setState(() => _phase = _ModalPhase.idle);
  }

  Future<void> _finish() async {
    setState(() => _phase = _ModalPhase.processing);
    try {
      await ref.read(recordingFinisherProvider).finish();
      if (mounted) _close();
    } catch (_) {
      _snack(t.recording.saveFailed);
      if (mounted) setState(() => _phase = _ModalPhase.paused);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/inbox');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- render ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_phase != _ModalPhase.processing &&
                _phase != _ModalPhase.draftCheck)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: t.common.cancel,
                    onPressed: _phase == _ModalPhase.draftPrompt ||
                            _phase == _ModalPhase.unsupported
                        ? _close
                        : _discard,
                  ),
                ),
              ),
            Center(child: _body(state)),
          ],
        ),
      ),
    );
  }

  Widget _body(RecordingState state) {
    switch (_phase) {
      case _ModalPhase.draftCheck:
      case _ModalPhase.processing:
        return _ProcessingView(
          label: _phase == _ModalPhase.draftCheck
              ? t.recording.loading
              : t.recording.processing,
        );
      case _ModalPhase.unsupported:
        return _UnsupportedView(onClose: _close);
      case _ModalPhase.draftPrompt:
        return _DraftPromptView(
          durationSeconds: state.durationSeconds,
          onResume: _draftResume,
          onDiscard: _draftDiscard,
        );
      case _ModalPhase.idle:
      case _ModalPhase.recording:
      case _ModalPhase.paused:
        return _ActiveView(
          phase: _phase,
          durationSeconds: state.durationSeconds,
          bars: _bars,
          onStart: _start,
          onPause: _pause,
          onResume: _resume,
          onFinish: _finish,
        );
    }
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.accentSoft,
            child: const Icon(Icons.mic_off, size: 44, color: AppColors.accentDark),
          ),
          const SizedBox(height: 24),
          Text(
            t.recording.unsupportedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            t.recording.unsupportedHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onClose, child: Text(t.common.cancel)),
        ],
      ),
    );
  }
}

class _DraftPromptView extends StatelessWidget {
  const _DraftPromptView({
    required this.durationSeconds,
    required this.onResume,
    required this.onDiscard,
  });

  final double durationSeconds;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.accentSoft,
            child: const Icon(Icons.mic, size: 44, color: AppColors.accentDark),
          ),
          const SizedBox(height: 24),
          Text(
            t.recording.draftFound,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            t.recording.draftHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (durationSeconds > 0) ...[
            const SizedBox(height: 16),
            Text(
              AudioRecordingService.formatDuration(durationSeconds),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('draft-discard-button'),
                  onPressed: onDiscard,
                  child: Text(t.recording.draftDiscard),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('draft-resume-button'),
                  onPressed: onResume,
                  child: Text(t.recording.draftResume),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    required this.phase,
    required this.durationSeconds,
    required this.bars,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final _ModalPhase phase;
  final double durationSeconds;
  final List<double> bars;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  bool get _isRecording => phase == _ModalPhase.recording;
  bool get _isPaused => phase == _ModalPhase.paused;

  String get _statusLabel {
    switch (phase) {
      case _ModalPhase.recording:
        return t.recording.title;
      case _ModalPhase.paused:
        return t.recording.paused;
      default:
        return t.recording.ready;
    }
  }

  String get _hintLabel {
    switch (phase) {
      case _ModalPhase.recording:
        return t.recording.stopHint;
      case _ModalPhase.paused:
        return t.recording.resumeHint;
      default:
        return t.recording.startHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = _isRecording ? AppColors.failed : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _hintLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            AudioRecordingService.formatDuration(durationSeconds),
            key: const Key('recording-timer'),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 4,
                    height: bars[i],
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.accent
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Primary circular record/pause/resume button.
          GestureDetector(
            key: const Key('record-primary-button'),
            onTap: _isRecording
                ? onPause
                : _isPaused
                    ? onResume
                    : onStart,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Icon(
                  _isRecording ? Icons.pause : Icons.mic,
                  size: 40,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_isRecording || _isPaused)
            Row(
              children: [
                if (_isRecording)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('pause-button'),
                      onPressed: onPause,
                      child: Text(t.recording.pause),
                    ),
                  ),
                if (_isPaused)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('resume-button'),
                      onPressed: onResume,
                      child: Text(t.recording.resume),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('finish-button'),
                    onPressed: onFinish,
                    child: Text(t.recording.finish),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
