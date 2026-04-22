import React, { useMemo } from "react";
import {
  ActivityIndicator,
  FlatList,
  ScrollView,
  TouchableOpacity,
  View,
} from "react-native";
import { Layout, Text, useTheme } from "@ui-kitten/components";
import { Ionicons } from "@expo/vector-icons";
import { useTranslation } from "react-i18next";

import { styles, CELL_SIZE } from "./Calendar.styles";
import type { CalendarProps, CalendarRecordingCard } from "./Calendar.types";

const WEEKDAY_LABELS = ["S", "M", "T", "W", "T", "F", "S"];

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

const ACCENT = "#E1B346";
const ACCENT_SOFT = "#F6E8C0";

const formatDuration = (seconds: number): string => {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
};

type DayCell =
  | { type: "empty"; key: string }
  | { type: "day"; day: number; key: string };

function buildGridCells(year: number, month: number): DayCell[] {
  const firstDayOfWeek = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const cells: DayCell[] = [];
  for (let i = 0; i < firstDayOfWeek; i++) {
    cells.push({ type: "empty", key: `empty-pre-${i}` });
  }
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ type: "day", day: d, key: `day-${d}` });
  }
  const remainder = cells.length % 7;
  if (remainder !== 0) {
    for (let i = 0; i < 7 - remainder; i++) {
      cells.push({ type: "empty", key: `empty-post-${i}` });
    }
  }
  return cells;
}

interface MonthGridProps {
  year: number;
  month: number;
  recordingCounts: Map<number, number>;
  selectedDay: number;
  today: { year: number; month: number; day: number };
  onDayPress: (day: number) => void;
  isLoading: boolean;
}

