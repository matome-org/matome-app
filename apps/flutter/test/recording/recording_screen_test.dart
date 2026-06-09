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
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:record/record.dart' show Amplitude, AudioEncoder, RecordState;

import 'audio_recording_service_test.dart' show FakeRecorderBackend;

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
  Future<void> start(String p, {AudioEncoder encoder = AudioEncoder.aacLc}) async {
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

  RecordingsRepository stubRepo() {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/recordings',
      (server) => server.reply(201, {
        'recording': {
          'id': 42,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'pending',
        },
        'upload': {
          'method': 'PUT',
          'url': 'http://127.0.0.1:9/upload',
          'storage_key': 'k',
          'expires_in': 900,
        },
      }),
      data: Matchers.any,
    );
    adapter.onPost(
      '/api/recordings/42/process',
      (server) => server.reply(202, {
        'recording': {
          'id': 42,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'processing',
        },
        'processing': {'queued': true},
      }),
    );
    adapter.onGet(
      '/api/recordings/42',
      (server) => server.reply(200, {
        'recording': {
          'id': 42,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'done',
        },
      }),
    );
    return _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
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

  Widget app(ProviderContainer container) {
    final router = GoRouter(
      initialLocation: '/recording',
      routes: [
        GoRoute(
          path: '/recording',
          builder: (context, state) => const RecordingScreen(),
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('record → pause → resume → finish closes the modal',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioRecordingServiceProvider.overrideWithValue(svc(db)),
      recordingsRepositoryProvider.overrideWithValue(stubRepo()),
      // Avoid a live Phoenix socket connect in the widget test; the poll
      // fallback resolves done (the realtime wiring itself is covered by the
      // finish unit test).
      inboxUploaderProvider.overrideWith(
        (ref) => InboxUploader(ref, awaitResult: pollFallbackAwaiter),
      ),
    ]);
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));

    // Entry resolves to idle (no draft): the primary mic button is present.
    expect(find.byKey(const Key('record-primary-button')), findsOneWidget);
    expect(find.text(t.recording.ready), findsOneWidget);

    // Start → recording.
    await tapAsync(tester, find.byKey(const Key('record-primary-button')));
    expect(find.text(t.recording.title), findsOneWidget);
    expect(find.byKey(const Key('finish-button')), findsOneWidget);

    // Pause.
    await tapAsync(tester, find.byKey(const Key('pause-button')));
    expect(find.text(t.recording.paused), findsOneWidget);
    // Pause autosaved a recovery draft.
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull);

    // Resume.
    await tapAsync(tester, find.byKey(const Key('resume-button')));
    expect(find.text(t.recording.title), findsOneWidget);

    // Finish → finalize, then the upload pipeline runs (create + upload +
    // enqueue + await done) → modal closes (router moves to /inbox).
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('finish-button')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('inbox'), findsOneWidget);

    // The new recording landed in the Inbox (Drift), done.
    final row = await db.recordingsDao.getRecordingById('42');
    expect(row, isNotNull);
    expect(row!.processingStatus, 'done');
    // Draft was cleaned up.
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
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

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioRecordingServiceProvider.overrideWithValue(svc(db)),
      recordingsRepositoryProvider.overrideWithValue(stubRepo()),
    ]);
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

  testWidgets('draft prompt → Discard clears it and shows idle', (tester) async {
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

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioRecordingServiceProvider.overrideWithValue(svc(db)),
      recordingsRepositoryProvider.overrideWithValue(stubRepo()),
    ]);
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));
    expect(find.text(t.recording.draftFound), findsOneWidget);

    await tapAsync(tester, find.byKey(const Key('draft-discard-button')));

    // Back to a fresh idle screen, draft gone.
    expect(find.text(t.recording.ready), findsOneWidget);
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
  });

  testWidgets('unsupported mic → shows graceful notice, no crash',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioRecordingServiceProvider
          .overrideWithValue(svc(db, supported: false)),
      recordingsRepositoryProvider.overrideWithValue(stubRepo()),
    ]);
    addTearDown(container.dispose);

    await pumpEntry(tester, app(container));

    expect(find.text(t.recording.unsupportedTitle), findsOneWidget);
    expect(find.byKey(const Key('record-primary-button')), findsNothing);
  });
}

class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {}
}

/// Socket-absent awaiter: an empty event stream so only the poll fallback
/// (GET → done) resolves. Drives the production [RecordingResultWaiter] race
/// without a live Phoenix socket in the widget test.
Future<RecordingResult> pollFallbackAwaiter({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
}) async {
  final events = StreamController<RecordingStatusEvent>();
  final waiter = RecordingResultWaiter(
    recordingId: recording.id,
    statusEvents: events.stream,
    poll: poll,
    pollInterval: const Duration(milliseconds: 20),
  );
  final result = await waiter.wait();
  await events.close();
  return result;
}
