import '../../core/db/daos/matomes_dao.dart';

/// Display-ready item for one **Matome** in the Calendar day list (#1378).
///
/// The Calendar groups matomes by `happenedAt` (not recordings by createdAt).
/// Carries both `spaceName` (for display) and `spaceId` (so the space filter
/// can target a specific space even when two spaces share a name).
class CalendarMatomeItem {
  const CalendarMatomeItem({
    required this.id,
    required this.title,
    required this.itemCount,
    required this.spaceName,
    required this.spaceId,
    required this.happenedAt,
  });

  final String id;
  final String title;

  /// Number of child Items (recordings) the matome gathers.
  final int itemCount;

  /// NULL when the matome is in the Inbox (spaceId == null).
  final String? spaceName;
  final String? spaceId;

  /// Epoch ms of the matome's happening (the grouping key).
  final int happenedAt;
}

/// Reads the Calendar's Drift slice as **matomes** (#1378): the day-with-matome
/// set (for the month dots) and the day list, grouped by `happened_at`.
///
/// Pure-Dart over [MatomesDao] (no HTTP). [spaceNames] resolves a matome's
/// `spaceId` to a display name for the day-list rows.
class CalendarData {
  const CalendarData(this._dao);

  final MatomesDao _dao;

  /// The set of day-of-month numbers (1–31) that have at least one matome in
  /// [month] of [year] ([month] is 0-indexed, 0 = January).
  ///
  /// Window: local midnight on the 1st → last millisecond of the last day.
  Future<Set<int>> fetchDaysWithMatomes(int year, int month) async {
    final monthStart = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final lastDay = DateTime(year, month + 2, 0, 23, 59, 59, 999);
    final monthEnd = lastDay.millisecondsSinceEpoch;

    final rows = await _dao.matomesByDateRange(monthStart, monthEnd);

    final days = <int>{};
    for (final row in rows) {
      final day = DateTime.fromMillisecondsSinceEpoch(row.happenedAt).day;
      days.add(day);
    }
    return days;
  }

  /// The day's matomes for [date], mapped to display cards. Window: local
  /// midnight of [date] → +24h-1ms. Preserves the DB ordering (newest first).
  /// [spaceNames] maps a `spaceId` to its workspace name (NULL ⟹ Inbox).
  Future<List<CalendarMatomeItem>> fetchDayMatomes(
    DateTime date, {
    required Map<String, String> spaceNames,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch;
    final dayEnd = dayStart + (24 * 60 * 60 * 1000) - 1;

    final rows = await _dao.matomeItemsByDateRange(dayStart, dayEnd);

    return rows
        .map(
          (m) => CalendarMatomeItem(
            id: m.id,
            title: m.title,
            itemCount: m.recordingCount,
            spaceId: m.spaceId,
            spaceName: m.spaceId == null ? null : spaceNames[m.spaceId],
            happenedAt: m.happenedAt,
          ),
        )
        .toList(growable: false);
  }
}
