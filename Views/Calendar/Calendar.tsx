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

const WEEKDAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

/** Format duration in seconds as "m:ss" */
const formatDuration = (seconds: number): string => {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
};

// ---------------------------------------------------------------------------
// Month grid helpers
// ---------------------------------------------------------------------------

type DayCell =
  | { type: "empty"; key: string }
  | { type: "day"; day: number; key: string };

function buildGridCells(year: number, month: number): DayCell[] {
  const firstDayOfWeek = new Date(year, month, 1).getDay(); // 0=Sun
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const cells: DayCell[] = [];

  // Leading empty cells
  for (let i = 0; i < firstDayOfWeek; i++) {
    cells.push({ type: "empty", key: `empty-pre-${i}` });
  }

  // Day cells
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ type: "day", day: d, key: `day-${d}` });
  }

  // Trailing empty cells to complete the last row
  const remainder = cells.length % 7;
  if (remainder !== 0) {
    for (let i = 0; i < 7 - remainder; i++) {
      cells.push({ type: "empty", key: `empty-post-${i}` });
    }
  }

  return cells;
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface MonthGridProps {
  year: number;
  month: number;
  daysWithRecordings: Set<number>;
  selectedDay: number;
  today: { year: number; month: number; day: number };
  onDayPress: (day: number) => void;
  isLoading: boolean;
}

