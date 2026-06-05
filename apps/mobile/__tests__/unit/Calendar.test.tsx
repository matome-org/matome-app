/**
 * Unit tests for Views/Calendar/Calendar.tsx
 *
 * Covers: month header rendering, day grid, day selection, month navigation,
 * recording list, empty/loading states, space filter strip, duration formatting.
 */

import React from "react";
import { render, fireEvent } from "@testing-library/react-native";
import { ApplicationProvider } from "@ui-kitten/components";
import * as eva from "@eva-design/eva";

jest.mock("react-i18next", () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}));

jest.mock("@expo/vector-icons", () => ({
  Ionicons: "Ionicons",
}));

import { Calendar } from "@/Views/Calendar/Calendar";
import type { CalendarProps } from "@/Views/Calendar/Calendar.types";

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeCard(overrides: Partial<{
  id: string;
  title: string;
  duration: number;
  badge: "Work" | "Personal" | "Inbox";
  workspaceName: string | null;
  workspaceId: string;
}> = {}) {
  return {
    id: overrides.id ?? "rec-1",
    title: overrides.title ?? "Team standup",
    duration: overrides.duration ?? 180,
    badge: overrides.badge ?? "Work",
    workspaceName: Object.prototype.hasOwnProperty.call(overrides, "workspaceName")
      ? overrides.workspaceName ?? null
      : "Engineering",
    workspaceId: overrides.workspaceId ?? "ws-1",
    createdAt: new Date(2026, 3, 10, 9, 0, 0).getTime(),
  };
}

const defaultProps: CalendarProps = {
  year: 2026,
  month: 3,
  daysWithRecordings: new Set<number>(),
  selectedDay: 10,
  onDayPress: jest.fn(),
  onMonthChange: jest.fn(),
  isMonthLoading: false,
  dayRecordings: [],
  isDayLoading: false,
  onRecordingPress: jest.fn(),
  spaces: [],
  selectedSpaceId: null,
  onSpaceFilterChange: jest.fn(),
};

function renderCalendar(props: Partial<CalendarProps> = {}) {
  return render(
    <ApplicationProvider {...eva} theme={eva.light}>
      <Calendar {...defaultProps} {...props} />
    </ApplicationProvider>
  );
}

// ---------------------------------------------------------------------------
// Month header
// ---------------------------------------------------------------------------

