import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';

import 'audio_recording_service_test.dart' show FakeRecorderBackend;

// ---------------------------------------------------------------------------
// Mirrors apps/mobile __tests__/integration/recording.integration.test.tsx
// (the RecordingScreen phase state machine + draft-recovery prompt), but at the
// controller level since the S3 modal UI is out of scope for F3.
// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rec_ctrl_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  AudioRecordingService svc(AppDatabase db, {FakeRecorderBackend? backend}) {
    return AudioRecordingService(
      draftsDao: db.recordingDraftsDao,
      recorder: backend ?? FakeRecorderBackend(),
      documentsDirProvider: () async => tmp,
      durationProbe: (p) async => File(p).lengthSync(),
      captureSupportedProbe: () async => true,
    );
  }

  test(
    'phase machine: idle → recording → paused → recording → finished',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final controller = RecordingController(svc(db));

      expect(controller.state.phase, RecordingPhase.idle);

      await controller.start();
      expect(controller.state.phase, RecordingPhase.recording);

      await controller.pause();
      expect(controller.state.phase, RecordingPhase.paused);
      // Pause autosaved a draft.
      expect(await db.recordingDraftsDao.loadDraft(), isNotNull);

      await controller.resume();
      expect(controller.state.phase, RecordingPhase.recording);

      final path = await controller.finish();
      expect(controller.state.phase, RecordingPhase.finished);
      expect(await File(path).exists(), isTrue);
      expect(controller.state.durationSeconds, greaterThan(0));

      controller.dispose();
      await db.close();
    },
  );

  test('detectDraft flags hasRecoverableDraft when a draft exists', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    // Seed a draft via one controller session.
    final c1 = RecordingController(svc(db));
    await c1.start();
    await c1.pause();
    c1.dispose();

    // Fresh controller (next app start) detects it.
    final c2 = RecordingController(svc(db));
    final detection = await c2.detectDraft();
    expect(c2.state.hasRecoverableDraft, isTrue);
    expect(detection.draft, isNotNull);

    // Resume continues the same session.
    await c2.resumeFromDraft(detection);
    expect(c2.state.phase, RecordingPhase.recording);
    expect(c2.state.hasRecoverableDraft, isFalse);

    c2.dispose();
    await db.close();
  });

  test('discard resets to idle and clears the draft', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final controller = RecordingController(svc(db));

    await controller.start();
    await controller.pause();
    await controller.discard();

    expect(controller.state.phase, RecordingPhase.idle);
    expect(await db.recordingDraftsDao.loadDraft(), isNull);

    controller.dispose();
    await db.close();
  });

  test('providers wire the controller to the F2 drafts DAO', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioRecordingServiceProvider.overrideWithValue(svc(db)),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(recordingControllerProvider);
    expect(state.phase, RecordingPhase.idle);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    expect(
      container.read(recordingControllerProvider).phase,
      RecordingPhase.recording,
    );

    await db.close();
  });
}
