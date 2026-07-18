// Private-field named constructor params can't be initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/services.dart';

import 'meeting_capture_backend.dart';

/// Shared MethodChannel/EventChannel backend for native meeting-capture
/// implementations (Windows/macOS). It is platform-neutral Dart — the OS-specific
/// work lives behind the channel in the native plugin (C++/Swift). Linux does not
/// use this (it has its own dart:io process backend), so on Linux this class is
/// simply never instantiated.
///
/// Protocol (see the native plugins):
/// - Method channel [_defaultMethodChannel] `matome.meeting_capture/methods`:
///   `probe`, `requestPermission`, `start`, `stop`, `cancel`, `dispose`, `inspect`.
/// - Event channel `matome.meeting_capture/events/<sessionId>` streams broadcast
///   maps that map to [MeetingCaptureEvent].
const MethodChannel _defaultMethodChannel = MethodChannel(
  'matome.meeting_capture/methods',
);

const String _defaultEventChannelPrefix = 'matome.meeting_capture/events/';

typedef EventChannelFactory = EventChannel Function(String name);

class MethodChannelMeetingCaptureBackend implements MeetingCaptureBackend {
  MethodChannelMeetingCaptureBackend({
    required String backendId,
    MethodChannel methods = _defaultMethodChannel,
    String eventChannelPrefix = _defaultEventChannelPrefix,
    EventChannelFactory eventChannelFactory = EventChannel.new,
  }) : _backendId = backendId,
       _methods = methods,
       _eventChannelPrefix = eventChannelPrefix,
       _eventChannelFactory = eventChannelFactory;

  final String _backendId;
  final MethodChannel _methods;
  final String _eventChannelPrefix;
  final EventChannelFactory _eventChannelFactory;

  final StreamController<MeetingCaptureEvent> _events =
      StreamController<MeetingCaptureEvent>.broadcast();
  StreamSubscription<dynamic>? _eventSub;
  String? _sessionId;
  bool _disposed = false;

  @override
  String get backendId => _backendId;

  @override
  Stream<MeetingCaptureEvent> get events => _events.stream;

  @override
  Future<MeetingCaptureCapability> probe() async {
    final result = await _methods.invokeMapMethod<String, Object?>('probe');
    final map = result ?? const <String, Object?>{};
    final supported = map['supported'] == true;
    final backendId = (map['backendId'] as String?) ?? _backendId;
    if (supported) {
      return MeetingCaptureCapability.supported(backendId: backendId);
    }
    return MeetingCaptureCapability.unsupported(
      backendId: backendId,
      reason: (map['reason'] as String?) ?? 'unsupported',
    );
  }

  @override
  Future<MeetingCapturePermission> requestPermission() async {
    final result = await _methods.invokeMapMethod<String, Object?>(
      'requestPermission',
    );
    return _permissionFromWire((result ?? const {})['permission'] as String?);
  }

  @override
  Future<void> start(MeetingCaptureRequest request) async {
    if (_disposed) throw StateError('Meeting backend is disposed');
    if (_sessionId != null) {
      throw StateError('Meeting capture is already active');
    }
    // Subscribe BEFORE start so no early level/state event is missed.
    final channel = _eventChannelFactory(
      '$_eventChannelPrefix${request.sessionId}',
    );
    _eventSub = channel.receiveBroadcastStream().listen(
      _forwardEvent,
      onError: (Object error, StackTrace _) =>
          _events.add(MeetingCaptureEvent.failed(message: '$error')),
    );
    _sessionId = request.sessionId;
    try {
      await _methods.invokeMethod<void>('start', _encodeRequest(request));
    } on PlatformException catch (error) {
      await _teardownSession();
      if (error.code == 'unsupported') {
        throw MeetingCaptureUnsupportedError(error.message ?? 'unsupported');
      }
      rethrow;
    }
  }

