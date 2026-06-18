import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import 'calendar_controller.dart';
import 'calendar_data.dart';

const List<String> _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _weekdayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> _shortMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Wide-viewport content clamp (mirrors HomeScreen).
const double _wideBreakpoint = 1000;
const double _contentMaxWidth = 720;

/// Format whole seconds as `m:ss` (the day-list duration label).
/// Mirrors the RN Calendar `formatDuration` helper.
String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Calendar tab (S4, #783). Offline-first month grid backed by Drift:
///   * dots/heat on days with recordings (byDateRange for the visible month),
///   * tap a day → that day's recordings (byDayWithWorkspace),
///   * a space filter strip (workspaces) narrows the day list,
///   * tap a recording → `/calendar/:id` (shared DetailsScreen, S2),
///   * prev/next month nav reloads the dots and the day list.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final today = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? _contentMaxWidth : double.infinity,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    year: state.year,
                    month: state.month,
                    state: state,
                    today: today,
                    onPrev: controller.prevMonth,
                    onNext: controller.nextMonth,
                    onDayPress: controller.selectDay,
                    onSpaceFilter: controller.setSpaceFilter,
                  ),
                ),
                if (state.dayRecordings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: state.isDayLoading
                        ? const _DayLoading()
                        : const _DayEmpty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    sliver: SliverList.builder(
                      itemCount: state.dayRecordings.length,
                      itemBuilder: (context, i) {
                        final item = state.dayRecordings[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecordingRow(
                            item: item,
                            onTap: () =>
                                GoRouter.of(context).go('/calendar/${item.id}'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.year,
    required this.month,
    required this.state,
    required this.today,
    required this.onPrev,
    required this.onNext,
    required this.onDayPress,
    required this.onSpaceFilter,
  });

  final int year;
  final int month;
  final CalendarState state;
  final DateTime today;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onDayPress;
  final ValueChanged<String?> onSpaceFilter;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const ValueKey('calendar-prev-month'),
                tooltip: 'Previous month',
                onPressed: onPrev,
                icon: Icon(Icons.chevron_left, color: colors.textSecondary),
              ),
              Column(
                children: [
                  Text(
                    _monthNames[month],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '$year',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
              IconButton(
                key: const ValueKey('calendar-next-month'),
                tooltip: 'Next month',
                onPressed: onNext,
                icon: Icon(Icons.chevron_right, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        // Month grid.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: _MonthGrid(
              year: year,
              month: month,
              daysWithRecordings: state.daysWithRecordings,
              selectedDay: state.selectedDay,
              today: today,
              isLoading: state.isMonthLoading,
              onDayPress: onDayPress,
            ),
          ),
        ),
        // Space filter strip.
        _SpaceFilterStrip(
          spaces: state.spaces,
          selectedSpaceId: state.selectedSpaceId,
          onSpaceFilter: onSpaceFilter,
        ),
        // Day heading.
        _DayHeading(
          year: year,
          month: month,
          selectedDay: state.selectedDay,
          count: state.dayRecordings.length,
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.month,
    required this.daysWithRecordings,
    required this.selectedDay,
    required this.today,
    required this.isLoading,
    required this.onDayPress,
  });

  final int year;
  final int month;
  final Set<int> daysWithRecordings;
  final int selectedDay;
  final DateTime today;
  final bool isLoading;
  final ValueChanged<int> onDayPress;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    // weekday(): Mon=1..Sun=7 in Dart; the RN grid is Sunday-first, so map
    // Sunday(7) -> 0, Mon(1) -> 1, ... Sat(6) -> 6.
    final firstWeekday = DateTime(year, month + 1, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 2, 0).day;
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final isCurrentMonth = today.year == year && today.month - 1 == month;

    return Column(
      children: [
        // Weekday labels.
        Row(
          children: List.generate(
            7,
            (i) => Expanded(
              child: Center(
                child: Text(
                  _weekdayLabels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Day cells.
        for (var row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final day = cellIndex - firstWeekday + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              return Expanded(
                child: _DayCell(
                  day: day,
                  hasRecording: daysWithRecordings.contains(day),
                  isSelected: day == selectedDay,
                  isToday: isCurrentMonth && day == today.day,
                  onTap: () => onDayPress(day),
                ),
              );
            }),
          ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasRecording,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool hasRecording;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    final Color background = isSelected
        ? colors.accentSoft
        : hasRecording
        ? colors.accent.withValues(alpha: 0.16)
        : Colors.transparent;

    final Color textColor = isSelected
        ? colors.textPrimary
        : isToday
        ? colors.accentDark
        : colors.textPrimary;

    return InkWell(
      key: ValueKey('calendar-day-$day'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: colors.textPrimary, width: 2)
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Recording dot.
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasRecording ? colors.accent : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceFilterStrip extends StatelessWidget {
  const _SpaceFilterStrip({
    required this.spaces,
    required this.selectedSpaceId,
    required this.onSpaceFilter,
  });

  final List<CalendarSpace> spaces;
  final String? selectedSpaceId;
  final ValueChanged<String?> onSpaceFilter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: [
          _FilterChip(
            key: const ValueKey('calendar-filter-all'),
            label: t.calendar.allSpaces,
            active: selectedSpaceId == null,
            onTap: () => onSpaceFilter(null),
          ),
          for (final space in spaces) ...[
            const SizedBox(width: 8),
            _FilterChip(
              key: ValueKey('calendar-filter-${space.id}'),
              label: space.name,
              active: selectedSpaceId == space.id,
              onTap: () =>
                  onSpaceFilter(selectedSpaceId == space.id ? null : space.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Material(
      color: active ? colors.textPrimary : colors.subtleFill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.count,
  });

  final int year;
  final int month;
  final int selectedDay;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (selectedDay <= 0) return const SizedBox.shrink();
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    final date = DateTime(year, month + 1, selectedDay);
    final label =
        '${_weekdayNames[date.weekday % 7]}, '
        '${_shortMonthNames[month]} $selectedDay';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$count ${count == 1 ? 'recording' : 'recordings'}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.item, required this.onTap});

  final CalendarRecordingCard item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    final isWork = item.badge == 'Work';
    final dotColor = isWork ? colors.accent : colors.textMuted;
    final displayName = item.workspaceName ?? item.badge;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('calendar-recording-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isWork
                                ? colors.accent.withValues(alpha: 0.13)
                                : colors.border,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isWork
                                  ? colors.accentDark
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDuration(item.duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayLoading extends StatelessWidget {
  const _DayLoading();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}

class _DayEmpty extends StatelessWidget {
  const _DayEmpty();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 32,
              color: colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              t.calendar.noRecordings,
              style: TextStyle(fontSize: 14, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
