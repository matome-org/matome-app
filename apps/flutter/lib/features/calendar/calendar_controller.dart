import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/workspaces_dao.dart';
import '../../core/providers.dart';
import 'calendar_data.dart';

/// A space option in the filter strip.
class CalendarSpace {
  const CalendarSpace({required this.id, required this.name});

  final String id;
  final String name;
}

/// Immutable Calendar screen state, mirroring the local React state held by
/// apps/mobile CalendarContainer.
class CalendarState {
  const CalendarState({
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.daysWithRecordings,
    required this.rawDayRecordings,
    required this.spaces,
    required this.selectedSpaceId,
    required this.isMonthLoading,
    required this.isDayLoading,
  });

  /// 0-indexed month (0 = January), matching the RN container.
  final int year;
  final int month;
  final int selectedDay;

  /// Day-of-month numbers (1–31) that have at least one recording this month.
  final Set<int> daysWithRecordings;

  /// The selected day's recordings before the space filter is applied.
  final List<CalendarRecordingCard> rawDayRecordings;

  final List<CalendarSpace> spaces;
  final String? selectedSpaceId;

  final bool isMonthLoading;
  final bool isDayLoading;

  /// The selected day's recordings after applying the active space filter.
  /// Filters on `workspaceId` (not name) so two spaces with identical names
  /// never bleed into each other's list. Ports the `filteredDayRecordings`
  /// memo from CalendarContainer.
  List<CalendarRecordingCard> get dayRecordings {
    if (selectedSpaceId == null) return rawDayRecordings;
    return rawDayRecordings
        .where((r) => r.workspaceId == selectedSpaceId)
        .toList(growable: false);
  }

  CalendarState copyWith({
    int? year,
    int? month,
    int? selectedDay,
    Set<int>? daysWithRecordings,
    List<CalendarRecordingCard>? rawDayRecordings,
    List<CalendarSpace>? spaces,
    Object? selectedSpaceId = _noChange,
    bool? isMonthLoading,
    bool? isDayLoading,
  }) {
    return CalendarState(
      year: year ?? this.year,
      month: month ?? this.month,
      selectedDay: selectedDay ?? this.selectedDay,
      daysWithRecordings: daysWithRecordings ?? this.daysWithRecordings,
      rawDayRecordings: rawDayRecordings ?? this.rawDayRecordings,
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

/// Drives the Calendar screen (S4). Offline-first: dots, day lists, and spaces
/// all read from Drift (display source). Faithful port of CalendarContainer:
///   * loadMonthDots(y, m)  → fetchDaysWithRecordings,
///   * loadDayRecordings(d) → fetchDayRecordings,
///   * loadSpaces()         → workspaces list,
///   * handleMonthChange    → always reloads BOTH dots and the day list
///     (CRITICAL-2 guard), clamping the selected day to the new month.
class CalendarController extends StateNotifier<CalendarState> {
  CalendarController(this._ref, {DateTime? now})
      : super(
          _initial(now ?? DateTime.now()),
        ) {
    _bootstrap();
  }

  final Ref _ref;

  CalendarData get _data => CalendarData(_ref.read(recordingsDaoProvider));
  WorkspacesDao get _workspacesDao => _ref.read(workspacesDaoProvider);

  static CalendarState _initial(DateTime now) {
    return CalendarState(
      year: now.year,
      month: now.month - 1, // store 0-indexed to match RN
      selectedDay: now.day,
      daysWithRecordings: const <int>{},
      rawDayRecordings: const [],
      spaces: const [],
      selectedSpaceId: null,
      isMonthLoading: false,
      isDayLoading: false,
    );
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      loadMonthDots(state.year, state.month),
      loadDayRecordings(DateTime(state.year, state.month + 1, state.selectedDay)),
      loadSpaces(),
    ]);
  }

  /// Reload the dots for [year]/[month] (0-indexed month).
  Future<void> loadMonthDots(int year, int month) async {
    if (!mounted) return;
    state = state.copyWith(isMonthLoading: true);
    try {
      final days = await _data.fetchDaysWithRecordings(year, month);
      if (!mounted) return;
      state = state.copyWith(daysWithRecordings: days);
    } catch (_) {
      // Swallow — keep whatever dots are already shown (offline-first).
    } finally {
      if (mounted) state = state.copyWith(isMonthLoading: false);
    }
  }

  /// Reload the day list for [date].
  Future<void> loadDayRecordings(DateTime date) async {
    if (!mounted) return;
    state = state.copyWith(isDayLoading: true);
    try {
      final records = await _data.fetchDayRecordings(date);
      if (!mounted) return;
      state = state.copyWith(rawDayRecordings: records);
    } catch (_) {
      if (mounted) state = state.copyWith(rawDayRecordings: const []);
    } finally {
      if (mounted) state = state.copyWith(isDayLoading: false);
    }
  }

  /// Load the space filter options from Drift (workspaces).
  Future<void> loadSpaces() async {
    try {
      final rows = await _workspacesDao.getWorkspaces();
      if (!mounted) return;
      state = state.copyWith(
        spaces: rows
            .map((w) => CalendarSpace(id: w.id, name: w.name))
            .toList(growable: false),
      );
    } catch (_) {
      // Non-fatal; the strip just shows "All" with no chips.
    }
  }

  /// Navigate to a new [year]/[month] (0-indexed). Clamps the selected day to
  /// the last day of the new month when it would overflow (e.g. Mar 31 → Feb),
  /// then ALWAYS reloads both the dots and the day list (CRITICAL-2 guard).
  Future<void> changeMonth(int year, int month) async {
    if (!mounted) return;
    final daysInNewMonth = DateTime(year, month + 2, 0).day;
    final targetDay =
        state.selectedDay > daysInNewMonth ? 1 : state.selectedDay;

    state = state.copyWith(
      year: year,
      month: month,
      selectedDay: targetDay,
    );

    await Future.wait([
      loadDayRecordings(DateTime(year, month + 1, targetDay)),
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

  /// Select [day] in the current month and load its recordings.
  Future<void> selectDay(int day) async {
    if (!mounted) return;
    state = state.copyWith(selectedDay: day);
    await loadDayRecordings(DateTime(state.year, state.month + 1, day));
  }

  /// Apply (or clear, when null) the space filter. No DB re-fetch — filtering
  /// happens in [CalendarState.dayRecordings].
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