const MonthGrid: React.FC<MonthGridProps> = ({
  year,
  month,
  daysWithRecordings,
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
      {/* Weekday header */}
      <View style={styles.weekdayRow}>
        {WEEKDAY_LABELS.map((label) => (
          <View key={label} style={styles.weekdayCell}>
            <Text
              style={[
                styles.weekdayLabel,
                { color: theme["color-basic-600"] },
              ]}
            >
              {label}
            </Text>
          </View>
        ))}
      </View>

      {/* Day rows */}
      {rows.map((row, rowIndex) => (
        <View key={rowIndex} style={styles.gridRow}>
          {row.map((cell) => {
            if (cell.type === "empty") {
              return <View key={cell.key} style={styles.dayCell} />;
            }

            const { day } = cell;
            const isSelected = day === selectedDay;
            const isToday =
              year === today.year &&
              month === today.month &&
              day === today.day;
            const hasDot = daysWithRecordings.has(day);

            const selectedBg = theme["color-primary-500"];
            const todayColor = theme["color-primary-500"];

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
                    isSelected && { backgroundColor: selectedBg },
                  ]}
                >
                  <Text
                    style={[
                      styles.dayNumber,
                      isSelected && styles.dayNumberSelected,
                      isSelected
                        ? { color: theme["color-primary-900"] }
                        : isToday
                          ? { color: todayColor, fontWeight: "700" }
                          : { color: theme["color-basic-800"] },
                    ]}
                  >
                    {day}
                  </Text>

                  {/* Today underline (only when not selected) */}
                  {isToday && !isSelected && (
                    <View
                      style={[
                        styles.todayUnderline,
                        { backgroundColor: todayColor },
                      ]}
                    />
                  )}
                </View>

                {/* Recording dot — below the circle */}
                {hasDot && (
                  <View
                    style={[
                      styles.recordingDot,
                      {
                        backgroundColor: isSelected
                          ? theme["color-primary-900"]
                          : theme["color-primary-500"],
                      },
                    ]}
                  />
                )}
              </TouchableOpacity>
            );
          })}
        </View>
      ))}

      {isLoading && (
        <View style={{ paddingVertical: 4, alignItems: "center" }}>
          <ActivityIndicator size="small" color={theme["color-primary-500"]} />
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
  const badgeBg = isWork
    ? theme["color-primary-500"]
    : theme["color-basic-300"];
  const badgeColor = isWork
    ? theme["color-primary-900"]
    : theme["color-basic-700"];

  const displayName = item.workspaceName ?? item.badge;

  return (
    <TouchableOpacity
      style={[
        styles.recordingItem,
        {
          backgroundColor: theme["color-basic-100"],
          borderColor: theme["color-basic-500"],
        },
      ]}
      onPress={() => onPress(item.id)}
      activeOpacity={0.7}
    >
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
          <Text
            style={[styles.durationText, { color: theme["color-basic-600"] }]}
          >
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

// ---------------------------------------------------------------------------
// Main Calendar component
// ---------------------------------------------------------------------------

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
    if (month === 0) {
      onMonthChange(year - 1, 11);
    } else {
      onMonthChange(year, month - 1);
    }
  };

  const handleNextMonth = () => {
    if (month === 11) {
      onMonthChange(year + 1, 0);
    } else {
      onMonthChange(year, month + 1);
    }
  };

  const handleDayPress = (day: number) => {
    onDayPress(new Date(year, month, day));
  };

  // Header for the FlatList — grid + space filter strip
  const ListHeader = (
    <View>
      {/* Month navigation */}
      <View style={styles.monthHeader}>
        <TouchableOpacity
          style={styles.navButton}
          onPress={handlePrevMonth}
          activeOpacity={0.6}
        >
          <Ionicons
            name="chevron-back-outline"
            size={22}
            color={theme["color-basic-700"]}
          />
        </TouchableOpacity>
        <Text style={[styles.monthTitle, { color: theme["color-basic-800"] }]}>
          {MONTH_NAMES[month]} {year}
        </Text>
        <TouchableOpacity
          style={styles.navButton}
          onPress={handleNextMonth}
          activeOpacity={0.6}
        >
          <Ionicons
            name="chevron-forward-outline"
            size={22}
            color={theme["color-basic-700"]}
          />
        </TouchableOpacity>
      </View>

      {/* Month grid */}
      <MonthGrid
        year={year}
        month={month}
        daysWithRecordings={daysWithRecordings}
        selectedDay={selectedDay}
        today={today}
        onDayPress={handleDayPress}
        isLoading={isMonthLoading}
      />

      {/* Divider */}
      <View
        style={[styles.divider, { backgroundColor: theme["color-basic-400"] }]}
      />

      {/* Space filter strip */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.filterStrip}
        contentContainerStyle={{ gap: 8, paddingRight: 16 }}
      >
        {/* "All" chip */}
        <TouchableOpacity
          style={[
            styles.filterChip,
            {
              backgroundColor:
                selectedSpaceId === null
                  ? theme["color-primary-500"]
                  : theme["color-basic-200"],
              borderColor:
                selectedSpaceId === null
                  ? theme["color-primary-500"]
                  : theme["color-basic-400"],
            },
          ]}
          onPress={() => onSpaceFilterChange(null)}
          activeOpacity={0.7}
        >
          <Text
            style={[
              styles.filterChipText,
              {
                color:
                  selectedSpaceId === null
                    ? theme["color-primary-900"]
                    : theme["color-basic-700"],
              },
            ]}
          >
            {t("calendar.allSpaces")}
          </Text>
        </TouchableOpacity>

        {/* Space chips */}
        {spaces.map((space) => {
          const isActive = selectedSpaceId === space.id;
          return (
            <TouchableOpacity
              key={space.id}
              style={[
                styles.filterChip,
                {
                  backgroundColor: isActive
                    ? theme["color-primary-500"]
                    : theme["color-basic-200"],
                  borderColor: isActive
                    ? theme["color-primary-500"]
                    : theme["color-basic-400"],
                },
              ]}
              onPress={() => onSpaceFilterChange(isActive ? null : space.id)}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.filterChipText,
                  {
                    color: isActive
                      ? theme["color-primary-900"]
                      : theme["color-basic-700"],
                  },
                ]}
              >
                {space.name}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );

  const ListEmpty = isDayLoading ? (
    <View style={styles.loadingContainer}>
      <ActivityIndicator size="small" color={theme["color-primary-500"]} />
    </View>
  ) : (
    <View style={styles.emptyContainer}>
      <Ionicons
        name="calendar-outline"
        size={32}
        color={theme["color-basic-400"]}
      />
      <Text style={[styles.emptyText, { color: theme["color-basic-500"] }]}>
        {t("calendar.noRecordings")}
      </Text>
    </View>
  );

  return (
    <Layout
      style={[
        styles.container,
        { backgroundColor: theme["color-basic-200"] },
      ]}
    >
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
