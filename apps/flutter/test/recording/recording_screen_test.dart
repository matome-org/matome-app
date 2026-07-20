import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:matome_flutter/app/screens/recording_screen.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:record/record.dart' show Amplitude, AudioEncoder, RecordState;

import 'audio_recording_service_test.dart' show FakeRecorderBackend;
import '../support/fake_parent_sync.dart';
import '../support/verified_upload_repository_fake.dart';
import '../support/fake_media_blob_store.dart';

/// A [FakeRecorderBackend] for widget tests that emits NO stream events. The
/// production fake's `Stream.periodic` amplitude + broadcast state controller
/// fire under the widget tester's FakeAsync zone, causing a setState storm
/// (pumpAndSettle never settles) and a "Cannot add event while adding stream"
/// race on teardown. Here the lifecycle still writes/reads the single-file
/// audio (so finish resolves a real file) but never touches a StreamController.
/// The state machine + finish flow run unchanged; only the cosmetic waveform is
/// suppressed.
class SilentRecorderBackend extends FakeRecorderBackend {
  @override
  Future<void> start(
    String p, {
    AudioEncoder encoder = AudioEncoder.aacLc,
  }) async {
    path = p;
    started = true;
    paused = false;
    recordSpans = 1;
    await File(p).writeAsBytes(List.filled(1000, 1));
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> resume() async {
    paused = false;
    recordSpans += 1;
    final f = File(path!);
    final existing = await f.readAsBytes();
    await f.writeAsBytes([...existing, ...List.filled(1000, 2)]);
  }

  @override
  Future<String?> stop() async {
    started = false;
    return path;
  }

  @override
  Future<void> cancel() async {
    started = false;
    if (path != null) {
      final f = File(path!);
      if (await f.exists()) await f.delete();
    }
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream<Amplitude>.empty();

  @override
  Stream<RecordState> onStateChanged() => const Stream<RecordState>.empty();

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Mirrors apps/mobile __tests__/integration/recording.integration.test.tsx +
// the .maestro flows (record-pause-resume-finish, record-kill-recover/discard).
// Drives the real S3 modal widget over the F3 controller with a fake recorder
// backend; the F4 upload PUT is stubbed.
// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rec_screen_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  AudioRecordingService svc(
    AppDatabase db, {
    FakeRecorderBackend? backend,
    bool supported = true,
  }) {
    return AudioRecordingService(
      draftsDao: db.recordingDraftsDao,
      recorder: backend ?? SilentRecorderBackend(),
      documentsDirProvider: () async => tmp,
      durationProbe: (p) async => File(p).lengthSync(),
      captureSupportedProbe: () async => supported,
    );
  }

  // Modern items contract (recordings→items migration): the create leg POSTs to
  // /api/matomes/{coreMatomeId}/items and returns an ITEM + W0 upload; processing
  // is POST /api/items/{id}/process; the current-run poll source is GET
  // /api/items/{id}. The minted-matome coreId is 900; the created item id is 42.
  RecordingsRepository stubRepo({
    Future<void>? uploadGate,
    Completer<void>? uploadStarted,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/matomes/900/items',
      (server) => server.reply(201, {
        'item': {
          'id': 42,
          'owner_id': 1,
          'matome_id': 900,
          'item_type': 'file',
          'title': 'New Recording',
          'processing_state': 'not_requested',
          'processing_run_id': null,
          'processing_attempt': 0,
          'processing_requested_outputs': const <String>[],
          'processing_outputs': const <String, dynamic>{},
          'file': {'media_type': 'audio', 'upload_state': 'pending'},
        },
        'upload': {
          'request': {
            'method': 'PUT',
            'url': 'http://127.0.0.1:9/upload',
            'headers': <String, String>{},
          },
        },
      }),
      data: Matchers.any,
    );
    adapter.onPost(
      '/api/items/42/process',
      (server) => server.reply(202, {
        'item': {
          'id': 42,
          'owner_id': 1,
          'matome_id': 900,
          'item_type': 'file',
          'title': 'New Recording',
          'processing_state': 'queued',
          'processing_run_id': 'run-42',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': const <String, dynamic>{},
          'file': {'media_type': 'audio', 'upload_state': 'uploaded'},
        },
        'processing': {'queued': true},
      }),
    );
    adapter.onGet(
      '/api/items/42',
      (server) => server.reply(200, {
        'item': {
          'id': 42,
          'owner_id': 1,
          'matome_id': 900,
          'item_type': 'file',
          'title': 'New Recording',
          'processing_state': 'succeeded',
          'processing_run_id': 'run-42',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': const <String, dynamic>{},
        },
      }),
    );
    return _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
      uploadGate: uploadGate,
      uploadStarted: uploadStarted,
    );
  }

