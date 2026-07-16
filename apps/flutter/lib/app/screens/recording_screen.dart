import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/recording/audio_recording_service.dart';
import '../../features/recording/meeting_recorder.dart';
import '../../features/recording/recording_controller.dart';
import '../../features/recording/recording_finish.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/avatar.dart';
import '../../ui/loading_indicator.dart';

/// Which recorder a [RecordingScreen] drives. The default mic recorder, or the
/// desktop **meeting** recorder (loopback + mic mixed via ffmpeg). Both share
/// the entire modal UI + the F4 finalize/upload pipeline; only the backing
/// providers differ, so the meeting flow is a thin variant rather than a fork.
class RecorderBinding {
  const RecorderBinding({
    required this.serviceProvider,
    required this.controllerProvider,
    required this.finisherProvider,
    this.titleLabel,
    this.unsupportedReason,
    this.supportsPause = true,
  });

  final Provider<AudioRecordingService> serviceProvider;
  final StateNotifierProvider<RecordingController, RecordingState>
  controllerProvider;
  final Provider<RecordingFinisher> finisherProvider;

  /// Whether this recorder supports mid-stream pause/resume. The meeting backend
  /// is single-pass (ffmpeg capture) and `pause()` throws, so the meeting modal
  /// must NOT offer pause — its primary button finishes instead (audit #828
  /// warning #2). The mic backend supports pause, so it keeps the full controls.
  final bool supportsPause;

  /// Optional header label override (e.g. "Record meeting"); null falls back to
  /// the mic recorder copy.
  final String? titleLabel;

  /// Optional host-specific reason capture is unavailable, shown on the
  /// unsupported screen instead of the generic mic copy. Resolved against the
  /// [WidgetRef] so it can probe the host (e.g. ffmpeg/monitor missing).
  final Future<String?> Function(WidgetRef ref)? unsupportedReason;

  /// Default mic recorder binding.
  static final mic = RecorderBinding(
    serviceProvider: audioRecordingServiceProvider,
    controllerProvider: recordingControllerProvider,
    finisherProvider: recordingFinisherProvider,
  );

