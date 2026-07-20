/// Package-neutral contract for capturing microphone and system audio on one
/// timeline. Platform implementations own native readiness and shutdown.
abstract interface class MeetingCaptureBackend {
  String get backendId;

  Stream<MeetingCaptureEvent> get events;

  Future<MeetingCaptureCapability> probe();

  Future<MeetingCapturePermission> requestPermission();

  Future<void> start(MeetingCaptureRequest request);

  Future<MeetingCaptureCandidate> stop();

  /// Must complete only after every producer and capture pipe has terminated.
  /// A caller timeout means termination is unknown and owned files must remain
  /// recoverable rather than being deleted.
  Future<void> cancel();

  /// Must obey the same producer-termination guarantee as [cancel].
  Future<void> dispose();
}

class MeetingCaptureCapability {
  const MeetingCaptureCapability.supported({required this.backendId})
    : supported = true,
      reason = null;

  const MeetingCaptureCapability.unsupported({
    required this.backendId,
    required this.reason,
  }) : supported = false;

  final String backendId;
  final bool supported;
  final String? reason;
}

enum MeetingCapturePermission { granted, denied, restricted }

enum MeetingCaptureState {
  idle,
  starting,
  recording,
  finalizing,
  completed,
  cancelled,
  unavailable,
  failed,
}

enum MeetingCaptureSource { microphone, system }

enum MeetingAudioCodec {
  aacLc('aac_lc');

  const MeetingAudioCodec(this.wireName);
  final String wireName;
}

enum MeetingContainer {
  m4a('m4a');

  const MeetingContainer(this.extension);
  final String extension;
}

class MeetingCaptureMix {
  const MeetingCaptureMix({
    this.microphoneGainDb = -6,
    this.systemGainDb = -6,
    this.limiterCeilingDb = -1,
  });

  final double microphoneGainDb;
  final double systemGainDb;
  final double limiterCeilingDb;
}

class MeetingCaptureRequest {
  const MeetingCaptureRequest({
    required this.sessionId,
    required this.stagingPath,
    this.codec = MeetingAudioCodec.aacLc,
    this.container = MeetingContainer.m4a,
    this.sampleRate = 48000,
    this.channels = 1,
    this.bitrate = 96000,
    this.mix = const MeetingCaptureMix(),
  });

  final String sessionId;
  final String stagingPath;
  final MeetingAudioCodec codec;
  final MeetingContainer container;
  final int sampleRate;
  final int channels;
  final int bitrate;
  final MeetingCaptureMix mix;
}

class MeetingCaptureCandidate {
  const MeetingCaptureCandidate({required this.path});
  final String path;
}

class MeetingCaptureEvent {
  const MeetingCaptureEvent.state(this.state)
    : source = null,
      levelDb = null,
      message = null;

  const MeetingCaptureEvent.level({required this.source, required this.levelDb})
    : state = null,
      message = null;

  const MeetingCaptureEvent.unavailable({
    required this.source,
    required this.message,
  }) : state = MeetingCaptureState.unavailable,
       levelDb = null;

  const MeetingCaptureEvent.failed({required this.message})
    : state = MeetingCaptureState.failed,
      source = null,
      levelDb = null;

  final MeetingCaptureState? state;
  final MeetingCaptureSource? source;
  final double? levelDb;
  final String? message;
}

class MeetingArtifactFacts {
  const MeetingArtifactFacts({
    required this.decodable,
    required this.container,
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.duration,
    required this.byteSize,
  });

  final bool decodable;
  final MeetingContainer container;
  final MeetingAudioCodec codec;
  final int sampleRate;
  final int channels;
  final Duration duration;
  final int byteSize;
}

class MeetingCaptureArtifact {
  const MeetingCaptureArtifact({
    required this.sessionId,
    required this.path,
    required this.facts,
  });

  final String sessionId;
  final String path;
  final MeetingArtifactFacts facts;
}

typedef MeetingArtifactInspector =
    Future<MeetingArtifactFacts> Function(String path);

class MeetingCaptureUnsupportedError implements Exception {
  const MeetingCaptureUnsupportedError(this.reason);
  final String reason;
}

class MeetingCapturePermissionError implements Exception {
  const MeetingCapturePermissionError(this.permission);
  final MeetingCapturePermission permission;
}

class MeetingCaptureTimeoutError implements Exception {
  const MeetingCaptureTimeoutError(this.operation);
  final String operation;
}

class MeetingArtifactInvalidError implements Exception {
  const MeetingArtifactInvalidError(this.reason);
  final String reason;
}

class MeetingStorageLowError implements Exception {
  const MeetingStorageLowError();
}

class MeetingStorageUnsafeError implements Exception {
  const MeetingStorageUnsafeError(this.reason);
  final String reason;
}
