import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/app/screens/meeting_recording_screen.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:matome_flutter/features/recording/meeting_capture_finish.dart';
import 'package:matome_flutter/features/recording/meeting_capture_service.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

class _ScreenBackend implements MeetingCaptureBackend {
  final controller = StreamController<MeetingCaptureEvent>.broadcast();
  MeetingCaptureRequest? request;

  @override
  String get backendId => 'screen-fake';

  @override
  Stream<MeetingCaptureEvent> get events => controller.stream;

  @override
  Future<MeetingCaptureCapability> probe() async =>
      const MeetingCaptureCapability.supported(backendId: 'screen-fake');

  @override
  Future<MeetingCapturePermission> requestPermission() async =>
      MeetingCapturePermission.granted;

  @override
  Future<void> start(MeetingCaptureRequest value) async {
    request = value;
    await File(value.stagingPath).writeAsBytes(List<int>.filled(1024, 1));
    controller.add(
      const MeetingCaptureEvent.level(
        source: MeetingCaptureSource.system,
        levelDb: -18,
      ),
    );
    controller.add(
      const MeetingCaptureEvent.level(
        source: MeetingCaptureSource.microphone,
        levelDb: -24,
      ),
    );
  }

  @override
  Future<MeetingCaptureCandidate> stop() async =>
      MeetingCaptureCandidate(path: request!.stagingPath);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    unawaited(controller.close());
  }
}

class _ScreenService extends MeetingCaptureService {
  _ScreenService({required AppDatabase db, required _ScreenBackend backend})
    : _backend = backend,
      super(
        draftsDao: db.recordingDraftsDao,
        backend: backend,
        storageDirectory: Directory.systemTemp.createTemp,
        inspectArtifact: (_) => throw UnimplementedError(),
        availableBytes: (_) async => 1 << 30,
        minimumAvailableBytes: 1024,
      );

  final _ScreenBackend _backend;

  @override
  Stream<MeetingCaptureEvent> get events => _backend.events;

  @override
  Future<MeetingCaptureArtifact?> recover() async => null;

  @override
  Future<void> start() async {
    _backend.controller.add(
      const MeetingCaptureEvent.level(
        source: MeetingCaptureSource.system,
        levelDb: -18,
      ),
    );
    _backend.controller.add(
      const MeetingCaptureEvent.level(
        source: MeetingCaptureSource.microphone,
        levelDb: -24,
      ),
    );
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('starts capture and renders independent live source levels', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final backend = _ScreenBackend();
    final service = _ScreenService(db: db, backend: backend);
    final finisher = MeetingCaptureFinisher(
      service: service,
      persist: (artifact, {title}) async => 'local-meeting',
      scheduleUpload: (_) {},
    );
    final capabilityProvider = FutureProvider<MeetingCaptureCapability>(
      (ref) async =>
          const MeetingCaptureCapability.supported(backendId: 'screen-fake'),
    );
    final serviceProvider = Provider<MeetingCaptureService>((ref) => service);
    final finisherProvider = Provider<MeetingCaptureFinisher>(
      (ref) => finisher,
    );
    final binding = MeetingRecordingBinding(
      capabilityProvider: capabilityProvider,
      serviceProvider: serviceProvider,
      finisherProvider: finisherProvider,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await service.dispose();
      await db.close();
    });

    await tester.pumpWidget(_app(MeetingRecordingScreen(binding: binding)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.meetingRecording.ready), findsOneWidget);

    await tester.tap(find.byKey(const Key('meeting-start-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.meetingRecording.systemAudio), findsOneWidget);
    expect(find.byKey(const Key('meeting-finish-button')), findsOneWidget);
    await service.cancel();
  });

  testWidgets('direct route shows a localized unsupported state', (
    tester,
  ) async {
    final capabilityProvider = FutureProvider<MeetingCaptureCapability>(
      (ref) async => const MeetingCaptureCapability.unsupported(
        backendId: 'screen-fake',
        reason: 'linux-required',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: MeetingRecordingScreen(
              binding: MeetingRecordingBinding(
                capabilityProvider: capabilityProvider,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.meetingRecording.unsupportedTitle), findsOneWidget);
    expect(find.text(t.meetingRecording.linuxRequired), findsOneWidget);
  });
}

Widget _app(Widget home) => ProviderScope(
  child: TranslationProvider(
    child: MaterialApp(
      theme: buildLightTheme(),
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  ),
);
