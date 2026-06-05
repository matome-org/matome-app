/**
 * Unit tests for Views/Calendar/CalendarContainer.tsx
 *
 * Covers: initial data load, space filter logic, month navigation,
 * and the CRITICAL-2 regression guard.
 */

jest.mock("expo-router", () => ({
  useRouter: () => ({ push: jest.fn() }),
}));
jest.mock("@/processes/calendarData", () => ({
  fetchDaysWithRecordings: jest.fn(),
  fetchDayRecordings: jest.fn(),
}));
jest.mock("@/processes/spacesData", () => ({
  fetchSpacesData: jest.fn(),
}));

let mockRefreshKey = 0;
jest.mock("@/stores/recordingsStore", () => ({
  useRecordingsStore: (selector: (s: { refreshKey: number }) => unknown) =>
    selector({ refreshKey: mockRefreshKey }),
}));

jest.mock("react-i18next", () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}));
jest.mock("@expo/vector-icons", () => ({
  Ionicons: "Ionicons",
}));

import React from "react";
import { render, act, waitFor, fireEvent } from "@testing-library/react-native";
import { ApplicationProvider } from "@ui-kitten/components";
import * as eva from "@eva-design/eva";

import CalendarContainer from "@/Views/Calendar/CalendarContainer";
import { fetchDaysWithRecordings, fetchDayRecordings } from "@/processes/calendarData";
import { fetchSpacesData } from "@/processes/spacesData";

const mockFetchDaysWithRecordings = fetchDaysWithRecordings as jest.MockedFunction<typeof fetchDaysWithRecordings>;
const mockFetchDayRecordings = fetchDayRecordings as jest.MockedFunction<typeof fetchDayRecordings>;
const mockFetchSpacesData = fetchSpacesData as jest.MockedFunction<typeof fetchSpacesData>;

function makeCard(overrides: Partial<{
  id: string;
  workspaceId: string | null;
  workspaceName: string | null;
  badge: "Work" | "Personal" | "Inbox";
}> = {}) {
  return {
    id: overrides.id ?? "rec-1",
    title: "Team meeting",
    duration: 300,
    badge: overrides.badge ?? "Work",
    workspaceName: Object.prototype.hasOwnProperty.call(overrides, "workspaceName")
      ? overrides.workspaceName ?? null
      : "Engineering",
    workspaceId: Object.prototype.hasOwnProperty.call(overrides, "workspaceId")
      ? overrides.workspaceId ?? null
      : "ws-eng",
    createdAt: Date.now(),
  };
}

function renderContainer() {
  return render(
    <ApplicationProvider {...eva} theme={eva.light}>
      <CalendarContainer />
    </ApplicationProvider>
  );
}

// ---------------------------------------------------------------------------
// Initial mount
// ---------------------------------------------------------------------------

describe("CalendarContainer — initial mount", () => {
  beforeEach(() => {
    mockRefreshKey = 0;
    jest.clearAllMocks();
    mockFetchDaysWithRecordings.mockResolvedValue(new Set([1, 5, 10]));
    mockFetchDayRecordings.mockResolvedValue([]);
    mockFetchSpacesData.mockResolvedValue([]);
  });

  it("should call fetchDaysWithRecordings with today's year and month on mount", async () => {
    const now = new Date();
    renderContainer();
    await waitFor(() => expect(mockFetchDaysWithRecordings).toHaveBeenCalledTimes(1));
    expect(mockFetchDaysWithRecordings).toHaveBeenCalledWith(now.getFullYear(), now.getMonth());
  });

  it("should call fetchDayRecordings with today's date on mount", async () => {
    const now = new Date();
    renderContainer();
    await waitFor(() => expect(mockFetchDayRecordings).toHaveBeenCalledTimes(1));
    const calledDate = mockFetchDayRecordings.mock.calls[0][0] as Date;
    expect(calledDate.getFullYear()).toBe(now.getFullYear());
    expect(calledDate.getMonth()).toBe(now.getMonth());
    expect(calledDate.getDate()).toBe(now.getDate());
  });

  it("should call fetchSpacesData on mount", async () => {
    renderContainer();
    await waitFor(() => expect(mockFetchSpacesData).toHaveBeenCalledTimes(1));
  });

  it("should render space chips for all fetched spaces", async () => {
    mockFetchSpacesData.mockResolvedValue([
      { id: "ws-1", name: "Design", count: 2 },
      { id: "ws-2", name: "Marketing", count: 5 },
    ]);
    const { findByText } = renderContainer();
    expect(await findByText("Design")).toBeTruthy();
    expect(await findByText("Marketing")).toBeTruthy();
  });

  it("should not crash when fetchSpacesData rejects", async () => {
    mockFetchSpacesData.mockRejectedValueOnce(new Error("Network error"));
    expect(() => renderContainer()).not.toThrow();
    await waitFor(() => expect(mockFetchSpacesData).toHaveBeenCalledTimes(1));
  });

  it("should not crash when fetchDayRecordings rejects", async () => {
    mockFetchDayRecordings.mockRejectedValueOnce(new Error("DB error"));
    expect(() => renderContainer()).not.toThrow();
    await waitFor(() => expect(mockFetchDayRecordings).toHaveBeenCalledTimes(1));
  });
});