describe("Calendar — month header", () => {
  it("should display the correct month name and year", () => {
    const { getByText } = renderCalendar({ year: 2026, month: 3 });
    expect(getByText("April")).toBeTruthy();
    expect(getByText("2026")).toBeTruthy();
  });

  it("should display January correctly (month 0)", () => {
    const { getByText } = renderCalendar({ year: 2025, month: 0 });
    expect(getByText("January")).toBeTruthy();
    expect(getByText("2025")).toBeTruthy();
  });

  it("should display December correctly (month 11)", () => {
    const { getByText } = renderCalendar({ year: 2026, month: 11 });
    expect(getByText("December")).toBeTruthy();
    expect(getByText("2026")).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// Day grid
// ---------------------------------------------------------------------------

describe("Calendar — day grid", () => {
  it("should render all 30 days for April", () => {
    const { getByText } = renderCalendar({ year: 2026, month: 3 });
    for (let d = 1; d <= 30; d++) {
      expect(getByText(String(d))).toBeTruthy();
    }
  });

  it("should render only 28 days for February in a non-leap year", () => {
    const { getByText, queryByText } = renderCalendar({ year: 2025, month: 1 });
    expect(getByText("28")).toBeTruthy();
    expect(queryByText("29")).toBeNull();
  });

  it("should render 29 days for February in a leap year", () => {
    const { getByText } = renderCalendar({ year: 2028, month: 1 });
    expect(getByText("29")).toBeTruthy();
  });

  it("should render all 7 weekday header labels", () => {
    const { getAllByText, getByText } = renderCalendar();
    expect(getAllByText("S").length).toBeGreaterThanOrEqual(2);
    expect(getByText("M")).toBeTruthy();
    expect(getAllByText("T").length).toBeGreaterThanOrEqual(2);
    expect(getByText("W")).toBeTruthy();
    expect(getByText("F")).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// Day selection
// ---------------------------------------------------------------------------

describe("Calendar — day selection", () => {
  it("should call onDayPress with a Date object when a day is pressed", () => {
    const onDayPress = jest.fn();
    const { getByText } = renderCalendar({ onDayPress, year: 2026, month: 3 });
    fireEvent.press(getByText("15"));
    expect(onDayPress).toHaveBeenCalledTimes(1);
    const arg = onDayPress.mock.calls[0][0] as Date;
    expect(arg).toBeInstanceOf(Date);
    expect(arg.getFullYear()).toBe(2026);
    expect(arg.getMonth()).toBe(3);
    expect(arg.getDate()).toBe(15);
  });

  it("should call onDayPress with day 1 when the first day is pressed", () => {
    const onDayPress = jest.fn();
    const { getByText } = renderCalendar({ onDayPress, year: 2026, month: 3 });
    fireEvent.press(getByText("1"));
    expect((onDayPress.mock.calls[0][0] as Date).getDate()).toBe(1);
  });

  it("should call onDayPress with the last day of the month when pressed", () => {
    const onDayPress = jest.fn();
    const { getByText } = renderCalendar({ onDayPress, year: 2026, month: 3 });
    fireEvent.press(getByText("30"));
    expect((onDayPress.mock.calls[0][0] as Date).getDate()).toBe(30);
  });

  it("should construct the Date with the correct month (0-indexed)", () => {
    const onDayPress = jest.fn();
    const { getByText } = renderCalendar({ onDayPress, year: 2026, month: 0 });
    fireEvent.press(getByText("10"));
    const arg = onDayPress.mock.calls[0][0] as Date;
    expect(arg.getMonth()).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Recording list
// ---------------------------------------------------------------------------

describe("Calendar — recording list", () => {
  it("should render all recording titles", () => {
    const recordings = [
      makeCard({ id: "r1", title: "Morning sync" }),
      makeCard({ id: "r2", title: "Sprint planning" }),
    ];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("Morning sync")).toBeTruthy();
    expect(getByText("Sprint planning")).toBeTruthy();
  });

  it("should show the i18n empty-state key when there are no recordings and not loading", () => {
    const { getByText } = renderCalendar({ dayRecordings: [], isDayLoading: false });
    expect(getByText("calendar.noRecordings")).toBeTruthy();
  });

  it("should NOT show the empty-state text when isDayLoading is true", () => {
    const { queryByText } = renderCalendar({ dayRecordings: [], isDayLoading: true });
    expect(queryByText("calendar.noRecordings")).toBeNull();
  });

  it("should call onRecordingPress with the correct recording id when pressed", () => {
    const onRecordingPress = jest.fn();
    const recordings = [makeCard({ id: "rec-xyz", title: "Daily standup" })];
    const { getByText } = renderCalendar({ dayRecordings: recordings, onRecordingPress });
    fireEvent.press(getByText("Daily standup"));
    expect(onRecordingPress).toHaveBeenCalledWith("rec-xyz");
  });

  it("should display workspaceName in the badge when set", () => {
    const recordings = [makeCard({ workspaceName: "Design Team", badge: "Work" })];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("Design Team")).toBeTruthy();
  });

  it("should fall back to badge name when workspaceName is null", () => {
    const recordings = [makeCard({ workspaceName: null, badge: "Personal" })];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("Personal")).toBeTruthy();
  });

  it("should format duration 125 seconds as '2:05'", () => {
    const recordings = [makeCard({ duration: 125 })];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("2:05")).toBeTruthy();
  });

  it("should pad seconds to two digits: 65 seconds → '1:05'", () => {
    const recordings = [makeCard({ duration: 65 })];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("1:05")).toBeTruthy();
  });

  it("should format 0 seconds as '0:00'", () => {
    const recordings = [makeCard({ duration: 0 })];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("0:00")).toBeTruthy();
  });

  it("should format 59 seconds as '0:59'", () => {
    const recordings = [makeCard({ duration: 59 })];
    const { getByText } = renderCalendar({ dayRecordings: recordings });
    expect(getByText("0:59")).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// Space filter strip
// ---------------------------------------------------------------------------

describe("Calendar — space filter strip", () => {
  const spaces = [
    { id: "ws-1", name: "Engineering" },
    { id: "ws-2", name: "Design" },
  ];

  it("should render the All chip using the i18n key", () => {
    const { getByText } = renderCalendar({ spaces });
    expect(getByText("calendar.allSpaces")).toBeTruthy();
  });

  it("should render a chip for each space", () => {
    const { getByText } = renderCalendar({ spaces });
    expect(getByText("Engineering")).toBeTruthy();
    expect(getByText("Design")).toBeTruthy();
  });

  it("should call onSpaceFilterChange(null) when the All chip is pressed", () => {
    const onSpaceFilterChange = jest.fn();
    const { getByText } = renderCalendar({
      spaces,
      selectedSpaceId: "ws-1",
      onSpaceFilterChange,
    });
    fireEvent.press(getByText("calendar.allSpaces"));
    expect(onSpaceFilterChange).toHaveBeenCalledWith(null);
  });

  it("should call onSpaceFilterChange with the space id when an inactive chip is pressed", () => {
    const onSpaceFilterChange = jest.fn();
    const { getByText } = renderCalendar({
      spaces,
      selectedSpaceId: null,
      onSpaceFilterChange,
    });
    fireEvent.press(getByText("Engineering"));
    expect(onSpaceFilterChange).toHaveBeenCalledWith("ws-1");
  });

  it("should call onSpaceFilterChange(null) when the active chip is pressed again (toggle off)", () => {
    const onSpaceFilterChange = jest.fn();
    const { getByText } = renderCalendar({
      spaces,
      selectedSpaceId: "ws-1",
      onSpaceFilterChange,
    });
    fireEvent.press(getByText("Engineering"));
    expect(onSpaceFilterChange).toHaveBeenCalledWith(null);
  });

  it("should render no space chips when spaces array is empty", () => {
    const { queryByText } = renderCalendar({ spaces: [] });
    expect(queryByText("Engineering")).toBeNull();
  });
});