  // Pumps the widget, letting the post-frame bootstrap (mic-support probe +
  // Drift draft detection — both real async) complete on the real event loop
  // before pumping to render the resolved entry phase.
  Future<void> pumpEntry(WidgetTester tester, Widget widget) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  // Taps [finder] and lets the (async) handler's REAL File IO complete on the
  // real event loop via runAsync — widget-test FakeAsync does not advance
  // dart:io futures, so a plain tap+pump would leave start/pause/resume/finish
  // forever pending. After the handler settles we pump to rebuild, then pump a
  // few frames so any follow-up async (e.g. the upload pipeline + navigation)
  // can land.
  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      // Give the real event loop time to drain the handler's awaits.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Widget app(ProviderContainer container, {RecorderBinding? binding}) {
    final router = GoRouter(
      initialLocation: '/recording',
      routes: [
        GoRoute(
          path: '/recording',
          builder: (context, state) => RecordingScreen(binding: binding),
        ),
        GoRoute(
          path: '/inbox',
          builder: (context, state) => const Scaffold(body: Text('inbox')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('record → pause → resume → finish closes the modal', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBlobStoreProvider.overrideWithValue(FakeMediaBlobStore()),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(coreId: 900),
        audioRecordingServiceProvider.overrideWithValue(svc(db)),
        recordingsRepositoryProvider.overrideWithValue(stubRepo()),
        uploadQueueProvider.overrideWith(UploadQueue.new),
      ],
    );
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));

    // Entry resolves to idle (no draft): the primary mic button is present.
    expect(find.byKey(const Key('record-primary-button')), findsOneWidget);
    expect(find.text(t.recording.ready), findsOneWidget);

    // Start → recording.
    await tapAsync(tester, find.byKey(const Key('record-primary-button')));
    expect(find.text(t.recording.title), findsOneWidget);
    expect(find.byKey(const Key('finish-button')), findsOneWidget);
    expect(
      await db.workQueueDao.listAll(),
      isEmpty,
      reason: 'active capture has no upload work and cannot reach the network',
    );

    // Pause.
    await tapAsync(tester, find.byKey(const Key('pause-button')));
    expect(find.text(t.recording.paused), findsOneWidget);
    // Pause autosaved a recovery draft.
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull);
    expect(
      await db.workQueueDao.listAll(),
      isEmpty,
      reason: 'paused capture is still unfinalized and cannot upload',
    );

    // Resume.
    await tapAsync(tester, find.byKey(const Key('resume-button')));
    expect(find.text(t.recording.title), findsOneWidget);

    // Finish → finalize, upload, and Core process acceptance → modal closes.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('finish-button')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('inbox'), findsOneWidget);

