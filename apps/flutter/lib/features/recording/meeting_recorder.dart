import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'audio_recording_service.dart';
import 'meeting_loopback_source.dart';
import 'meeting_recorder_backend.dart';
import 'recording_controller.dart';

/// Per-platform capability gate for the **desktop meeting recorder** (loopback
/// + mic). Deliberately mirrors the molde of
/// [AudioRecordingService.isCaptureSupported] / [AudioCaptureUnsupportedError]
/// for the mic-only path, but the meeting gate is *stricter*: it also requires
/// a usable system-output loopback tap (PipeWire/Pulse `.monitor`) + ffmpeg.
///
/// Greenfield experiment — there is no SaaS feature-flag service, so this is a
/// local capability gate. On an unsupported host the meeting-recorder entry
/// must disable with the human-readable [unsupportedReason].
class MeetingCaptureCapability {
  const MeetingCaptureCapability({MeetingLoopbackSource? loopback})
    : _loopback = loopback ?? const MeetingLoopbackSource();

  final MeetingLoopbackSource _loopback;

  /// Whether this host can capture a meeting (Linux + ffmpeg + pactl + a
  /// resolvable monitor source). False on Windows/macOS (out of MVP scope) and
  /// on a Linux box missing ffmpeg or any output monitor.
  Future<bool> isSupported() => _loopback.isSupported();

  /// A precise, user-facing reason capture is unavailable (or null when it IS
  /// available) — drives the disabled-entry copy. Probes the host so the reason
  /// names the actual missing piece rather than a generic "unsupported".
  Future<String?> unsupportedReason() async {
    if (!await _loopback.hasFfmpeg()) {
      // ffmpeg also implies "not Linux" indirectly, but be explicit about the
      // dependency first since it's the most actionable fix.
      final isLinuxLike = await _loopback.hasPactl();
      if (!isLinuxLike) {
        return 'Meeting recording is currently Linux-only.';
      }
      return 'ffmpeg is required to record meetings. Install ffmpeg and retry.';
    }
    if (!await _loopback.hasPactl()) {
      return 'Meeting recording is currently Linux-only (PipeWire/PulseAudio).';
    }
    if (await _loopback.resolveMonitorSource() == null) {
      return 'No system-output device found to capture meeting audio.';
    }
    return null;
  }
}

/// Loopback source resolver (default sink `.monitor`), shared by the capability
/// gate and the ffmpeg backend.
final meetingLoopbackSourceProvider = Provider<MeetingLoopbackSource>(
  (ref) => const MeetingLoopbackSource(),
);

/// Capability gate for the meeting-recorder UI entry.
final meetingCaptureCapabilityProvider = Provider<MeetingCaptureCapability>(
  (ref) => MeetingCaptureCapability(
    loopback: ref.watch(meetingLoopbackSourceProvider),
  ),
);

/// Meeting-configured [AudioRecordingService]: same single-file model + F4
/// upload reuse as the mic recorder, but driven by the ffmpeg loopback backend
/// and writing `wav` segments (so the uploaded file is a valid meeting WAV).
final meetingRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService(
    draftsDao: ref.watch(recordingDraftsDaoProvider),
    recorder: MeetingRecorderBackend(
      loopback: ref.watch(meetingLoopbackSourceProvider),
    ),
    segmentExtension: 'wav',
    // The meeting capability gate is loopback-aware; reuse it as the service's
    // capture-support probe so start() degrades with the same molde.
    captureSupportedProbe: () =>
        ref.read(meetingCaptureCapabilityProvider).isSupported(),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Recorder state for the meeting modal — drives the same [RecordingController]
/// UI as the mic recorder, but over the meeting (loopback) service.
final meetingRecordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>((ref) {
      return RecordingController(ref.watch(meetingRecordingServiceProvider));
    });