  /// Desktop meeting recorder binding — loopback (system output) + mic mixed
  /// into one WAV via ffmpeg, then through the same F4 upload pipeline. The
  /// unsupported reason probes the host so off-Linux / missing-ffmpeg hosts get
  /// a precise message instead of the generic mic copy.
  static final meeting = RecorderBinding(
    serviceProvider: meetingRecordingServiceProvider,
    controllerProvider: meetingRecordingControllerProvider,
    finisherProvider: meetingRecordingFinisherProvider,
    titleLabel: 'Record meeting',
    unsupportedReason: (ref) =>
        ref.read(meetingCaptureCapabilityProvider).unsupportedReason(),
    // Single-pass ffmpeg capture has no lossless pause — the meeting modal hides
    // pause and makes its primary button finish straight through.
    supportsPause: false,
  );
}

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
  RecordingScreen({super.key, RecorderBinding? binding})
    : binding = binding ?? RecorderBinding.mic;

  /// Which recorder backs this modal (mic by default; the meeting recorder for
  /// the `/meeting` route).
  final RecorderBinding binding;

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  _ModalPhase _phase = _ModalPhase.draftCheck;
  RecordingDraftDetection? _detection;

  /// Host-specific unsupported reason (meeting binding), null → generic copy.
  String? _unsupportedReason;

  // Provider triplet for whichever recorder backs this modal (mic / meeting).
  Provider<AudioRecordingService> get _serviceProvider =>
      widget.binding.serviceProvider;
  StateNotifierProvider<RecordingController, RecordingState>
  get _controllerProvider => widget.binding.controllerProvider;
  Provider<RecordingFinisher> get _finisherProvider =>
      widget.binding.finisherProvider;

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
    final service = ref.read(_serviceProvider);
    final supported = await service.isCaptureSupported();
    if (!mounted) return;
    if (!supported) {
      final reasonResolver = widget.binding.unsupportedReason;
      final reason = reasonResolver != null ? await reasonResolver(ref) : null;
      if (!mounted) return;
      setState(() {
        _unsupportedReason = reason;
        _phase = _ModalPhase.unsupported;
      });
      return;
    }

    final controller = ref.read(_controllerProvider.notifier);
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
    _ampListener = ref.listenManual<RecordingState>(_controllerProvider, (
      prev,
      next,
    ) {
      if (next.phase != RecordingPhase.recording) return;
      if (prev != null && prev.amplitude == next.amplitude) return;
      const minDb = -60.0;
      const maxDb = 0.0;
      var normalized = (next.amplitude - minDb) / (maxDb - minDb);
      normalized = normalized.clamp(0.0, 1.0);
      final target = normalized * 40 + 5;
      final next0 = target > _lastHeight
          ? target
          : _lastHeight * 0.7 + target * 0.3;
      _lastHeight = next0 < 5 ? 5 : next0;
      _bars
        ..removeAt(0)
        ..add(_lastHeight);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
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
      await ref.read(_controllerProvider.notifier).start();
      if (mounted) setState(() => _phase = _ModalPhase.recording);
    } catch (_) {
      _snack(t.recording.startFailed);
    }
  }

  Future<void> _pause() async {
    try {
      await ref.read(_controllerProvider.notifier).pause();
      if (mounted) setState(() => _phase = _ModalPhase.paused);
    } catch (_) {
      _snack(t.recording.pauseFailed);
    }
  }

  Future<void> _resume() async {
    try {
      await ref.read(_controllerProvider.notifier).resume();
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
      await ref.read(_controllerProvider.notifier).resumeFromDraft(detection);
      if (mounted) setState(() => _phase = _ModalPhase.recording);
    } catch (_) {
      _snack(t.recording.resumeFailed);
      if (mounted) setState(() => _phase = _ModalPhase.idle);
    }
  }

  /// Close-while-capturing. If there is in-progress audio (recording/paused),
  /// confirm first so a stray tap on the X never silently throws away a take.
  /// From idle (no segments yet) there's nothing to lose — close straight away.
  Future<void> _discard() async {
    final hasAudio =
        _phase == _ModalPhase.recording || _phase == _ModalPhase.paused;
    if (hasAudio) {
      final confirmed = await _confirmDiscard();
      if (!confirmed || !mounted) return;
    }
    await ref.read(_controllerProvider.notifier).discard();
    _resetBars();
    if (mounted) _close();
  }

  /// Confirmation before discarding an unsaved in-progress recording.
  Future<bool> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(t.recording.discardConfirmTitle),
        content: Text(t.recording.discardConfirmBody),
        actions: [
          AppTextButton(
            key: const Key('discard-keep-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.recording.discardConfirmKeep),
          ),
          PrimaryButton(
            key: const Key('discard-confirm-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.recording.discardConfirmDiscard),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Draft prompt → Discard: clear segments + draft, then a fresh idle screen.
  Future<void> _draftDiscard() async {
    await ref.read(_controllerProvider.notifier).discard();
    _detection = null;
    _resetBars();
    if (mounted) setState(() => _phase = _ModalPhase.idle);
  }

  Future<void> _finish() async {
    setState(() => _phase = _ModalPhase.processing);
    // Kick the durable upload pipeline off the widget's lifecycle. The local
    // row appears immediately, and the queue runs until Core accepts processing.
    final finishing = ref.read(_finisherProvider).finish();
    try {
      await finishing;
      if (mounted) _close();
    } catch (_) {
      // If the modal was backgrounded the failure surfaces on the Inbox card
      // (InboxUploader persists `failed`); only revert/notify when still shown.
      if (mounted) {
        _snack(t.recording.saveFailed);
        setState(() => _phase = _ModalPhase.paused);
      }
    }
  }

  /// Processing → "Continue in Inbox": dismiss the modal while the upload keeps
  /// running in the background. Core processing continues independently after
  /// the device queue records the accepted run.
  void _backgroundToInbox() {
    if (context.canPop()) context.pop();
    context.go('/inbox');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- render ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_controllerProvider);
    final spacing = context.spacing;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_phase != _ModalPhase.processing &&
                _phase != _ModalPhase.draftCheck)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(spacing.xs),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: t.common.cancel,
                    onPressed:
                        _phase == _ModalPhase.draftPrompt ||
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
        final isProcessing = _phase == _ModalPhase.processing;
        return _ProcessingView(
          label: isProcessing ? t.recording.processing : t.recording.loading,
          // Only the terminal upload phase offers the background hand-off; the
          // draftCheck probe is a sub-second mic/draft check.
          onBackground: isProcessing ? _backgroundToInbox : null,
        );
      case _ModalPhase.unsupported:
        return _UnsupportedView(onClose: _close, reason: _unsupportedReason);
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
          idleLabel: widget.binding.titleLabel,
          supportsPause: widget.binding.supportsPause,
          onStart: _start,
          onPause: _pause,
          onResume: _resume,
          onFinish: _finish,
        );
    }
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.label, this.onBackground});
  final String label;

  /// When non-null, renders a "Continue in Inbox" affordance so the user can
  /// dismiss the modal and let the upload finish in the background.
  final VoidCallback? onBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LoadingIndicator(),
          SizedBox(height: spacing.md + spacing.xxs),
          Text(label, style: theme.textTheme.titleMedium),
          if (onBackground != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              t.recording.processingHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: spacing.md + spacing.xxs),
            OutlinedButton(
              key: const Key('processing-background-button'),
              onPressed: onBackground,
              child: Text(t.recording.processingBackground),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.onClose, this.reason});
  final VoidCallback onClose;

  /// Host-specific reason (meeting recorder); null → generic mic copy.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(
            size: spacing.xxl + spacing.xxl,
            backgroundColor: colors.accentSoft,
            child: Icon(
              Icons.mic_off,
              size: spacing.xl + spacing.sm,
              color: colors.accentDark,
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            t.recording.unsupportedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            reason ?? t.recording.unsupportedHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          PrimaryButton(onPressed: onClose, child: Text(t.common.cancel)),
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
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(
            size: spacing.xxl + spacing.xxl,
            backgroundColor: colors.accentSoft,
            child: Icon(
              Icons.mic,
              size: spacing.xl + spacing.sm,
              color: colors.accentDark,
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            t.recording.draftFound,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            t.recording.draftHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (durationSeconds > 0) ...[
            SizedBox(height: spacing.md),
            Text(
              AudioRecordingService.formatDuration(durationSeconds),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('draft-discard-button'),
                  onPressed: onDiscard,
                  child: Text(t.recording.draftDiscard),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: PrimaryButton(
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
    this.idleLabel,
    this.supportsPause = true,
  });

  final _ModalPhase phase;
  final double durationSeconds;
  final List<double> bars;

  /// Header label shown in the idle/ready state (e.g. "Record meeting"); null
  /// falls back to the generic mic-recorder ready copy.
  final String? idleLabel;

  /// Whether the backing recorder supports pause/resume. When false (meeting),
  /// the primary button finishes while recording (never maps to the throwing
  /// `pause()`), and the secondary pause control is hidden.
  final bool supportsPause;
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
        return idleLabel ?? t.recording.ready;
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
    final colors = context.colors;
    final spacing = context.spacing;
    final barRadius = context.radius.sm / 4;
    final primaryColor = _isRecording ? colors.failed : colors.accent;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            _hintLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            AudioRecordingService.formatDuration(durationSeconds),
            key: const Key('recording-timer'),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            height: spacing.xxl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing.xxs),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: spacing.xxs,
                    height: bars[i],
                    decoration: BoxDecoration(
                      color: _isRecording ? colors.accent : colors.border,
                      borderRadius: BorderRadius.circular(barRadius),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: spacing.xl),
          // Primary circular button. With pause support: record→pause→resume.
          // Without (meeting): the primary button finishes straight through
          // while recording — it must NEVER map to the throwing `pause()`
          // (audit #828 warning #2).
          GestureDetector(
            key: const Key('record-primary-button'),
            onTap: _isRecording
                ? (supportsPause ? onPause : onFinish)
                : _isPaused
                ? onResume
                : onStart,
            child: Container(
              width: spacing.xxl + spacing.xxl,
              height: spacing.xxl + spacing.xxl,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Icon(
                  _isRecording
                      ? (supportsPause ? Icons.pause : Icons.stop)
                      : Icons.mic,
                  size: spacing.xl + spacing.xs,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          SizedBox(height: spacing.xl),
          if (_isRecording || _isPaused)
            Row(
              children: [
                // Secondary pause/resume controls only exist for backends that
                // support pause — hidden entirely for the meeting binding.
                if (supportsPause && _isRecording)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('pause-button'),
                      onPressed: onPause,
                      child: Text(t.recording.pause),
                    ),
                  ),
                if (supportsPause && _isPaused)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('resume-button'),
                      onPressed: onResume,
                      child: Text(t.recording.resume),
                    ),
                  ),
                if (supportsPause) SizedBox(width: spacing.sm),
                Expanded(
                  child: PrimaryButton(
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
