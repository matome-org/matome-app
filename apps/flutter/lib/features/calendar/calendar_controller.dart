import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/workspaces_dao.dart';
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import 'calendar_data.dart';

/// A space option in the filter strip.
class CalendarSpace {
  const CalendarSpace({required this.id, required this.name});

  final String id;
  final String name;
}

/// Immutable Calendar screen state (#1378): the unit is the **Matome**, grouped
/// by `happenedAt`. Dots mark days with matomes; the day list shows that day's
/// matomes; the space filter narrows by `spaceId`.
class CalendarState {
  const CalendarState({
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.daysWithMatomes,
    required this.rawDayMatomes,
    required this.spaces,
    required this.selectedSpaceId,
    required this.isMonthLoading,
    required this.isDayLoading,
  });

  /// 0-indexed month (0 = January).
  final int year;
  final int month;
  final int selectedDay;

  /// Day-of-month numbers (1–31) that have at least one matome this month.
  final Set<int> daysWithMatomes;

  /// The selected day's matomes before the space filter is applied.
  final List<CalendarMatomeItem> rawDayMatomes;

  final List<CalendarSpace> spaces;
  final String? selectedSpaceId;

  final bool isMonthLoading;
  final bool isDayLoading;

  /// The selected day's matomes after applying the active space filter. Filters
  /// on `spaceId` (not name) so two spaces with identical names never bleed into
  /// each other's list.
  List<CalendarMatomeItem> get dayMatomes {
    if (selectedSpaceId == null) return rawDayMatomes;
    return rawDayMatomes
        .where((m) => m.spaceId == selectedSpaceId)
        .toList(growable: false);
  }

  CalendarState copyWith({
    int? year,
    int? month,
    int? selectedDay,
    Set<int>? daysWithMatomes,
    List<CalendarMatomeItem>? rawDayMatomes,
    List<CalendarSpace>? spaces,
    Object? selectedSpaceId = _noChange,
    bool? isMonthLoading,
    bool? isDayLoading,
  }) {
    return CalendarState(
      year: year ?? this.year,
      month: month ?? this.month,
      selectedDay: selectedDay ?? this.selectedDay,
      daysWithMatomes: daysWithMatomes ?? this.daysWithMatomes,
      rawDayMatomes: rawDayMatomes ?? this.rawDayMatomes,
      spaces: spaces ?? this.spaces,
      selectedSpaceId: selectedSpaceId == _noChange
          ? this.selectedSpaceId
          : selectedSpaceId as String?,
      isMonthLoading: isMonthLoading ?? this.isMonthLoading,
      isDayLoading: isDayLoading ?? this.isDayLoading,
    );
  }

  static const Object _noChange = Object();
}

/// Drives the Calendar screen (S4) under the matome-centric model (#1378).
/// Offline-first: dots, day lists, and spaces all read from Drift.
///   * loadMonthDots(y, m)  → fetchDaysWithMatomes,
///   * loadDayMatomes(d)    → fetchDayMatomes,
///   * loadSpaces()         → workspaces list,
///   * handleMonthChange    → always reloads BOTH dots and the day list,
///     clamping the selected day to the new month.
class CalendarController extends StateNotifier<CalendarState> {
  CalendarController(this._ref, {DateTime? now})
    : super(_initial(now ?? DateTime.now())) {
    _bootstrap();
  }

  final Ref _ref;

