import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recorder_backend.dart';
import 'package:record/record.dart';

// ---------------------------------------------------------------------------
// Mirrors apps/mobile __tests__/unit/audioRecordingService.unit.test.ts and
// draftRecordingService.unit.test.ts. No live mic: a fake RecorderBackend
// simulates the SINGLE-FILE pause/resume model by appending bytes to ONE file
// across pause/resume — proving start→pause→resume→finish yields one continuous
// file. Drift runs in-memory.
// ---------------------------------------------------------------------------

/// Fake backend simulating `record`'s single-file pause/resume: writes to ONE
/// path; pause/resume keep that file open; every "record" span appends bytes so
/// the finalized file's size reflects the WHOLE session (proxy for duration).
class FakeRecorderBackend implements RecorderBackend {
  FakeRecorderBackend({this.permission = true});

  final bool permission;
  String? path;
  bool started = false;
  bool paused = false;
  int recordSpans = 0; // number of record/resume spans appended
  final _stateCtrl = StreamController<RecordState>.broadcast();

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String p, {AudioEncoder encoder = AudioEncoder.aacLc}) async {
    path = p;
    started = true;
    paused = false;
    recordSpans = 1;
    // First span of audio bytes.
    await File(p).writeAsBytes(List.filled(1000, 1));
    _stateCtrl.add(RecordState.record);
  }

  @override
  Future<void> pause() async {
    paused = true;
    _stateCtrl.add(RecordState.pause);
  }

  @override
  Future<void> resume() async {
    paused = false;
    recordSpans += 1;
    // Append the resumed span to the SAME file (continuous, single file).
    final f = File(path!);
    final existing = await f.readAsBytes();
    await f.writeAsBytes([...existing, ...List.filled(1000, 2)]);
    _stateCtrl.add(RecordState.record);
  }

  @override
  Future<String?> stop() async {
    started = false;
    _stateCtrl.add(RecordState.stop);
    return path;
  }

  @override
  Future<void> cancel() async {
    started = false;
    if (path != null) {
      final f = File(path!);
      if (await f.exists()) await f.delete();
    }
    _stateCtrl.add(RecordState.stop);
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      Stream<Amplitude>.periodic(
        interval,
        (_) => Amplitude(current: -20, max: 0),
      );

  @override
  Stream<RecordState> onStateChanged() => _stateCtrl.stream;

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('audio_svc_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  AudioRecordingService makeService(
    AppDatabase db, {
    FakeRecorderBackend? backend,
    bool captureSupported = true,
  }) {
    return AudioRecordingService(
      draftsDao: db.recordingDraftsDao,
      recorder: backend ?? FakeRecorderBackend(),
      documentsDirProvider: () async => tmp,
      // Probe "duration" off the file size so it reflects span count.
      durationProbe: (p) async {
        final len = await File(p).length();
        return len; // ms == bytes (deterministic proxy)
      },
      captureSupportedProbe: () async => captureSupported,
    );
  }

  // -------------------------------------------------------------------------
  // De-risk: single continuous file across pause/resume.
  // -------------------------------------------------------------------------
  group('pause/resume single-file model', () {
    test('record → pause → resume → finish yields ONE file with full duration',
        () async {
      final db = _memDb();
      final backend = FakeRecorderBackend();
      final svc = makeService(db, backend: backend);

      await svc.startRecording();
      await svc.pauseRecording();
      await svc.resumeRecording();
      final segment = await svc.stopRecording();

      // Exactly one resolved segment (continuous session collapses to one file).
      expect(svc.getSegments().length, 1);
      final merged = await svc.mergeSegments();
      expect(merged, segment);
      expect(await File(merged).exists(), isTrue);

      // The finalized file contains BOTH spans (1000 + 1000 bytes) — no audio
      // lost on pause. Duration proxy == 2000.
      final durationSec = await svc.getAudioDurationSeconds(merged);
      expect(durationSec, 2.0); // 2000 ms

      await svc.dispose();
      await db.close();
    });

    test('multiple pause/resume cycles still resolve to one file', () async {
      final db = _memDb();
      final backend = FakeRecorderBackend();
      final svc = makeService(db, backend: backend);

      await svc.startRecording();
      await svc.pauseRecording();
      await svc.resumeRecording();
      await svc.pauseRecording();
      await svc.resumeRecording();
      final segment = await svc.stopRecording();

      expect(svc.getSegments(), [segment]);
      // 3 spans (start + 2 resumes) → 3000 bytes.
      expect(await File(segment).length(), 3000);

      await svc.dispose();
      await db.close();
    });

    test('pause writes a durable snapshot segment', () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      final snapshot = await svc.pauseRecording();

      expect(await File(snapshot).exists(), isTrue);
      expect(snapshot.split('/').last, startsWith('segment_'));
      expect(svc.getSegments(), [snapshot]);

      await svc.dispose();
      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // Draft autosave + crash recovery.
  // -------------------------------------------------------------------------
  group('draft autosave + recovery', () {
    test('pause autosaves the draft to Drift', () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      await svc.pauseRecording();

      final draft = await db.recordingDraftsDao.loadDraft();
      expect(draft, isNotNull);
      expect(draft!.segments, isNotEmpty);

      await svc.dispose();
      await db.close();
    });

    test('detectRecoverableDraft returns a draft whose files still exist',
        () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      final snapshot = await svc.pauseRecording();
      // Simulate "kill" by tearing down the service (draft + file persist).
      await svc.dispose();

      // New service on the SAME db (next app start).
      final svc2 = makeService(db);
      final detected = await svc2.detectRecoverableDraft();
      expect(detected, isNotNull);
      expect(detected!.segments, contains(snapshot));

      await svc2.dispose();
      await db.close();
    });

    test('detectRecoverableDraft discards a stale draft (files gone)', () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      final snapshot = await svc.pauseRecording();
      await svc.dispose();

      // Files vanish (e.g. OS cache cleared) but the draft row remains.
      await File(snapshot).delete();

      final svc2 = makeService(db);
      final detected = await svc2.detectRecoverableDraft();
      expect(detected, isNull);
      // Stale draft swept.
      expect(await db.recordingDraftsDao.loadDraft(), isNull);

      await svc2.dispose();
      await db.close();
    });

    test('resumeFromDraft seeds segments + restores duration', () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      final snapshot = await svc.pauseRecording();
      await svc.dispose();

      final svc2 = makeService(db);
      final detected = await svc2.detectRecoverableDraft();
      await svc2.resumeFromDraft(detected!);

      expect(svc2.getSegments(), contains(snapshot));
      expect(svc2.recordingDurationSeconds, detected.durationMs / 1000.0);

      await svc2.dispose();
      await db.close();
    });

    test('recovered draft: straight-through resumed span APPENDS (preserves prior)',
        () async {
      // Cross-restart: resume a recovered draft, record a NEW span (no pause),
      // finish. The new span is appended → 2 segments; mergeSegments returns the
      // LAST (documented limitation).
      final db = _memDb();
      final svc = makeService(db);
      await svc.startRecording();
      final priorSnapshot = await svc.pauseRecording();
      await svc.dispose();

      final svc2 = makeService(db, backend: FakeRecorderBackend());
      final detected = await svc2.detectRecoverableDraft();
      // Resume flow: start a fresh recorder, re-seed prior spans.
      await svc2.startRecording();
      svc2.restoreSegments(detected!.segments);
      final newSegment = await svc2.stopRecording(); // straight-through, not continuous

      final segs = svc2.getSegments();
      expect(segs, [priorSnapshot, newSegment]);
      expect(await svc2.mergeSegments(), newSegment); // last-span fallback

      await svc2.dispose();
      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // discardSegments — privacy: deletes files + draft.
  // -------------------------------------------------------------------------
  group('discardSegments', () {
    test('deletes all segment files AND the draft', () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      final snapshot = await svc.pauseRecording();
      expect(await File(snapshot).exists(), isTrue);
      expect(await db.recordingDraftsDao.loadDraft(), isNotNull);

      await svc.discardSegments();

      expect(await File(snapshot).exists(), isFalse);
      expect(svc.getSegments(), isEmpty);
      expect(await db.recordingDraftsDao.loadDraft(), isNull);

      await svc.dispose();
      await db.close();
    });

    test('is safe to call with nothing recorded', () async {
      final db = _memDb();
      final svc = makeService(db);
      await svc.discardSegments(); // must not throw
      expect(svc.getSegments(), isEmpty);
      await svc.dispose();
      await db.close();
    });

    test('cancelRecording stops, discards files + draft', () async {
      final db = _memDb();
      final svc = makeService(db);

      await svc.startRecording();
      final snapshot = await svc.pauseRecording();
      await svc.cancelRecording();

      expect(await File(snapshot).exists(), isFalse);
      expect(svc.isRecorderActive, isFalse);
      expect(await db.recordingDraftsDao.loadDraft(), isNull);

      await svc.dispose();
      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // Back-to-back session isolation (no state leak).
  // -------------------------------------------------------------------------
  group('session isolation', () {
    test('a new session resets segments + flags from the prior one', () async {
      final db = _memDb();
      final svc = makeService(db);

      // Session 1: record + finish (leaves a segment in state).
      await svc.startRecording();
      await svc.pauseRecording();
      await svc.resumeRecording();
      final s1 = await svc.stopRecording();
      expect(svc.getSegments(), [s1]);

      // Session 2: fresh start must clear S1 state up front.
      await svc.startRecording();
      expect(svc.getSegments(), isEmpty);
      expect(svc.recordingDurationSeconds, 0);
      final s2 = await svc.stopRecording();
      expect(svc.getSegments(), [s2]);
      expect(s2, isNot(s1));

      await svc.dispose();
      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // Capability + permission degradation.
  // -------------------------------------------------------------------------
  group('platform degradation', () {
    test('start throws AudioCaptureUnsupportedError when capture unsupported',
        () async {
      final db = _memDb();
      final svc = makeService(db, captureSupported: false);
      await expectLater(
        svc.startRecording(),
        throwsA(isA<AudioCaptureUnsupportedError>()),
      );
      await svc.dispose();
      await db.close();
    });

    test('start throws MicrophonePermissionDeniedError when denied', () async {
      final db = _memDb();
      final svc = makeService(db, backend: FakeRecorderBackend(permission: false));
      await expectLater(
        svc.startRecording(),
        throwsA(isA<MicrophonePermissionDeniedError>()),
      );
      await svc.dispose();
      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // Pure helpers (mirror the RN unit tests).
  // -------------------------------------------------------------------------
  group('helpers', () {
    test('formatDuration', () {
      expect(AudioRecordingService.formatDuration(0), '0s');
      expect(AudioRecordingService.formatDuration(9), '9s');
      expect(AudioRecordingService.formatDuration(59), '59s');
      expect(AudioRecordingService.formatDuration(60), '1m 0s');
      expect(AudioRecordingService.formatDuration(134), '2m 14s');
      expect(AudioRecordingService.formatDuration(134.9), '2m 14s');
    });

    test('generateRecordingId is unique and prefixed', () {
      final a = AudioRecordingService.generateRecordingId();
      final b = AudioRecordingService.generateRecordingId();
      expect(a, startsWith('rec_'));
      expect(a, isNot(b));
    });

    test('generateTitle: default when empty, truncates long transcripts', () {
      expect(AudioRecordingService.generateTitle(null), startsWith('New Recording'));
      expect(AudioRecordingService.generateTitle(''), startsWith('New Recording'));
      expect(AudioRecordingService.generateTitle('Hello world'), 'Hello world');
      final long = 'x' * 60;
      final title = AudioRecordingService.generateTitle(long);
      expect(title.length, 50);
      expect(title, endsWith('...'));
      expect(AudioRecordingService.generateTitle('First line\nsecond'),
          'First line');
    });

    test('formatTimestamp 12-hour clock', () {
      expect(
          AudioRecordingService.formatTimestamp(DateTime(2026, 1, 1, 10, 42)),
          '10:42 AM');
      expect(
          AudioRecordingService.formatTimestamp(DateTime(2026, 1, 1, 0, 5)),
          '12:05 AM');
      expect(
          AudioRecordingService.formatTimestamp(DateTime(2026, 1, 1, 13, 7)),
          '1:07 PM');
      expect(
          AudioRecordingService.formatTimestamp(DateTime(2026, 1, 1, 12, 0)),
          '12:00 PM');
    });
  });
}
