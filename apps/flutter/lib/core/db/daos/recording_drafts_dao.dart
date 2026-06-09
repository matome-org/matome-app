import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'recording_drafts_dao.g.dart';

/// In-progress multi-segment recording draft, ported from the RN
/// `RecordingDraft` (apps/mobile/services/draftRecordingService.ts).
///
/// Only one draft is kept at a time: [RecordingDraftsDao.saveDraft] replaces
/// any prior row.
class RecordingDraft {
  const RecordingDraft({required this.segments, required this.durationMs});

  /// Ordered list of segment file paths.
  final List<String> segments;

  /// Accumulated recording duration in milliseconds.
  final int durationMs;
}

/// DAO for `recording_drafts`, porting draftRecordingService.ts.
@DriftAccessor(tables: [RecordingDrafts])
class RecordingDraftsDao extends DatabaseAccessor<AppDatabase>
    with _$RecordingDraftsDaoMixin {
  RecordingDraftsDao(super.db);

  /// Save (or replace) the current draft. Keeps a single row at a time;
  /// DELETE-then-INSERT is wrapped in a transaction so a draft can never be
  /// left deleted-but-not-reinserted. Mirrors `saveDraft`.
  Future<void> saveDraft(List<String> segments, int durationMs) {
    return transaction(() async {
      await delete(recordingDrafts).go();
      await into(recordingDrafts).insert(
        RecordingDraftsCompanion.insert(
          createdAt: DateTime.now().toUtc().toIso8601String(),
          segmentsJson: jsonEncode(segments),
          durationMs: Value(durationMs),
        ),
      );
    });
  }

  /// Load the current draft, or null if none exists. Mirrors `loadDraft`.
  Future<RecordingDraft?> loadDraft() async {
    final row = await (select(recordingDrafts)
          ..orderBy([(d) => OrderingTerm.desc(d.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;

    List<String> segments = const [];
    try {
      final parsed = jsonDecode(row.segmentsJson);
      if (parsed is List) {
        segments = parsed.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // Corrupt JSON — treat as no usable draft, matching the RN guard.
      return null;
    }

    return RecordingDraft(segments: segments, durationMs: row.durationMs);
  }

  /// Delete the current draft (does NOT touch segment files on disk).
  /// Mirrors `deleteDraft`.
  Future<void> deleteDraft() {
    return delete(recordingDrafts).go();
  }
}
