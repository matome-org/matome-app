import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "expo-router";

import { fetchDaysWithRecordings, fetchDayRecordings } from "@/processes/calendarData";
import type { CalendarRecordingCard } from "@/processes/calendarData";
import { fetchSpacesData } from "@/processes/spacesData";
import { useRecordingsStore } from "@/stores/recordingsStore";

import { Calendar } from "./Calendar";

const CalendarContainer: React.FC = () => {
  const router = useRouter();
  const refreshKey = useRecordingsStore((state) => state.refreshKey);

  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth());
  const [selectedDay, setSelectedDay] = useState(now.getDate());

  const [daysWithRecordings, setDaysWithRecordings] = useState<Set<number>>(
    new Set(),
  );
  const [dayRecordings, setDayRecordings] = useState<CalendarRecordingCard[]>(
    [],
  );
  const [spaces, setSpaces] = useState<Array<{ id: string; name: string }>>([]);
  const [selectedSpaceId, setSelectedSpaceId] = useState<string | null>(null);
  const [isMonthLoading, setIsMonthLoading] = useState(false);
  const [isDayLoading, setIsDayLoading] = useState(false);

  // Raw day recordings before space filtering
  const [rawDayRecordings, setRawDayRecordings] = useState<
    CalendarRecordingCard[]
  >([]);

  // Apply space filter in state — no DB re-fetch
  const filteredDayRecordings = useMemo(() => {
    if (selectedSpaceId === null) return rawDayRecordings;
    // Filter by workspaceId so that two spaces with identical names never bleed
    // into each other's filtered list.
    return rawDayRecordings.filter((r) => r.workspaceId === selectedSpaceId);
  }, [rawDayRecordings, selectedSpaceId]);

  const loadMonthDots = useCallback(async (y: number, m: number) => {
    setIsMonthLoading(true);
    try {
      const days = await fetchDaysWithRecordings(y, m);
      setDaysWithRecordings(days);
    } catch (err) {
      console.error("CalendarContainer: loadMonthDots error", err);
    } finally {
      setIsMonthLoading(false);
    }
  }, []);

  const loadDayRecordings = useCallback(async (date: Date) => {
    setIsDayLoading(true);
    try {
      const records = await fetchDayRecordings(date);
      setRawDayRecordings(records);
    } catch (err) {
      console.error("CalendarContainer: loadDayRecordings error", err);
      setRawDayRecordings([]);
    } finally {
      setIsDayLoading(false);
    }
  }, []);

  const loadSpaces = useCallback(async () => {
    try {
      const spaceCards = await fetchSpacesData();
      setSpaces(spaceCards.map((s) => ({ id: s.id, name: s.name })));
    } catch (err) {
      console.error("CalendarContainer: loadSpaces error", err);
    }
  }, []);

  // Initial mount load
  useEffect(() => {
    const today = new Date();
    loadMonthDots(today.getFullYear(), today.getMonth());
    loadDayRecordings(today);
    loadSpaces();
  }, [loadMonthDots, loadDayRecordings, loadSpaces]);

  // Auto-refresh when a recording is saved/created
  useEffect(() => {
    if (refreshKey === 0) return; // Skip initial mount (handled above)
    loadMonthDots(year, month);
    loadDayRecordings(new Date(year, month, selectedDay));
  }, [refreshKey]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleMonthChange = useCallback(
    (newYear: number, newMonth: number) => {
      setYear(newYear);
      setMonth(newMonth);

      // Clamp selected day to the last day of the new month if necessary
      // (e.g. navigating from March to February where day 31 doesn't exist)
      const daysInNewMonth = new Date(newYear, newMonth + 1, 0).getDate();
      const targetDay = selectedDay > daysInNewMonth ? 1 : selectedDay;
      if (selectedDay > daysInNewMonth) setSelectedDay(1);

      // Always reload day recordings regardless of whether the day number is
      // valid in both months — without this, navigating e.g. April→March on
      // day 10 would leave the panel showing the previous month's recordings.
      loadDayRecordings(new Date(newYear, newMonth, targetDay));
      loadMonthDots(newYear, newMonth);
    },
    [selectedDay, loadMonthDots, loadDayRecordings],
  );

  const handleDayPress = useCallback(
    (date: Date) => {
      const day = date.getDate();
      setSelectedDay(day);
      loadDayRecordings(date);
    },
    [loadDayRecordings],
  );

  const handleRecordingPress = useCallback(
    (id: string) => {
      router.push(`/(tabs)/calendar/${id}`);
    },
    [router],
  );

  const handleSpaceFilterChange = useCallback(
    (spaceId: string | null) => {
      setSelectedSpaceId(spaceId);
    },
    [],
  );

  // Keep filtered list in sync with the derived memo
  useEffect(() => {
    setDayRecordings(filteredDayRecordings);
  }, [filteredDayRecordings]);

  return (
    <Calendar
      year={year}
      month={month}
      daysWithRecordings={daysWithRecordings}
      selectedDay={selectedDay}
      onDayPress={handleDayPress}
      onMonthChange={handleMonthChange}
      isMonthLoading={isMonthLoading}
      dayRecordings={dayRecordings}
      isDayLoading={isDayLoading}
      onRecordingPress={handleRecordingPress}
      spaces={spaces}
      selectedSpaceId={selectedSpaceId}
      onSpaceFilterChange={handleSpaceFilterChange}
    />
  );
};

export default CalendarContainer;
