import 'package:record/record.dart';

/// Thin abstraction over the native `record` [AudioRecorder] so the
/// [AudioRecordingService] can be unit-tested with a fake backend (no live mic,
/// no platform channels). The production implementation [RecordRecorderBackend]
/// is a straight 1:1 delegate.
///
/// Only the surface the service actually drives is exposed.
abstract class RecorderBackend {
  Future<bool> hasPermission();

  /// Start recording to [path] (single continuous file for the session).
  Future<void> start(String path, {AudioEncoder encoder});

  /// Pause — keeps the same underlying file open for [resume].
  Future<void> pause();

  /// Resume — continues appending to the SAME file.
  Future<void> resume();

  /// Stop and finalize; returns the output path (or null on backends that
  /// echo the requested path).
  Future<String?> stop();

  /// Cancel and discard the in-progress recording.
  Future<void> cancel();

  /// Amplitude (dBFS) stream for the waveform.
  Stream<Amplitude> onAmplitudeChanged(Duration interval);

  /// Recorder state (record / pause / stop) stream.
  Stream<RecordState> onStateChanged();

  /// Release native resources.
  Future<void> dispose();
}

/// Production backend — delegates straight to `record`'s [AudioRecorder].
class RecordRecorderBackend implements RecorderBackend {
  RecordRecorderBackend([AudioRecorder? recorder])
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path,
      {AudioEncoder encoder = AudioEncoder.aacLc}) {
    return _recorder.start(RecordConfig(encoder: encoder), path: path);
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      _recorder.onAmplitudeChanged(interval);

  @override
  Stream<RecordState> onStateChanged() => _recorder.onStateChanged();

  @override
  Future<void> dispose() => _recorder.dispose();
}