  @override
  Future<MeetingCaptureCandidate> stop() async {
    final sessionId = _sessionId;
    if (sessionId == null) throw StateError('No meeting capture is active');
    final result = await _methods.invokeMapMethod<String, Object?>('stop', {
      'sessionId': sessionId,
    });
    await _teardownSession();
    final path = (result ?? const {})['path'] as String?;
    if (path == null) {
      throw const MeetingArtifactInvalidError('native stop returned no path');
    }
    return MeetingCaptureCandidate(path: path);
  }

  @override
  Future<void> cancel() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      await _methods.invokeMethod<void>('cancel', {'sessionId': sessionId});
      await _teardownSession();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final sessionId = _sessionId;
    if (sessionId != null) {
      await _methods.invokeMethod<void>('dispose', {'sessionId': sessionId});
    }
    await _teardownSession();
    await _events.close();
  }

  Future<void> _teardownSession() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _sessionId = null;
  }

  void _forwardEvent(dynamic raw) {
    if (raw is! Map) return;
    final map = raw.cast<Object?, Object?>();
    switch (map['type']) {
      case 'state':
        final state = _stateFromWire(map['state'] as String?);
        if (state != null) _events.add(MeetingCaptureEvent.state(state));
      case 'level':
        final source = _sourceFromWire(map['source'] as String?);
        final level = (map['levelDb'] as num?)?.toDouble();
        if (source != null && level != null) {
          _events.add(
            MeetingCaptureEvent.level(source: source, levelDb: level),
          );
        }
      case 'unavailable':
        final source = _sourceFromWire(map['source'] as String?);
        if (source != null) {
          _events.add(
            MeetingCaptureEvent.unavailable(
              source: source,
              message: (map['message'] as String?) ?? 'unavailable',
            ),
          );
        }
      case 'failed':
        _events.add(
          MeetingCaptureEvent.failed(
            message: (map['message'] as String?) ?? 'failed',
          ),
        );
    }
  }

  Map<String, Object?> _encodeRequest(MeetingCaptureRequest request) => {
    'sessionId': request.sessionId,
    'stagingPath': request.stagingPath,
    'codec': request.codec.wireName,
    'container': request.container.extension,
    'sampleRate': request.sampleRate,
    'channels': request.channels,
    'bitrate': request.bitrate,
    'micGainDb': request.mix.microphoneGainDb,
    'systemGainDb': request.mix.systemGainDb,
    'limiterCeilingDb': request.mix.limiterCeilingDb,
  };
}

/// Builds a channel-backed [MeetingArtifactInspector] that asks the native side
/// to validate the recorded artifact (Media Foundation on Windows, AVFoundation
/// on macOS) and returns typed facts.
MeetingArtifactInspector channelMeetingArtifactInspector({
  MethodChannel methods = _defaultMethodChannel,
}) {
  return (String path) async {
    final result = await methods.invokeMapMethod<String, Object?>('inspect', {
      'path': path,
    });
    if (result == null) {
      throw const MeetingArtifactInvalidError('native inspect returned null');
    }
    return MeetingArtifactFacts(
      decodable: result['decodable'] == true,
      container: MeetingContainer.m4a,
      codec: MeetingAudioCodec.aacLc,
      sampleRate: (result['sampleRate'] as num).toInt(),
      channels: (result['channels'] as num).toInt(),
      duration: Duration(microseconds: (result['durationUs'] as num).toInt()),
      byteSize: (result['byteSize'] as num).toInt(),
    );
  };
}

MeetingCapturePermission _permissionFromWire(String? wire) => switch (wire) {
  'granted' => MeetingCapturePermission.granted,
  'restricted' => MeetingCapturePermission.restricted,
  _ => MeetingCapturePermission.denied,
};

MeetingCaptureSource? _sourceFromWire(String? wire) => switch (wire) {
  'system' => MeetingCaptureSource.system,
  'microphone' => MeetingCaptureSource.microphone,
  _ => null,
};

MeetingCaptureState? _stateFromWire(String? wire) {
  for (final state in MeetingCaptureState.values) {
    if (state.name == wire) return state;
  }
  return null;
}