    final rows = await db.itemsDao.listAll('1');
    expect(rows.single.blobId, isNotNull);
    expect(rows.single.processingStatus, 'queued');
  });

  testWidgets('meeting binding (no pause): primary button finishes while recording, '
      'secondary pause is hidden', (tester) async {
    // Audit #828 warning #2: the meeting backend's pause() throws, so the
    // meeting binding must NOT map the primary button to pause and must hide the
    // secondary pause control. We drive a binding with supportsPause:false over
    // the same fake mic providers (the flag is what gates the UI branch).
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBlobStoreProvider.overrideWithValue(FakeMediaBlobStore()),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(coreId: 900),
        audioRecordingServiceProvider.overrideWithValue(svc(db)),
        recordingsRepositoryProvider.overrideWithValue(stubRepo()),
        uploadQueueProvider.overrideWith(UploadQueue.new),
      ],
    );
    addTearDown(container.dispose);

    final meetingLike = RecorderBinding(
      serviceProvider: audioRecordingServiceProvider,
      controllerProvider: recordingControllerProvider,
      finisherProvider: recordingFinisherProvider,
      supportsPause: false,
    );

    await pumpEntry(tester, app(container, binding: meetingLike));

    // Idle: primary present, no pause control yet.
    expect(find.byKey(const Key('record-primary-button')), findsOneWidget);

    // Start → recording.
    await tapAsync(tester, find.byKey(const Key('record-primary-button')));
    expect(find.text(t.recording.title), findsOneWidget);

    // While recording, the meeting binding hides the secondary pause control
    // entirely (it would otherwise call the throwing pause()).
    expect(find.byKey(const Key('pause-button')), findsNothing);
    expect(find.byKey(const Key('finish-button')), findsOneWidget);

    // The PRIMARY button now finishes (stop), not pause: tapping it finalizes
    // and the upload pipeline closes the modal to /inbox. (If it mapped to the
    // throwing pause() this would error instead.)
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('record-primary-button')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.text('inbox'),
      findsOneWidget,
      reason: 'meeting primary button finishes straight through',
    );
  });

  testWidgets('draft prompt → Resume continues the session', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a recoverable draft via a prior paused session. Run on the real
    // event loop (runAsync) — the recorder's File IO can't progress under the
    // widget tester's FakeAsync zone.
    await tester.runAsync(() async {
      final seed = RecordingController(svc(db));
      await seed.start();
      await seed.pause();
      seed.dispose();
    });

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(coreId: 900),
        audioRecordingServiceProvider.overrideWithValue(svc(db)),
        recordingsRepositoryProvider.overrideWithValue(stubRepo()),
      ],
    );
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));

    // Draft prompt shown.
    expect(find.text(t.recording.draftFound), findsOneWidget);
    expect(find.byKey(const Key('draft-resume-button')), findsOneWidget);

    // Resume → recording.
    await tapAsync(tester, find.byKey(const Key('draft-resume-button')));
    expect(find.text(t.recording.title), findsOneWidget);
    expect(
      container.read(recordingControllerProvider).phase,
      RecordingPhase.recording,
    );

    // Tear the live session down (close = discard) so no recorder timer leaks
    // past the test, then let the navigation settle.
    await tapAsync(tester, find.byIcon(Icons.close));
  });

  testWidgets('draft prompt → Discard clears it and shows idle', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a recoverable draft on the real event loop (File IO can't progress
    // under the widget tester's FakeAsync zone).
    await tester.runAsync(() async {
      final seed = RecordingController(svc(db));
      await seed.start();
      await seed.pause();
      seed.dispose();
    });

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(coreId: 900),
        audioRecordingServiceProvider.overrideWithValue(svc(db)),
        recordingsRepositoryProvider.overrideWithValue(stubRepo()),
      ],
    );
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));
    expect(find.text(t.recording.draftFound), findsOneWidget);

    await tapAsync(tester, find.byKey(const Key('draft-discard-button')));

    // Back to a fresh idle screen, draft gone.
    expect(find.text(t.recording.ready), findsOneWidget);
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
  });

  testWidgets(
    'close while recording asks to confirm before discarding (no silent loss)',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
          testParentSyncOverride(coreId: 900),
          audioRecordingServiceProvider.overrideWithValue(svc(db)),
          recordingsRepositoryProvider.overrideWithValue(stubRepo()),
        ],
      );
      addTearDown(container.dispose);

      await pumpEntry(tester, app(container));
      // Start recording so there is in-progress audio to protect.
      await tapAsync(tester, find.byKey(const Key('record-primary-button')));
      expect(find.text(t.recording.title), findsOneWidget);

      // Tap the close (X): a confirmation dialog appears instead of discarding.
      await tapAsync(tester, find.byIcon(Icons.close));
      expect(find.text(t.recording.discardConfirmTitle), findsOneWidget);

      // "Keep recording" dismisses the dialog and keeps the session.
      await tapAsync(tester, find.byKey(const Key('discard-keep-button')));
      // Let the dialog's dismiss transition fully run before asserting it's gone.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(t.recording.discardConfirmTitle), findsNothing);
      expect(
        container.read(recordingControllerProvider).phase,
        RecordingPhase.recording,
      );

      // Re-open and confirm Discard: now the session is torn down and the modal
      // navigates to the Inbox.
      await tapAsync(tester, find.byIcon(Icons.close));
      await tapAsync(tester, find.byKey(const Key('discard-confirm-button')));
      expect(find.text('inbox'), findsOneWidget);
    },
  );

  testWidgets('unsupported mic → shows graceful notice, no crash', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(coreId: 900),
        audioRecordingServiceProvider.overrideWithValue(
          svc(db, supported: false),
        ),
        recordingsRepositoryProvider.overrideWithValue(stubRepo()),
      ],
    );
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));

    expect(find.text(t.recording.unsupportedTitle), findsOneWidget);
    expect(find.byKey(const Key('record-primary-button')), findsNothing);
  });
}

class _StubUploadRepository extends RecordingsRepository
    with VerifiedSingleUploadRepositoryFake {
  _StubUploadRepository({
    required super.apiClient,
    this.uploadGate,
    this.uploadStarted,
  });

  final Future<void>? uploadGate;
  final Completer<void>? uploadStarted;

  @override
  Future<String> uploadStreamRange(
    UploadRequest request,
    Stream<List<int>> stream,
    int length,
  ) async {
    if (!(uploadStarted?.isCompleted ?? true)) uploadStarted!.complete();
    final gate = uploadGate;
    if (gate != null) await gate;
    await stream.drain<void>();
    return 'etag-test';
  }
}