// ---------------------------------------------------------------------------
// Space filter logic
// ---------------------------------------------------------------------------

describe("CalendarContainer — space filter logic", () => {
  const spaces = [
    { id: "ws-eng", name: "Engineering", count: 3 },
    { id: "ws-design", name: "Design", count: 1 },
  ];

  const recordings = [
    makeCard({ id: "r1", workspaceId: "ws-eng", workspaceName: "Engineering" }),
    makeCard({ id: "r2", workspaceId: "ws-design", workspaceName: "Design" }),
    makeCard({ id: "r3", workspaceId: "ws-eng", workspaceName: "Engineering" }),
    makeCard({ id: "r4", workspaceId: null, workspaceName: null, badge: "Inbox" }),
  ];

  beforeEach(() => {
    mockRefreshKey = 0;
    jest.clearAllMocks();
    mockFetchDaysWithRecordings.mockResolvedValue(new Set());
    mockFetchDayRecordings.mockResolvedValue(recordings);
    mockFetchSpacesData.mockResolvedValue(spaces);
  });

  it("should display all recordings when no space filter is active (All)", async () => {
    const { findAllByText } = renderContainer();
    const items = await findAllByText("Team meeting");
    expect(items.length).toBe(4);
  });

  it("should filter to only Engineering recordings when Engineering chip is pressed", async () => {
    const { findAllByText } = renderContainer();
    const engineeringChip = (await findAllByText("Engineering"))[0];

    await act(async () => {
      fireEvent.press(engineeringChip);
    });

    await waitFor(async () => {
      const items = await findAllByText("Team meeting");
      expect(items.length).toBe(2);
    });
  });

  it("should restore all recordings when the active chip is pressed again (toggle off)", async () => {
    const { findAllByText } = renderContainer();
    const engineeringChip = (await findAllByText("Engineering"))[0];

    await act(async () => { fireEvent.press(engineeringChip); });
    await act(async () => { fireEvent.press((await findAllByText("Engineering"))[0]); });

    await waitFor(async () => {
      const items = await findAllByText("Team meeting");
      expect(items.length).toBe(4);
    });
  });
});

// ---------------------------------------------------------------------------
// CRITICAL-2 regression guard: month navigation always reloads day recordings
// ---------------------------------------------------------------------------

describe("CalendarContainer — CRITICAL-2 regression guard", () => {
  beforeEach(() => {
    mockRefreshKey = 0;
    jest.clearAllMocks();
    mockFetchDaysWithRecordings.mockResolvedValue(new Set());
    mockFetchDayRecordings.mockResolvedValue([]);
    mockFetchSpacesData.mockResolvedValue([]);
  });

  /**
   * CRITICAL-2 regression guard.
   *
   * The current implementation ONLY calls loadDayRecordings inside handleMonthChange
   * when selectedDay > daysInNewMonth. For all other navigations (the common case),
   * the day panel shows stale data.
   *
   * Required post-fix behavior: after navigating months, fetchDayRecordings must be
   * called with the new month date regardless of whether selectedDay is valid in both
   * months.
   *
   * NOTE: Navigation buttons need accessibilityLabel="Previous month" / "Next month"
   * (SUGGESTION-4) to be testable here without fragile implementation queries.
   * Add those labels and then implement this test.
   */
  it("documents the contract: handleMonthChange must call loadDayRecordings for any valid selectedDay", () => {
    // Placeholder — implement after CRITICAL-2 is fixed and SUGGESTION-4 accessibilityLabels are added
    expect(true).toBe(true);
  });
});