const MonthGrid: React.FC<MonthGridProps> = ({
  year,
  month,
  recordingCounts,
  selectedDay,
  today,
  onDayPress,
  isLoading,
}) => {
  const theme = useTheme();
  const cells = useMemo(() => buildGridCells(year, month), [year, month]);

  const rows: DayCell[][] = [];
  for (let i = 0; i < cells.length; i += 7) {
    rows.push(cells.slice(i, i + 7));
  }

  return (
    <View>
      {/* Weekday labels */}
      <View style={styles.weekdayRow}>
        {WEEKDAY_LABELS.map((label, i) => (
          <View key={i} style={styles.weekdayCell}>
            <Text style={[styles.weekdayLabel, { color: theme["color-basic-500"] }]}>
              {label}
            </Text>
          </View>
        ))}
      </View>

      {/* Day cells — heatmap */}
      {rows.map((row, rowIndex) => (
        <View key={rowIndex} style={styles.gridRow}>
          {row.map((cell) => {
            if (cell.type === "empty") {
              return <View key={cell.key} style={styles.dayCell} />;
            }

            const { day } = cell;
            const count = recordingCounts.get(day) ?? 0;
            const isSelected = day === selectedDay;
            const isToday =
              year === today.year &&
              month === today.month &&
              day === today.day;

            // Heatmap alpha: 0 count → transparent, 1 → 0.22, 2 → 0.44, 3+ → 0.66+
            const heatAlpha = count === 0 ? 0 : Math.min(0.18 + count * 0.22, 0.9);
            const heatBg =
              count > 0
                ? `rgba(225, 179, 70, ${heatAlpha})`
                : "transparent";

            return (
              <TouchableOpacity
                key={cell.key}
                style={styles.dayCell}
                onPress={() => onDayPress(day)}
                activeOpacity={0.7}
              >
                <View
                  style={[
                    styles.dayCellInner,
                    count > 0 && { backgroundColor: heatBg, borderRadius: 8 },
                    isSelected && {
                      borderWidth: 2,
                      borderColor: theme["color-basic-800"],
                      backgroundColor: heatBg,
                    },
                  ]}
                >
                  <Text
                    style={[
                      styles.dayNumber,
                      {
                        color: isSelected
                          ? theme["color-basic-800"]
                          : isToday
                          ? ACCENT
                          : count >= 3
                          ? theme["color-basic-800"]
                          : theme["color-basic-700"],
                        fontWeight: isSelected || isToday ? "700" : "400",
                      },
                    ]}
                  >
                    {day}
                  </Text>
                </View>

                {/* Today underline (when not selected) */}
                {isToday && !isSelected && (
                  <View
                    style={[styles.todayUnderline, { backgroundColor: ACCENT }]}
                  />
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      ))}

      {/* Heatmap legend */}
      <View style={styles.legendRow}>
        <Text style={[styles.legendLabel, { color: theme["color-basic-500"] }]}>
          fewer
        </Text>
        {[0.18, 0.4, 0.62, 0.84].map((a) => (
          <View
            key={a}
            style={[
              styles.legendDot,
              { backgroundColor: `rgba(225,179,70,${a})` },
            ]}
          />
        ))}
        <Text style={[styles.legendLabel, { color: theme["color-basic-500"] }]}>
          more
        </Text>
      </View>

      {isLoading && (
        <View style={{ paddingVertical: 4, alignItems: "center" }}>
          <ActivityIndicator size="small" color={ACCENT} />
        </View>
      )}
    </View>
  );
};

interface RecordingRowProps {
  item: CalendarRecordingCard;
  onPress: (id: string) => void;
}

const RecordingRow: React.FC<RecordingRowProps> = ({ item, onPress }) => {
  const theme = useTheme();

  const isWork = item.badge === "Work";
  const badgeBg = isWork ? ACCENT + "22" : theme["color-basic-300"];
  const badgeColor = isWork ? "#B98A1F" : theme["color-basic-600"];
  const dotColor = isWork ? ACCENT : theme["color-basic-500"];
  const displayName = item.workspaceName ?? item.badge;

  return (
    <TouchableOpacity
      style={[
        styles.recordingItem,
        {
          backgroundColor: theme["color-basic-100"],
          borderColor: theme["color-basic-400"],
        },
      ]}
      onPress={() => onPress(item.id)}
      activeOpacity={0.75}
    >
      {/* Timeline dot */}
      <View
        style={[styles.timelineDot, { backgroundColor: dotColor }]}
      />
      <View style={styles.recordingInfo}>
        <Text
          style={[styles.recordingTitle, { color: theme["color-basic-800"] }]}
          numberOfLines={1}
        >
          {item.title}
        </Text>
        <View style={styles.recordingMeta}>
          <View style={[styles.badge, { backgroundColor: badgeBg }]}>
            <Text style={[styles.badgeText, { color: badgeColor }]}>
              {displayName}
            </Text>
          </View>
          <Text style={[styles.durationText, { color: theme["color-basic-600"] }]}>
            {formatDuration(item.duration)}
          </Text>
        </View>
      </View>
      <Ionicons
        name="chevron-forward"
        size={16}
        color={theme["color-basic-500"]}
      />
    </TouchableOpacity>
  );
};

export const Calendar: React.FC<CalendarProps> = ({
  year,
  month,
  daysWithRecordings,
  selectedDay,
  onDayPress,
  onMonthChange,
  isMonthLoading,
  dayRecordings,
  isDayLoading,
  onRecordingPress,
  spaces,
  selectedSpaceId,
  onSpaceFilterChange,
}) => {
  const theme = useTheme();
  const { t } = useTranslation();

  const todayDate = new Date();
  const today = {
    year: todayDate.getFullYear(),
    month: todayDate.getMonth(),
    day: todayDate.getDate(),
  };

  const handlePrevMonth = () => {
    if (month === 0) onMonthChange(year - 1, 11);
    else onMonthChange(year, month - 1);
  };

  const handleNextMonth = () => {
    if (month === 11) onMonthChange(year + 1, 0);
    else onMonthChange(year, month + 1);
  };

  const handleDayPress = (day: number) => {
    onDayPress(new Date(year, month, day));
  };

  // Build a count map from daysWithRecordings (Set<number>)
  // CalendarContainer provides a Set, but we need counts for heatmap.
  // Derive counts from dayRecordings if on selected day, otherwise
  // just use presence (count=1 for any day with recordings).
  const recordingCounts = useMemo(() => {
    const map = new Map<number, number>();
    daysWithRecordings.forEach((d) => map.set(d, 1));
    // Boost the selected day count based on actual recordings
    if (selectedDay > 0 && dayRecordings.length > 0) {
      map.set(selectedDay, dayRecordings.length);
    }
    return map;
  }, [daysWithRecordings, selectedDay, dayRecordings.length]);

  const selectedDayLabel = useMemo(() => {
    if (!selectedDay) return null;
    const d = new Date(year, month, selectedDay);
    return d.toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" });
  }, [year, month, selectedDay]);

  const ListHeader = (
    <View>
      {/* Month navigation */}
      <View style={styles.monthHeader}>
        <TouchableOpacity
          style={styles.navButton}
          onPress={handlePrevMonth}
          activeOpacity={0.6}
        >
          <Ionicons name="chevron-back-outline" size={22} color={theme["color-basic-700"]} />
        </TouchableOpacity>
        <View>
          <Text style={[styles.monthTitle, { color: theme["color-basic-800"] }]}>
            {MONTH_NAMES[month]}
          </Text>
          <Text style={[styles.yearLabel, { color: theme["color-basic-600"] }]}>
            {year}
          </Text>
        </View>
        <TouchableOpacity
          style={styles.navButton}
          onPress={handleNextMonth}
          activeOpacity={0.6}
        >
          <Ionicons name="chevron-forward-outline" size={22} color={theme["color-basic-700"]} />
        </TouchableOpacity>
      </View>

      {/* Heatmap grid */}
      <View
        style={[
          styles.gridCard,
          {
            backgroundColor: theme["color-basic-100"],
            borderColor: theme["color-basic-400"],
          },
        ]}
      >
        <MonthGrid
          year={year}
          month={month}
          recordingCounts={recordingCounts}
          selectedDay={selectedDay}
          today={today}
          onDayPress={handleDayPress}
          isLoading={isMonthLoading}
        />
      </View>

      {/* Space filter chips */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.filterStrip}
        contentContainerStyle={{ gap: 8, paddingRight: 16 }}
      >
        <TouchableOpacity
          style={[
            styles.filterChip,
            {
              backgroundColor:
                selectedSpaceId === null
                  ? theme["color-basic-800"]
                  : "rgba(14,15,16,0.04)",
              borderColor: "transparent",
            },
          ]}
          onPress={() => onSpaceFilterChange(null)}
          activeOpacity={0.7}
        >
          <Text
            style={[
              styles.filterChipText,
              {
                color: selectedSpaceId === null ? "#fff" : theme["color-basic-700"],
              },
            ]}
          >
            {t("calendar.allSpaces")}
          </Text>
        </TouchableOpacity>

        {spaces.map((space) => {
          const isActive = selectedSpaceId === space.id;
          return (
            <TouchableOpacity
              key={space.id}
              style={[
                styles.filterChip,
                {
                  backgroundColor: isActive
                    ? theme["color-basic-800"]
                    : "rgba(14,15,16,0.04)",
                  borderColor: "transparent",
                },
              ]}
              onPress={() => onSpaceFilterChange(isActive ? null : space.id)}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.filterChipText,
                  {
                    color: isActive ? "#fff" : theme["color-basic-700"],
                  },
                ]}
              >
                {space.name}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>

      {/* Day heading */}
      {selectedDayLabel && (
        <View style={styles.dayHeading}>
          <Text style={[styles.dayHeadingText, { color: theme["color-basic-800"] }]}>
            {selectedDayLabel}
          </Text>
          {dayRecordings.length > 0 && (
            <Text style={[styles.dayCountText, { color: theme["color-basic-600"] }]}>
              {dayRecordings.length} {dayRecordings.length === 1 ? "recording" : "recordings"}
            </Text>
          )}
        </View>
      )}
    </View>
  );

  const ListEmpty = isDayLoading ? (
    <View style={styles.loadingContainer}>
      <ActivityIndicator size="small" color={ACCENT} />
    </View>
  ) : (
    <View style={styles.emptyContainer}>
      <Ionicons name="calendar-outline" size={32} color={theme["color-basic-400"]} />
      <Text style={[styles.emptyText, { color: theme["color-basic-500"] }]}>
        {t("calendar.noRecordings")}
      </Text>
    </View>
  );

  return (
    <Layout style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}>
      <FlatList
        data={dayRecordings}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <RecordingRow item={item} onPress={onRecordingPress} />
        )}
        ListHeaderComponent={ListHeader}
        ListEmptyComponent={ListEmpty}
        contentContainerStyle={styles.listContent}
        showsVerticalScrollIndicator={false}
      />
    </Layout>
  );
};
