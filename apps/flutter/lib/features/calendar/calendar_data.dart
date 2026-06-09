import '../../core/db/daos/recordings_dao.dart';

/// Display-ready card for one recording in the Calendar day list.
///
/// Ported from apps/mobile/processes/calendarData.ts `CalendarRecordingCard`.
/// Carries both `workspaceName` (for display) and `workspaceId` (so the space
/// filter can target a specific space even when two spaces share a name).
class CalendarRecordingCard {
  const CalendarRecordingCard({
    required this.id,
    required this.title,
    required this.duration,
    required this.badge,
    required this.workspaceName,
    required this.workspaceId,
    required this.createdAt,
  });

  final String id;
  final String title;

  /// Duration in whole seconds (parsed from the persisted "m:ss"/"Xm Ys"
  /// display string via [parseDurationSeconds]).
  final int duration;

  /// One of the canonical badge values: Work / Personal / Inbox.
  final String badge;

  /// NULL when the row is in the Inbox (LEFT JOIN returned no workspace).
  final String? workspaceName;
  final String? workspaceId;

  final int createdAt;
}

const List<String> _badgeValues = ['Work', 'Personal', 'Inbox'];

/// Coerce a free-form badge to one of the canonical values, defaulting to
/// `Inbox`. Mirrors `coerceBadge` in calendarData.ts.
String coerceBadge(Object? value) {
  if (value is String && _badgeValues.contains(value)) {
    return value;
  }
  return 'Inbox';
}

/// Parse a duration string produced by audioRecordingService.formatDuration.
///
/// Accepts:
///   * `"2m 14s"` — minutes + seconds,
///   * `"45s"`    — seconds only (< 60).
///
/// Falls back to 0 for anything unrecognisable (including the empty string).
/// Faithful port of `parseDurationSeconds` in calendarData.ts.
int parseDurationSeconds(String? duration) {
  if (duration == null || duration.isEmpty) return 0;

  // "Xm Ys" — e.g. "2m 14s".
  final minsAndSecs = RegExp(r'^(\d+)m\s+(\d+)s$').firstMatch(duration);
  if (minsAndSecs != null) {
    final minutes = int.tryParse(minsAndSecs.group(1)!);
    final seconds = int.tryParse(minsAndSecs.group(2)!);
    if (minutes != null && seconds != null) {
      return minutes * 60 + seconds;
    }
  }

  // "Xs" — e.g. "45s".
  final secsOnly = RegExp(r'^(\d+)s$').firstMatch(duration);
  if (secsOnly != null) {
    final seconds = int.tryParse(secsOnly.group(1)!);
    if (seconds != null) {
      return seconds;
    }
  }

  return 0;
}

/// Reads the Calendar's Drift slice: day-with-recordings sets + day lists.
///
/// Pure-Dart over [RecordingsDao] (no HTTP). Mirrors the two exported readers
/// in calendarData.ts: `fetchDaysWithRecordings` and `fetchDayRecordings`.
class CalendarData {
  const CalendarData(this._dao);

  final RecordingsDao _dao;

  /// The set of day-of-month numbers (1–31) that have at least one recording
  /// in [month] of [year] ([month] is 0-indexed, 0 = January).
  ///
  /// Window: local midnight on the 1st → last millisecond of the last day.
  /// Ports `fetchDaysWithRecordings`.
  Future<Set<int>> fetchDaysWithRecordings(int year, int month) async {
    final monthStart =
        DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    // DateTime(year, month + 2, 0) == last day of `month` (1-indexed month+1).
    final lastDay = DateTime(year, month + 2, 0, 23, 59, 59, 999);
    final monthEnd = lastDay.millisecondsSinceEpoch;

    final records = await _dao.recordingsByDateRange(monthStart, monthEnd);

    final days = <int>{};
    for (final record in records) {
      final day =
          DateTime.fromMillisecondsSinceEpoch(record.createdAt).day;
      days.add(day);
    }
    return days;
  }

  /// The day's recordings for [date], joined with workspace names and mapped to
  /// display cards. Window: local midnight of [date] → +24h-1ms. Preserves the
  /// DB ordering (newest first). Ports `fetchDayRecordings`.
  Future<List<CalendarRecordingCard>> fetchDayRecordings(DateTime date) async {
    final dayStart =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

    final rows = await _dao.recordingsByDayWithWorkspace(dayStart);

    return rows
        .map(
          (row) => CalendarRecordingCard(
            id: row.recording.id,
            title: row.recording.title,
            duration: parseDurationSeconds(row.recording.duration),
            badge: coerceBadge(row.recording.badge),
            workspaceName: row.workspaceName,
            workspaceId: row.recording.workspaceId,
            createdAt: row.recording.createdAt,
          ),
        )
        .toList(growable: false);
  }
}
