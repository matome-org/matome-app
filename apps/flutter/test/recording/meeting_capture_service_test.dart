import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/recording_drafts_dao.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:matome_flutter/features/recording/meeting_capture_finish.dart';
import 'package:matome_flutter/features/recording/meeting_capture_service.dart';

class _FakeMeetingBackend implements MeetingCaptureBackend {
  _FakeMeetingBackend({
    this.onStart,
    this.onStop,
    this.onCancel,
    this.capability = const MeetingCaptureCapability.supported(
      backendId: 'fake',
    ),
    this.permission = MeetingCapturePermission.granted,
  });

  final Future<void> Function(MeetingCaptureRequest request)? onStart;
  final Future<MeetingCaptureCandidate> Function()? onStop;
  final Future<void> Function()? onCancel;
  final MeetingCaptureCapability capability;
  final MeetingCapturePermission permission;
  final eventsController = StreamController<MeetingCaptureEvent>.broadcast();
  MeetingCaptureRequest? request;
  bool cancelCalled = false;
  int cancelCalls = 0;
  bool disposeCalled = false;

  @override
  String get backendId => 'fake';

  @override
  Stream<MeetingCaptureEvent> get events => eventsController.stream;

  @override
  Future<MeetingCaptureCapability> probe() async => capability;

  @override
  Future<MeetingCapturePermission> requestPermission() async => permission;

  @override
  Future<void> start(MeetingCaptureRequest value) async {
    request = value;
    await onStart?.call(value);
    await File(value.stagingPath).writeAsBytes(List<int>.filled(4096, 7));
  }

  @override
  Future<MeetingCaptureCandidate> stop() async =>
      onStop?.call() ?? MeetingCaptureCandidate(path: request!.stagingPath);

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    cancelCalls += 1;
    await onCancel?.call();
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
    await eventsController.close();
  }
}

