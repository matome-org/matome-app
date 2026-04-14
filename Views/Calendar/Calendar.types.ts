import type { CalendarRecordingCard } from "@/processes/calendarData";

export type { CalendarRecordingCard };

export type CalendarProps = {
  // Month grid
  year: number;
  month: number; // 0-indexed (0 = January)
  daysWithRecordings: Set<number>;
  selectedDay: number;
  onDayPress: (date: Date) => void;
  onMonthChange: (year: number, month: number) => void;
  isMonthLoading: boolean;

  // Day recordings list
  dayRecordings: CalendarRecordingCard[];
  isDayLoading: boolean;
  onRecordingPress: (id: string) => void;

  // Space filter
  spaces: Array<{ id: string; name: string }>;
  selectedSpaceId: string | null;
  onSpaceFilterChange: (spaceId: string | null) => void;
};
