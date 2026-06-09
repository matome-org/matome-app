import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';

// ---------------------------------------------------------------------------
// LIVE F3 de-risk — runs on a real Android device/emulator with the REAL native
// `record` recorder (RecordRecorderBackend) + path_provider documents dir.
//
// Proves the single-file pause/resume model end-to-end:
//   record (span A) → pause → resume → record (span B) → finish
//   ⇒ exactly ONE audio file whose duration ≈ A + B (no audio lost on pause).
//
// Run: flutter test integration_test/audio_recording_live_test.dart -d <device>
// Requires RECORD_AUDIO permission (granted on the emulator before running).
// This file is the LIVE-MIC counterpart of the headless E2E flows in
// integration_test/e2e_recording_flows_test.dart (which use FakeRecorderBackend
// and run under CI with no device).
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live: record → pause → resume → finish = one continuous file',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    // Default backend = real RecordRecorderBackend; default durationProbe =
    // just_audio probe off the finalized file.
    final svc = AudioRecordingService(draftsDao: db.recordingDraftsDao);

    final supported = await svc.isCaptureSupported();
    expect(supported, isTrue, reason: 'emulator should support mic capture');

    await svc.startRecording();
    expect(svc.isRecorderActive, isTrue);

    // Span A — record for ~1.5s.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final snapshot = await svc.pauseRecording();
    expect(await File(snapshot).exists(), isTrue);
    // Draft autosaved on pause (crash recovery).
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull);
    final pausedSeconds = svc.recordingDurationSeconds;

    // ~0.5s paused — must NOT count toward duration.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await svc.resumeRecording();
    // Span B — record another ~1.5s.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final finalPath = await svc.stopRecording();

    // Exactly ONE resolved segment (continuous session collapsed to one file).
    expect(svc.getSegments().length, 1,
        reason: 'pause/resume must keep a single file');
    final merged = await svc.mergeSegments();
    expect(merged, finalPath);
    expect(await File(merged).exists(), isTrue);
    expect(await File(merged).length(), greaterThan(0));

    // The finalized file's REAL duration ≈ spanA + spanB (≈3s), and clearly
    // longer than the duration captured at pause (≈1.5s). This is the de-risk:
    // resume appended to the SAME file rather than restarting it.
    final totalSeconds = await svc.getAudioDurationSeconds(merged);
    // ignore: avoid_print
    print('[F3-LIVE] pausedSeconds=$pausedSeconds '
        'totalSeconds=$totalSeconds file=$merged '
        'bytes=${await File(merged).length()}');
    expect(totalSeconds, greaterThan(2.0),
        reason: 'summed duration of both spans should exceed ~2s');
    expect(totalSeconds, greaterThan(pausedSeconds),
        reason: 'resume must extend the same file, not restart it');

    // Cleanup (privacy): discard deletes file + draft.
    await svc.discardSegments();
    expect(await File(merged).exists(), isFalse);
    expect(await db.recordingDraftsDao.loadDraft(), isNull);

    await svc.dispose();
    await db.close();
  });

  testWidgets('live: crash recovery — paused draft survives a service restart',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final svc = AudioRecordingService(draftsDao: db.recordingDraftsDao);

    await svc.startRecording();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final snapshot = await svc.pauseRecording();
    // Simulate a kill: release the recorder WITHOUT discarding (draft survives).
    await svc.releaseRecorder();
    await svc.dispose();

    // Next "app start": a fresh service on the same persisted DB detects it.
    final svc2 = AudioRecordingService(draftsDao: db.recordingDraftsDao);
    final detected = await svc2.detectRecoverableDraft();
    expect(detected, isNotNull, reason: 'draft must be recoverable after kill');
    expect(detected!.segments, contains(snapshot));

    await svc2.resumeFromDraft(detected);
    expect(svc2.getSegments(), contains(snapshot));

    // Cleanup.
    await svc2.discardSegments();
    await svc2.dispose();
    await db.close();
  });
}