void main() {
  late Directory temp;
  late AppDatabase db;

  setUp(() async {
    final rawTemp = await Directory.systemTemp.createTemp(
      'meeting_capture_service_',
    );
    temp = Directory(await rawTemp.resolveSymbolicLinks());
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  MeetingArtifactInspector inspector({bool decodable = true}) {
    return (path) async => MeetingArtifactFacts(
      decodable: decodable,
      container: MeetingContainer.m4a,
      codec: MeetingAudioCodec.aacLc,
      sampleRate: 48000,
      channels: 1,
      duration: const Duration(seconds: 12),
      byteSize: await File(path).length(),
    );
  }

  MeetingCaptureService makeService(
    _FakeMeetingBackend backend, {
    MeetingArtifactInspector? artifactInspector,
    Future<int?> Function(String path)? availableBytes,
    Future<Directory> Function()? storageDirectory,
    Duration operationTimeout = const Duration(milliseconds: 100),
  }) {
    return MeetingCaptureService(
      draftsDao: db.recordingDraftsDao,
      backend: backend,
      storageDirectory: storageDirectory ?? () async => temp,
      inspectArtifact: artifactInspector ?? inspector(),
      availableBytes: availableBytes ?? (_) async => 1 << 30,
      minimumAvailableBytes: 4096,
      heartbeatInterval: const Duration(milliseconds: 10),
      operationTimeout: operationTimeout,
    );
  }

  test('persists a typed meeting draft before native capture starts', () async {
    late _FakeMeetingBackend backend;
    backend = _FakeMeetingBackend(
      onStart: (request) async {
        final draft = await db.recordingDraftsDao.loadDraft(
          captureKind: RecordingCaptureKind.meeting,
        );
        expect(draft, isNotNull);
        expect(draft!.sessionId, request.sessionId);
        expect(draft.backend, 'fake');
        expect(draft.codec, 'aac_lc');
        expect(draft.state, RecordingDraftState.starting);
        expect(draft.stagingHandle, request.stagingPath.split('/').last);
        expect(request.mix.microphoneGainDb, -6);
        expect(request.mix.systemGainDb, -6);
        expect(request.mix.limiterCeilingDb, -1);
      },
    );
    final service = makeService(backend);

    await service.start();

    final draft = await db.recordingDraftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    expect(draft?.state, RecordingDraftState.recording);
    expect(draft?.heartbeatAt, isNotNull);
    await service.cancel();
    await service.dispose();
  });

  test(
    'validates then atomically publishes exactly one final artifact',
    () async {
      final backend = _FakeMeetingBackend();
      final service = makeService(backend);
      await service.start();
      final staging = backend.request!.stagingPath;

      final artifact = await service.stop();

      expect(artifact.path, endsWith('.m4a'));
      expect(artifact.path, isNot(staging));
      expect(await File(artifact.path).exists(), isTrue);
      expect(await File(staging).exists(), isFalse);
      expect(temp.listSync().whereType<File>().map((file) => file.path), [
        artifact.path,
      ]);
      final draft = await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      );
      expect(draft?.state, RecordingDraftState.completed);
      expect(draft?.segmentHandles, [artifact.path.split('/').last]);

      await service.acknowledgePersisted(artifact.sessionId);
      expect(
        await db.recordingDraftsDao.loadDraft(
          captureKind: RecordingCaptureKind.meeting,
        ),
        isNull,
      );
      await service.dispose();
    },
  );

  test('failed validation retains one recoverable staging artifact', () async {
    final backend = _FakeMeetingBackend();
    final service = makeService(
      backend,
      artifactInspector: inspector(decodable: false),
    );
    await service.start();
    final staging = backend.request!.stagingPath;

    await expectLater(
      service.stop(),
      throwsA(isA<MeetingArtifactInvalidError>()),
    );

    expect(await File(staging).exists(), isTrue);
    expect(temp.listSync().whereType<File>(), hasLength(1));
    final draft = await db.recordingDraftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    expect(draft?.state, RecordingDraftState.failed);
    expect(draft?.segmentHandles, [staging.split('/').last]);
    await service.dispose();
  });

  test('cancel removes owned partials and only the meeting draft', () async {
    await db.recordingDraftsDao.saveDraft(['/mic.m4a'], 1000);
    final backend = _FakeMeetingBackend();
    final service = makeService(backend);
    await service.start();
    final staging = backend.request!.stagingPath;

    await service.cancel();

    expect(backend.cancelCalled, isTrue);
    expect(await File(staging).exists(), isFalse);
    expect(
      await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      ),
      isNull,
    );
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull);
    await service.dispose();
  });

  test(
    'refuses capture before backend start when provider quota is exhausted',
    () async {
      final backend = _FakeMeetingBackend();
      final service = makeService(backend, availableBytes: (_) async => 0);

      await expectLater(
        service.start(),
        throwsA(isA<MeetingStorageLowError>()),
      );

      expect(backend.request, isNull);
      expect(
        await db.recordingDraftsDao.loadDraft(
          captureKind: RecordingCaptureKind.meeting,
        ),
        isNull,
      );
      await service.dispose();
    },
  );

  test('refuses unsupported capability before creating a draft', () async {
    final backend = _FakeMeetingBackend(
      capability: const MeetingCaptureCapability.unsupported(
        backendId: 'fake',
        reason: 'no loopback source',
      ),
    );
    final service = makeService(backend);

    await expectLater(
      service.start(),
      throwsA(isA<MeetingCaptureUnsupportedError>()),
    );

    expect(backend.request, isNull);
    expect(
      await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      ),
      isNull,
    );
    await service.dispose();
  });

  test('refuses denied permission before creating a draft', () async {
    final backend = _FakeMeetingBackend(
      permission: MeetingCapturePermission.denied,
    );
    final service = makeService(backend);

    await expectLater(
      service.start(),
      throwsA(isA<MeetingCapturePermissionError>()),
    );

    expect(backend.request, isNull);
    expect(
      await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      ),
      isNull,
    );
    await service.dispose();
  });

  test(
    'heartbeat persists elapsed duration while capture remains local',
    () async {
      final backend = _FakeMeetingBackend();
      final service = makeService(backend);
      await service.start();

      await Future<void>.delayed(const Duration(milliseconds: 35));

      final draft = await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      );
      expect(draft?.durationMs, greaterThan(0));
      expect(draft?.state, RecordingDraftState.recording);
      await service.cancel();
      await service.dispose();
    },
  );

  test(
    'heartbeat cancels and removes owned bytes when provider quota drops',
    () async {
      var probes = 0;
      final backend = _FakeMeetingBackend();
      final service = makeService(
        backend,
        availableBytes: (_) async => probes++ == 0 ? 1 << 30 : 0,
      );
      await service.start();
      final staging = backend.request!.stagingPath;

      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(service.state, MeetingCaptureState.cancelled);
      expect(backend.cancelCalled, isTrue);
      expect(await File(staging).exists(), isFalse);
      expect(
        await db.recordingDraftsDao.loadDraft(
          captureKind: RecordingCaptureKind.meeting,
        ),
        isNull,
      );
      await service.dispose();
    },
  );

  test('a hung heartbeat capacity probe cannot pin cancellation', () async {
    final never = Completer<int?>();
    var probes = 0;
    final backend = _FakeMeetingBackend();
    final service = makeService(
      backend,
      availableBytes: (_) =>
          probes++ == 0 ? Future<int?>.value(1 << 30) : never.future,
    );
    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await service.cancel().timeout(const Duration(milliseconds: 300));

    expect(service.state, MeetingCaptureState.cancelled);
    expect(backend.cancelCalled, isTrue);
    await service.dispose();
  });

  test(
    'forwards source levels and unavailable events from the backend',
    () async {
      final backend = _FakeMeetingBackend();
      final service = makeService(backend);
      final events = <MeetingCaptureEvent>[];
      final subscription = service.events.listen(events.add);

      backend.eventsController.add(
        const MeetingCaptureEvent.level(
          source: MeetingCaptureSource.microphone,
          levelDb: -18,
        ),
      );
      backend.eventsController.add(
        const MeetingCaptureEvent.unavailable(
          source: MeetingCaptureSource.system,
          message: 'device lost',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.map((event) => event.levelDb), contains(-18));
      expect(events.map((event) => event.message), contains('device lost'));
      await subscription.cancel();
      await service.dispose();
    },
  );

  test('device loss moves the durable lifecycle to failed', () async {
    final backend = _FakeMeetingBackend();
    final service = makeService(backend);
    await service.start();
    final staging = backend.request!.stagingPath;

    backend.eventsController.add(
      const MeetingCaptureEvent.unavailable(
        source: MeetingCaptureSource.system,
        message: 'device lost',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.state, MeetingCaptureState.failed);
    expect(backend.cancelCalled, isTrue);
    expect(await File(staging).exists(), isTrue);
    final draft = await db.recordingDraftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    expect(draft?.state, RecordingDraftState.failed);
    await service.dispose();
  });

  test(
    'recovers a valid killed-session artifact and publishes it once',
    () async {
      final staging = File('${temp.path}/meeting_recovery.partial.m4a');
      await staging.writeAsBytes(List<int>.filled(4096, 3));
      await db.recordingDraftsDao.saveTypedDraft(
        RecordingDraft(
          segmentHandles: ['meeting_recovery.partial.m4a'],
          durationMs: 5000,
          sessionId: 'meeting_recovery',
          captureKind: RecordingCaptureKind.meeting,
          backend: 'fake',
          stagingHandle: 'meeting_recovery.partial.m4a',
          codec: 'aac_lc',
          state: RecordingDraftState.recording,
          heartbeatAt: DateTime.now().toUtc(),
        ),
      );
      final service = makeService(_FakeMeetingBackend());

      final recovered = await service.recover();

      expect(recovered, isNotNull);
      expect(recovered!.path, '${temp.path}/meeting_recovery.m4a');
      expect(await staging.exists(), isFalse);
      expect(await File(recovered.path).exists(), isTrue);
      expect(temp.listSync().whereType<File>(), hasLength(1));
      await service.dispose();
    },
  );

  test('safely discards an invalid owned artifact during recovery', () async {
    final staging = File('${temp.path}/meeting_invalid.partial.m4a');
    await staging.writeAsBytes(List<int>.filled(32, 3));
    await db.recordingDraftsDao.saveTypedDraft(
      RecordingDraft(
        segmentHandles: ['meeting_invalid.partial.m4a'],
        durationMs: 100,
        sessionId: 'meeting_invalid',
        captureKind: RecordingCaptureKind.meeting,
        backend: 'fake',
        stagingHandle: 'meeting_invalid.partial.m4a',
        codec: 'aac_lc',
        state: RecordingDraftState.failed,
      ),
    );
    final service = makeService(
      _FakeMeetingBackend(),
      artifactInspector: inspector(decodable: false),
    );

    expect(await service.recover(), isNull);

    expect(await staging.exists(), isFalse);
    expect(
      await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      ),
      isNull,
    );
    await service.dispose();
  });

  test(
    'recovery falls back to staging when the final artifact is corrupt',
    () async {
      final staging = File('${temp.path}/meeting_fallback.partial.m4a');
      final finalFile = File('${temp.path}/meeting_fallback.m4a');
      await staging.writeAsBytes(List<int>.filled(4096, 4));
      await finalFile.writeAsBytes(List<int>.filled(32, 9));
      await db.recordingDraftsDao.saveTypedDraft(
        RecordingDraft(
          segmentHandles: [
            'meeting_fallback.partial.m4a',
            'meeting_fallback.m4a',
          ],
          durationMs: 1000,
          sessionId: 'meeting_fallback',
          captureKind: RecordingCaptureKind.meeting,
          backend: 'fake',
          stagingHandle: 'meeting_fallback.partial.m4a',
          codec: 'aac_lc',
          state: RecordingDraftState.failed,
        ),
      );
      final service = makeService(
        _FakeMeetingBackend(),
        artifactInspector: (path) async {
          final bytes = await File(path).length();
          return MeetingArtifactFacts(
            decodable: bytes >= 4096,
            container: MeetingContainer.m4a,
            codec: MeetingAudioCodec.aacLc,
            sampleRate: 48000,
            channels: 1,
            duration: const Duration(seconds: 2),
            byteSize: bytes,
          );
        },
      );

      final recovered = await service.recover();

      expect(recovered?.path, finalFile.path);
      expect(await finalFile.length(), 4096);
      expect(await staging.exists(), isFalse);
      await service.dispose();
    },
  );

  test('idle cancel cannot orphan a persisted recovery draft', () async {
    final staging = File('${temp.path}/meeting_idle.partial.m4a');
    await staging.writeAsBytes(List<int>.filled(4096, 1));
    await db.recordingDraftsDao.saveTypedDraft(
      RecordingDraft(
        segmentHandles: ['meeting_idle.partial.m4a'],
        durationMs: 1000,
        sessionId: 'meeting_idle',
        captureKind: RecordingCaptureKind.meeting,
        backend: 'fake',
        stagingHandle: 'meeting_idle.partial.m4a',
        codec: 'aac_lc',
        state: RecordingDraftState.failed,
      ),
    );
    final service = makeService(_FakeMeetingBackend());

    await expectLater(service.cancel(), throwsStateError);

    expect(await staging.exists(), isTrue);
    expect(
      await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      ),
      isNotNull,
    );
    await service.dispose();
  });

  test(
    'path traversal in persisted ownership metadata is never deleted',
    () async {
      final outside = File('${temp.parent.path}/meeting_outside.m4a');
      await outside.writeAsBytes(List<int>.filled(4096, 1));
      addTearDown(
        () =>
            outside.exists().then((exists) => exists ? outside.delete() : null),
      );
      await db.recordingDraftsDao.saveTypedDraft(
        RecordingDraft(
          segmentHandles: ['meeting_outside.m4a'],
          durationMs: 1000,
          sessionId: '../meeting_outside',
          captureKind: RecordingCaptureKind.meeting,
          backend: 'fake',
          stagingHandle: 'meeting_outside.m4a',
          codec: 'aac_lc',
          state: RecordingDraftState.failed,
        ),
      );
      final service = makeService(_FakeMeetingBackend());

      expect(await service.recover(), isNull);

      expect(await outside.exists(), isTrue);
      await service.dispose();
    },
  );

  test('refuses a symlinked storage root before creating a draft', () async {
    final outside = await Directory.systemTemp.createTemp(
      'meeting_capture_outside_',
    );
    final link = Link('${temp.path}_link');
    await link.create(outside.path);
    addTearDown(() async {
      if (await link.exists()) await link.delete();
      if (await outside.exists()) await outside.delete(recursive: true);
    });
    final backend = _FakeMeetingBackend();
    final service = makeService(
      backend,
      storageDirectory: () async => Directory(link.path),
    );

    await expectLater(
      service.start(),
      throwsA(isA<MeetingStorageUnsafeError>()),
    );

    expect(backend.request, isNull);
    expect(
      await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      ),
      isNull,
    );
    await service.dispose();
  });

  test('cancel timeout retains the recovery anchor and owned bytes', () async {
    final never = Completer<void>();
    final backend = _FakeMeetingBackend(onCancel: () => never.future);
    final service = makeService(backend);
    await service.start();
    final staging = backend.request!.stagingPath;

    await expectLater(
      service.cancel(),
      throwsA(
        isA<MeetingCaptureTimeoutError>().having(
          (error) => error.operation,
          'operation',
          'cancel',
        ),
      ),
    );

    expect(await File(staging).exists(), isTrue);
    final draft = await db.recordingDraftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    expect(draft?.state, RecordingDraftState.failed);
    await service.dispose();
  });

  test(
    'finisher commits only after validation and schedules upload afterward',
    () async {
      final backend = _FakeMeetingBackend();
      final service = makeService(backend);
      final order = <String>[];
      final finisher = MeetingCaptureFinisher(
        service: service,
        persist: (artifact, {title}) async {
          order.add('persist:${await File(artifact.path).exists()}');
          return 'local-1';
        },
        scheduleUpload: (localId) => order.add('upload:$localId'),
      );
      await service.start();
      expect(
        order,
        isEmpty,
        reason: 'capture has no persistence or network edge',
      );

      final localId = await finisher.finish(title: 'Meeting');

      expect(localId, 'local-1');
      expect(order, ['persist:true', 'upload:local-1']);
      expect(
        await db.recordingDraftsDao.loadDraft(
          captureKind: RecordingCaptureKind.meeting,
        ),
        isNull,
      );
      await service.dispose();
    },
  );

  test(
    'finisher revalidates bytes immediately before local persistence',
    () async {
      var inspections = 0;
      var persisted = false;
      final backend = _FakeMeetingBackend();
      final service = makeService(
        backend,
        artifactInspector: (path) async {
          inspections += 1;
          return MeetingArtifactFacts(
            decodable: inspections <= 2,
            container: MeetingContainer.m4a,
            codec: MeetingAudioCodec.aacLc,
            sampleRate: 48000,
            channels: 1,
            duration: const Duration(seconds: 1),
            byteSize: await File(path).length(),
          );
        },
      );
      final finisher = MeetingCaptureFinisher(
        service: service,
        persist: (artifact, {title}) async {
          persisted = true;
          return 'local';
        },
        scheduleUpload: (_) {},
      );
      await service.start();

      await expectLater(
        finisher.finish(),
        throwsA(isA<MeetingArtifactInvalidError>()),
      );

      expect(persisted, isFalse);
      final draft = await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      );
      expect(draft?.state, RecordingDraftState.completed);
      await service.dispose();
    },
  );

  test(
    'failed local commit keeps completed draft and never schedules upload',
    () async {
      final backend = _FakeMeetingBackend();
      final service = makeService(backend);
      var uploadScheduled = false;
      final finisher = MeetingCaptureFinisher(
        service: service,
        persist: (artifact, {title}) async => throw StateError('db failed'),
        scheduleUpload: (_) => uploadScheduled = true,
      );
      await service.start();

      await expectLater(finisher.finish(), throwsStateError);

      expect(uploadScheduled, isFalse);
      final draft = await db.recordingDraftsDao.loadDraft(
        captureKind: RecordingCaptureKind.meeting,
      );
      expect(draft?.state, RecordingDraftState.completed);
      expect(
        await File('${temp.path}/${draft!.sessionId}.m4a').exists(),
        isTrue,
      );
      await service.dispose();
    },
  );

  test('stop and cancel cannot enter the backend concurrently', () async {
    final stop = Completer<MeetingCaptureCandidate>();
    final backend = _FakeMeetingBackend(onStop: () => stop.future);
    final service = makeService(backend);
    await service.start();

    final stopping = service.stop();
    await Future<void>.delayed(Duration.zero);
    await expectLater(service.cancel(), throwsStateError);
    stop.complete(MeetingCaptureCandidate(path: backend.request!.stagingPath));

    expect(await stopping, isA<MeetingCaptureArtifact>());
    expect(backend.cancelCalled, isFalse);
    await service.dispose();
  });

  test(
    'recovery derives a safe final destination instead of trusting the draft',
    () async {
      final staging = File('${temp.path}/meeting_safe.partial.m4a');
      final outside = File(
        '${temp.parent.path}/meeting_unsafe_destination.m4a',
      );
      await staging.writeAsBytes(List<int>.filled(4096, 1));
      addTearDown(
        () =>
            outside.exists().then((exists) => exists ? outside.delete() : null),
      );
      await db.recordingDraftsDao.saveTypedDraft(
        RecordingDraft(
          segmentHandles: ['meeting_safe.partial.m4a'],
          durationMs: 1000,
          sessionId: 'meeting_safe',
          captureKind: RecordingCaptureKind.meeting,
          backend: 'fake',
          stagingHandle: 'meeting_safe.partial.m4a',
          codec: 'aac_lc',
          state: RecordingDraftState.failed,
        ),
      );
      final service = makeService(_FakeMeetingBackend());

      final recovered = await service.recover();

      expect(recovered?.path, '${temp.path}/meeting_safe.m4a');
      expect(await outside.exists(), isFalse);
      await service.dispose();
    },
  );

  test(
    'transient inspection failure can retry recovery on the same service',
    () async {
      final staging = File('${temp.path}/meeting_retry.partial.m4a');
      await staging.writeAsBytes(List<int>.filled(4096, 1));
      await db.recordingDraftsDao.saveTypedDraft(
        RecordingDraft(
          segmentHandles: ['meeting_retry.partial.m4a'],
          durationMs: 1000,
          sessionId: 'meeting_retry',
          captureKind: RecordingCaptureKind.meeting,
          backend: 'fake',
          stagingHandle: 'meeting_retry.partial.m4a',
          codec: 'aac_lc',
          state: RecordingDraftState.failed,
        ),
      );
      var inspections = 0;
      final service = makeService(
        _FakeMeetingBackend(),
        artifactInspector: (path) async {
          inspections += 1;
          if (inspections == 1) throw FileSystemException('temporarily locked');
          return MeetingArtifactFacts(
            decodable: true,
            container: MeetingContainer.m4a,
            codec: MeetingAudioCodec.aacLc,
            sampleRate: 48000,
            channels: 1,
            duration: const Duration(seconds: 1),
            byteSize: await File(path).length(),
          );
        },
      );

      expect(await service.recover(), isNull);
      final recovered = await service.recover();

      expect(recovered?.path, '${temp.path}/meeting_retry.m4a');
      await service.dispose();
    },
  );

  test('stop is bounded and retains the partial for recovery', () async {
    final never = Completer<MeetingCaptureCandidate>();
    final backend = _FakeMeetingBackend(onStop: () => never.future);
    final service = makeService(backend);
    await service.start();
    final staging = backend.request!.stagingPath;

    await expectLater(
      service.stop(),
      throwsA(
        isA<MeetingCaptureTimeoutError>().having(
          (error) => error.operation,
          'operation',
          'stop',
        ),
      ),
    );

    expect(await File(staging).exists(), isTrue);
    final draft = await db.recordingDraftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    expect(draft?.state, RecordingDraftState.failed);
    await service.dispose();
  });

  test(
    'a delayed start is cancelled again if it completes after timeout',
    () async {
      final start = Completer<void>();
      final backend = _FakeMeetingBackend(onStart: (_) => start.future);
      final service = makeService(backend);

      await expectLater(
        service.start(),
        throwsA(
          isA<MeetingCaptureTimeoutError>().having(
            (error) => error.operation,
            'operation',
            'start',
          ),
        ),
      );
      expect(backend.cancelCalls, 1);

      start.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(backend.cancelCalls, 2);
      await service.dispose();
    },
  );

  test(
    'accepts a long generated artifact after independent decode',
    () async {
      late _FakeMeetingBackend backend;
      backend = _FakeMeetingBackend(
        onStop: () async {
          final path = backend.request!.stagingPath;
          final generated = await Process.run('ffmpeg', [
            '-hide_banner',
            '-loglevel',
            'error',
            '-f',
            'lavfi',
            '-i',
            'anullsrc=r=48000:cl=mono',
            '-t',
            '3600',
            '-c:a',
            'aac',
            '-profile:a',
            'aac_low',
            '-b:a',
            '96k',
            '-movflags',
            '+faststart',
            '-y',
            path,
          ]);
          expect(generated.exitCode, 0, reason: generated.stderr as String?);
          return MeetingCaptureCandidate(path: path);
        },
      );
      final service = makeService(
        backend,
        operationTimeout: const Duration(seconds: 30),
        artifactInspector: (path) async {
          final probe = await Process.run('ffprobe', [
            '-v',
            'error',
            '-show_entries',
            'format=duration,size:stream=codec_name,profile,sample_rate,channels',
            '-of',
            'json',
            path,
          ]);
          expect(probe.exitCode, 0, reason: probe.stderr as String?);
          final decoded = jsonDecode(probe.stdout as String);
          final stream = (decoded['streams'] as List).single as Map;
          final format = decoded['format'] as Map;
          final decode = await Process.run('ffmpeg', [
            '-v',
            'error',
            '-i',
            path,
            '-f',
            'null',
            '-',
          ]);
          return MeetingArtifactFacts(
            decodable: decode.exitCode == 0,
            container: MeetingContainer.m4a,
            codec: stream['codec_name'] == 'aac' && stream['profile'] == 'LC'
                ? MeetingAudioCodec.aacLc
                : throw StateError('Unexpected codec: $stream'),
            sampleRate: int.parse(stream['sample_rate'] as String),
            channels: stream['channels'] as int,
            duration: Duration(
              milliseconds: (double.parse(format['duration'] as String) * 1000)
                  .round(),
            ),
            byteSize: int.parse(format['size'] as String),
          );
        },
      );
      await service.start();

      final artifact = await service.stop();

      expect(artifact.facts.duration, const Duration(hours: 1));
      expect(artifact.facts.decodable, isTrue);
      await service.dispose();
    },
    tags: 'linux_host',
  );

  test('rejects inspector metadata whose size differs from the file', () async {
    final backend = _FakeMeetingBackend();
    final service = makeService(
      backend,
      artifactInspector: (path) async => const MeetingArtifactFacts(
        decodable: true,
        container: MeetingContainer.m4a,
        codec: MeetingAudioCodec.aacLc,
        sampleRate: 48000,
        channels: 1,
        duration: Duration(seconds: 1),
        byteSize: 1,
      ),
    );
    await service.start();

    await expectLater(
      service.stop(),
      throwsA(isA<MeetingArtifactInvalidError>()),
    );
    await service.dispose();
  });
}
