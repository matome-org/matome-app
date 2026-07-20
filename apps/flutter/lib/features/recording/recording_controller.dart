import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../core/db/daos/recording_drafts_dao.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import 'audio_recording_service.dart';

/// Recorder lifecycle phase exposed to the UI (S3 recording modal). Mirrors the
/// implicit idle/recording/paused state machine the RN recording screen drove.
enum RecordingPhase { idle, recording, paused, finished }

/// Immutable snapshot of the recorder for the waveform + timer UI.
class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.durationSeconds = 0,
    this.amplitude = -160,
    this.error,
    this.hasRecoverableDraft = false,
  });

  /// Current lifecycle phase.
  final RecordingPhase phase;

  /// Accumulated duration in seconds (held across pause).
  final double durationSeconds;

  /// Latest amplitude (dBFS, -160..0) for the waveform.
  final double amplitude;

  /// Last error message, if any (e.g. unsupported platform / denied permission).
  final String? error;

  /// True when a crash-recovery draft was detected at startup (S3 shows the
  /// resume/discard prompt).
  final bool hasRecoverableDraft;

  RecordingState copyWith({
    RecordingPhase? phase,
    double? durationSeconds,
    double? amplitude,
    Object? error = _noChange,
    bool? hasRecoverableDraft,
  }) {
    return RecordingState(
      phase: phase ?? this.phase,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      amplitude: amplitude ?? this.amplitude,
      error: identical(error, _noChange) ? this.error : error as String?,
      hasRecoverableDraft: hasRecoverableDraft ?? this.hasRecoverableDraft,
    );
  }

  static const _noChange = Object();
}

/// Drives [AudioRecordingService] and projects it into [RecordingState] for the
/// S3 modal. Subscribes to the amplitude + state streams while active.
class RecordingController extends StateNotifier<RecordingState> {
  RecordingController(this._service) : super(const RecordingState());

  final AudioRecordingService _service;

  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<RecordState>? _stateSub;
  Timer? _tick;

  /// Probe for an existing draft at startup. Mirrors the RN NavigationGuard
  /// draft-detection on app open. Sets [RecordingState.hasRecoverableDraft].
  Future<RecordingDraftDetection> detectDraft() async {
    final draft = await _service.detectRecoverableDraft();
    state = state.copyWith(hasRecoverableDraft: draft != null);
    AppLog.event(LogCat.action, 'detectDraft: recoverable=${draft != null}');
    return RecordingDraftDetection(draft: draft);
  }

  Future<void> start() async {
    try {
      await _service.startRecording();
      _subscribe();
      state = state.copyWith(
        phase: RecordingPhase.recording,
        durationSeconds: 0,
        error: null,
      );
      AppLog.event(LogCat.action, 'start: recording started');
    } catch (e, st) {
      AppLog.error(LogCat.error, 'start: startRecording failed', e, st);
      state = state.copyWith(phase: RecordingPhase.idle, error: e.toString());
      rethrow;
    }
  }

  Future<void> pause() async {
    await _service.pauseRecording();
    _ampSub?.pause();
    state = state.copyWith(
      phase: RecordingPhase.paused,
      durationSeconds: _service.recordingDurationSeconds,
    );
    AppLog.event(LogCat.action, 'pause: recording paused');
  }

  Future<void> resume() async {
    await _service.resumeRecording();
    _ampSub?.resume();
    state = state.copyWith(phase: RecordingPhase.recording);
    AppLog.event(LogCat.action, 'resume: recording resumed');
  }

  /// Resume a recovered draft and continue recording the same session.
  Future<void> resumeFromDraft(RecordingDraftDetection detection) async {
    final draft = detection.draft;
    if (draft == null) return;
    await _service.resumeFromDraft(draft);
    await _service.startRecording();
    await _service.resumeFromDraft(draft);
    _subscribe();
    state = state.copyWith(
      phase: RecordingPhase.recording,
      durationSeconds: draft.durationMs / 1000.0,
      hasRecoverableDraft: false,
    );
    AppLog.event(
      LogCat.action,
      'resumeFromDraft: resumed ${draft.segmentHandles.length} segment(s)',
    );
  }

  /// Finalize the session → returns the single resolved audio file path.
  Future<String> finish() async {
    _teardownStreams();
    if (_service.isRecorderActive) {
      await _service.stopRecording();
    }
    final path = await _service.mergeSegments();
    state = state.copyWith(
      phase: RecordingPhase.finished,
      durationSeconds: await _service.getAudioDurationSeconds(path),
    );
    AppLog.event(LogCat.action, 'finish: session finalized');
    return path;
  }

  /// Discard everything (files + draft) and reset to idle.
  Future<void> discard() async {
    _teardownStreams();
    await _service.cancelRecording();
    state = const RecordingState();
    AppLog.event(LogCat.action, 'discard: session discarded + reset');
  }

  void _subscribe() {
    _teardownStreams();
    _ampSub = _service.amplitudeStream().listen((amp) {
      state = state.copyWith(amplitude: amp.current);
    });
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (state.phase == RecordingPhase.recording) {
        state = state.copyWith(
          durationSeconds: _service.recordingDurationSeconds,
        );
      }
    });
  }

  void _teardownStreams() {
    _ampSub?.cancel();
    _ampSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    _teardownStreams();
    super.dispose();
  }
}

/// Result of a draft-detection probe — null draft means no recoverable session.
class RecordingDraftDetection {
  const RecordingDraftDetection({required this.draft});
  final RecordingDraft? draft;
}

/// The audio recording service, wired to the F2 Drift drafts DAO.
final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService(
    draftsDao: ref.watch(recordingDraftsDaoProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Recorder state for the S3 modal.
final recordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>((ref) {
      return RecordingController(ref.watch(audioRecordingServiceProvider));
    });
