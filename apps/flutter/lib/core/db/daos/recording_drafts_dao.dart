import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'recording_drafts_dao.g.dart';

enum RecordingCaptureKind {
  microphone('microphone'),
  meeting('meeting');

  const RecordingCaptureKind(this.wireName);
  final String wireName;

  static RecordingCaptureKind fromWire(String value) => values.firstWhere(
    (kind) => kind.wireName == value,
    orElse: () => microphone,
  );
}

enum RecordingDraftState {
  starting('starting'),
  recording('recording'),
  paused('paused'),
  finalizing('finalizing'),
  completed('completed'),
  failed('failed');

  const RecordingDraftState(this.wireName);
  final String wireName;

  static RecordingDraftState fromWire(String value) => values.firstWhere(
    (state) => state.wireName == value,
    orElse: () => paused,
  );
}

/// In-progress recording draft, ported from the RN
/// `RecordingDraft` (apps/mobile/services/draftRecordingService.ts).
class RecordingDraft {
  const RecordingDraft({
    required this.segmentHandles,
    required this.durationMs,
    this.sessionId = 'legacy',
    this.captureKind = RecordingCaptureKind.microphone,
    this.backend = 'record',
    this.stagingHandle,
    this.codec = 'aac_lc',
    this.state = RecordingDraftState.paused,
    this.heartbeatAt,
  });

  /// Ordered opaque handles resolved only inside recorder staging.
  final List<String> segmentHandles;

  /// Accumulated recording duration in milliseconds.
  final int durationMs;
  final String sessionId;
  final RecordingCaptureKind captureKind;
  final String backend;
  final String? stagingHandle;
  final String codec;
  final RecordingDraftState state;
  final DateTime? heartbeatAt;

  RecordingDraft copyWith({
    List<String>? segmentHandles,
    int? durationMs,
    String? sessionId,
    RecordingCaptureKind? captureKind,
    String? backend,
    String? stagingHandle,
    String? codec,
    RecordingDraftState? state,
    DateTime? heartbeatAt,
  }) {
    return RecordingDraft(
      segmentHandles: segmentHandles ?? this.segmentHandles,
      durationMs: durationMs ?? this.durationMs,
      sessionId: sessionId ?? this.sessionId,
      captureKind: captureKind ?? this.captureKind,
      backend: backend ?? this.backend,
      stagingHandle: stagingHandle ?? this.stagingHandle,
      codec: codec ?? this.codec,
      state: state ?? this.state,
      heartbeatAt: heartbeatAt ?? this.heartbeatAt,
    );
  }
}

/// DAO for `recording_drafts`, porting draftRecordingService.ts.
@DriftAccessor(tables: [RecordingDrafts])
class RecordingDraftsDao extends DatabaseAccessor<AppDatabase>
    with _$RecordingDraftsDaoMixin {
  RecordingDraftsDao(super.db);

  /// Compatibility entry point for microphone drafts.
  Future<void> saveDraft(List<String> segments, int durationMs) {
    final now = DateTime.now().toUtc();
    return saveTypedDraft(
      RecordingDraft(
        segmentHandles: segments,
        durationMs: durationMs,
        sessionId: 'mic_${now.microsecondsSinceEpoch}',
        heartbeatAt: now,
      ),
    );
  }

  /// Save (or replace) one capture kind without disturbing another active kind.
  Future<void> saveTypedDraft(RecordingDraft draft) {
    return transaction(() async {
      await (delete(
            recordingDrafts,
          )..where((row) => row.captureKind.equals(draft.captureKind.wireName)))
          .go();
      await into(recordingDrafts).insert(
        RecordingDraftsCompanion.insert(
          createdAt: DateTime.now().toUtc().toIso8601String(),
          segmentHandlesJson: jsonEncode(draft.segmentHandles),
          durationMs: Value(draft.durationMs),
          sessionId: Value(draft.sessionId),
          captureKind: Value(draft.captureKind.wireName),
          backend: Value(draft.backend),
          stagingHandle: Value(draft.stagingHandle),
          codec: Value(draft.codec),
          state: Value(draft.state.wireName),
          heartbeatAt: Value(draft.heartbeatAt?.toUtc().toIso8601String()),
        ),
      );
    });
  }

  /// Load the newest draft for [captureKind], or null if none exists.
  Future<RecordingDraft?> loadDraft({
    RecordingCaptureKind captureKind = RecordingCaptureKind.microphone,
  }) async {
    final row =
        await (select(recordingDrafts)
              ..where((row) => row.captureKind.equals(captureKind.wireName))
              ..orderBy([(d) => OrderingTerm.desc(d.id)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;

    List<String> segments = const [];
    try {
      final parsed = jsonDecode(row.segmentHandlesJson);
      if (parsed is List) {
        segments = parsed.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // Invalid handle lists are unusable and swept by capture recovery.
      segments = const [];
    }

    return RecordingDraft(
      segmentHandles: segments,
      durationMs: row.durationMs,
      sessionId: row.sessionId,
      captureKind: RecordingCaptureKind.fromWire(row.captureKind),
      backend: row.backend,
      stagingHandle: row.stagingHandle,
      codec: row.codec,
      state: RecordingDraftState.fromWire(row.state),
      heartbeatAt: DateTime.tryParse(row.heartbeatAt ?? ''),
    );
  }

  /// Delete one capture kind (does NOT touch files on disk).
  Future<void> deleteDraft({
    RecordingCaptureKind captureKind = RecordingCaptureKind.microphone,
  }) {
    return (delete(
      recordingDrafts,
    )..where((row) => row.captureKind.equals(captureKind.wireName))).go();
  }

  /// Compare-and-delete so acknowledgement for session A cannot clear a newer
  /// session B inserted between a read and delete.
  Future<bool> deleteDraftIfSession({
    required RecordingCaptureKind captureKind,
    required String sessionId,
    RecordingDraftState? state,
  }) async {
    final deleted =
        await (delete(recordingDrafts)..where(
              (row) =>
                  row.captureKind.equals(captureKind.wireName) &
                  row.sessionId.equals(sessionId) &
                  (state == null
                      ? const Constant(true)
                      : row.state.equals(state.wireName)),
            ))
            .go();
    return deleted == 1;
  }
}
