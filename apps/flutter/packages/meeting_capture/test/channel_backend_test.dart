import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_capture/meeting_capture.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  const methodChannel = MethodChannel('matome.meeting_capture/methods');
  final calls = <MethodCall>[];
  final responses = <String, Object?>{};

  setUp(() {
    calls.clear();
    responses
      ..clear()
      ..addAll(<String, Object?>{
        'probe': {'supported': true, 'backendId': 'test-native'},
        'requestPermission': {'permission': 'granted'},
        'start': null,
        'stop': {'path': '/tmp/meeting.m4a'},
        'cancel': null,
        'dispose': null,
        'inspect': {
          'decodable': true,
          'sampleRate': 48000,
          'channels': 1,
          'durationUs': 1200000000,
          'byteSize': 14680064,
        },
      });
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return responses[call.method];
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(methodChannel, null));

  MethodChannelMeetingCaptureBackend backend() =>
      MethodChannelMeetingCaptureBackend(backendId: 'test-native');

  test('probe maps a supported response', () async {
    final capability = await backend().probe();
    expect(capability.supported, isTrue);
    expect(capability.backendId, 'test-native');
    expect(calls.single.method, 'probe');
  });

  test('probe maps an unsupported response with a reason', () async {
    responses['probe'] = {
      'supported': false,
      'backendId': 'test-native',
      'reason': 'permission-denied',
    };
    final capability = await backend().probe();
    expect(capability.supported, isFalse);
    expect(capability.reason, 'permission-denied');
  });

  test('requestPermission maps the wire value', () async {
    responses['requestPermission'] = {'permission': 'restricted'};
    expect(
      await backend().requestPermission(),
      MeetingCapturePermission.restricted,
    );
  });

  test('start serializes the request onto the method channel', () async {
    await backend().start(
      const MeetingCaptureRequest(
        sessionId: 'sess-1',
        stagingPath: '/tmp/sess-1.m4a',
        sampleRate: 48000,
        channels: 1,
        bitrate: 96000,
      ),
    );
    final start = calls.firstWhere((c) => c.method == 'start');
    final args = (start.arguments as Map).cast<String, Object?>();
    expect(args['sessionId'], 'sess-1');
    expect(args['stagingPath'], '/tmp/sess-1.m4a');
    expect(args['codec'], 'aac_lc');
    expect(args['container'], 'm4a');
    expect(args['sampleRate'], 48000);
    expect(args['bitrate'], 96000);
    expect(args['micGainDb'], -6);
    expect(args['systemGainDb'], -6);
    expect(args['limiterCeilingDb'], -1);
  });

  test('start maps a PlatformException("unsupported") to the typed error',
      () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'start') {
        throw PlatformException(code: 'unsupported', message: 'no-loopback');
      }
      return responses[call.method];
    });
    expect(
      () => backend().start(
        const MeetingCaptureRequest(
          sessionId: 'sess-x',
          stagingPath: '/tmp/x.m4a',
        ),
      ),
      throwsA(isA<MeetingCaptureUnsupportedError>()),
    );
  });

  test('event-channel payloads map to MeetingCaptureEvent', () async {
    late MockStreamHandlerEventSink sink;
    final eventChannel = EventChannel('matome.meeting_capture/events/sess-2');
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) => sink = events,
      ),
    );
    addTearDown(() => messenger.setMockStreamHandler(eventChannel, null));

    final b = backend();
    final received = <MeetingCaptureEvent>[];
    b.events.listen(received.add);

    await b.start(
      const MeetingCaptureRequest(
        sessionId: 'sess-2',
        stagingPath: '/tmp/sess-2.m4a',
      ),
    );
    await pumpEventQueue();

    sink.success({'type': 'state', 'state': 'recording'});
    sink.success({'type': 'level', 'source': 'system', 'levelDb': -18.0});
    sink.success({
      'type': 'unavailable',
      'source': 'microphone',
      'message': 'microphone-device-lost',
    });
    sink.success({'type': 'failed', 'message': 'ffmpeg-exited:1'});
    await pumpEventQueue();

    expect(received, hasLength(4));
    expect(received[0].state, MeetingCaptureState.recording);
    expect(received[1].source, MeetingCaptureSource.system);
    expect(received[1].levelDb, -18.0);
    expect(received[2].state, MeetingCaptureState.unavailable);
    expect(received[2].source, MeetingCaptureSource.microphone);
    expect(received[3].state, MeetingCaptureState.failed);
    expect(received[3].message, 'ffmpeg-exited:1');

    await b.dispose();
  });

  test('stop returns the native artifact path', () async {
    final b = backend();
    await b.start(
      const MeetingCaptureRequest(
        sessionId: 'sess-3',
        stagingPath: '/tmp/sess-3.m4a',
      ),
    );
    final candidate = await b.stop();
    expect(candidate.path, '/tmp/meeting.m4a');
    final stop = calls.firstWhere((c) => c.method == 'stop');
    expect((stop.arguments as Map)['sessionId'], 'sess-3');
  });

  test('channelMeetingArtifactInspector builds typed facts', () async {
    final inspect = channelMeetingArtifactInspector(methods: methodChannel);
    final facts = await inspect('/tmp/meeting.m4a');
    expect(facts.decodable, isTrue);
    expect(facts.container, MeetingContainer.m4a);
    expect(facts.codec, MeetingAudioCodec.aacLc);
    expect(facts.sampleRate, 48000);
    expect(facts.channels, 1);
    expect(facts.duration, const Duration(microseconds: 1200000000));
    expect(facts.byteSize, 14680064);
    expect(calls.single.method, 'inspect');
  });
}