  CalendarData get _data => CalendarData(_ref.read(matomesDaoProvider));
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);

  /// spaceId → workspace name, refreshed by [loadSpaces]. Used to label the
  /// day-list rows with their filed Space.
  Map<String, String> _spaceNames = const {};

  static CalendarState _initial(DateTime now) {
    return CalendarState(
      year: now.year,
      month: now.month - 1, // store 0-indexed
      selectedDay: now.day,
      daysWithMatomes: const <int>{},
      rawDayMatomes: const [],
      spaces: const [],
      selectedSpaceId: null,
      isMonthLoading: false,
      isDayLoading: false,
    );
  }

  Future<void> _bootstrap() async {
    // Spaces first so the day-list rows can resolve their space names.
    await loadSpaces();
    if (!mounted) return;
    await Future.wait([
      loadMonthDots(state.year, state.month),
      loadDayMatomes(DateTime(state.year, state.month + 1, state.selectedDay)),
    ]);
  }

  /// Reload the dots for [year]/[month] (0-indexed month).
  Future<void> loadMonthDots(int year, int month) async {
    if (!mounted) return;
    state = state.copyWith(isMonthLoading: true);
    try {
      final days = await _data.fetchDaysWithMatomes(year, month);
      if (!mounted) return;
      state = state.copyWith(daysWithMatomes: days);
    } catch (e, st) {
      // Swallow — keep whatever dots are already shown (offline-first).
      AppLog.error(
        LogCat.error,
        'calendar loadMonthDots failed year=$year month=$month',
        e,
        st,
      );
    } finally {
      if (mounted) state = state.copyWith(isMonthLoading: false);
    }
  }

  /// Reload the day list for [date].
  Future<void> loadDayMatomes(DateTime date) async {
    if (!mounted) return;
    AppLog.event(
      LogCat.action,
      'loadDayMatomes date=${date.toIso8601String()}',
    );
    state = state.copyWith(isDayLoading: true);
    try {
      final matomes = await _data.fetchDayMatomes(
        date,
        spaceNames: _spaceNames,
      );
      if (!mounted) return;
      state = state.copyWith(rawDayMatomes: matomes);
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'calendar loadDayMatomes failed date=${date.toIso8601String()}',
        e,
        st,
      );
      if (mounted) state = state.copyWith(rawDayMatomes: const []);
    } finally {
      if (mounted) state = state.copyWith(isDayLoading: false);
    }
  }

  /// Load the space filter options from Drift (workspaces).
  Future<void> loadSpaces() async {
    try {
      final rows = await _workspacesDao.getWorkspaces();
      if (!mounted) return;
      _spaceNames = {for (final w in rows) w.id: w.name};
      state = state.copyWith(
        spaces: rows
            .map((w) => CalendarSpace(id: w.id, name: w.name))
            .toList(growable: false),
      );
    } catch (e, st) {
      // Non-fatal; the strip just shows "All" with no chips.
      AppLog.error(LogCat.error, 'calendar loadSpaces failed', e, st);
    }
  }

  /// Navigate to a new [year]/[month] (0-indexed). Clamps the selected day to
  /// the last day of the new month when it would overflow, then ALWAYS reloads
  /// both the dots and the day list.
  Future<void> changeMonth(int year, int month) async {
    if (!mounted) return;
    final daysInNewMonth = DateTime(year, month + 2, 0).day;
    final targetDay = state.selectedDay > daysInNewMonth
        ? 1
        : state.selectedDay;

    state = state.copyWith(year: year, month: month, selectedDay: targetDay);

    await Future.wait([
      loadDayMatomes(DateTime(year, month + 1, targetDay)),
      loadMonthDots(year, month),
    ]);
  }

  /// Step to the previous month, wrapping the year.
  Future<void> prevMonth() {
    if (state.month == 0) return changeMonth(state.year - 1, 11);
    return changeMonth(state.year, state.month - 1);
  }

  /// Step to the next month, wrapping the year.
  Future<void> nextMonth() {
    if (state.month == 11) return changeMonth(state.year + 1, 0);
    return changeMonth(state.year, state.month + 1);
  }

  /// Select [day] in the current month and load its matomes.
  Future<void> selectDay(int day) async {
    if (!mounted) return;
    AppLog.event(LogCat.action, 'selectDay day=$day');
    state = state.copyWith(selectedDay: day);
    await loadDayMatomes(DateTime(state.year, state.month + 1, day));
  }

  /// Apply (or clear, when null) the space filter. No DB re-fetch — filtering
  /// happens in [CalendarState.dayMatomes].
  void setSpaceFilter(String? spaceId) {
    state = state.copyWith(selectedSpaceId: spaceId);
  }
}

/// Clock seam for the Calendar's "today". Overridden in tests to pin the
/// bootstrap year/month/day deterministically.
final calendarNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final calendarControllerProvider =
    StateNotifierProvider<CalendarController, CalendarState>(
      (ref) => CalendarController(ref, now: ref.read(calendarNowProvider)()),
    );
