import { Dimensions, StyleSheet } from "react-native";

const { width: SCREEN_WIDTH } = Dimensions.get("window");

export const CELL_SIZE = Math.floor(SCREEN_WIDTH / 7);

export const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  // Month navigation header
  monthHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  monthTitle: {
    fontSize: 17,
    fontWeight: "600",
  },
  navButton: {
    padding: 8,
  },
  // Day-of-week header row
  weekdayRow: {
    flexDirection: "row",
  },
  weekdayCell: {
    width: CELL_SIZE,
    alignItems: "center",
    paddingVertical: 6,
  },
  weekdayLabel: {
    fontSize: 11,
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  // Grid
  gridRow: {
    flexDirection: "row",
  },
  dayCell: {
    width: CELL_SIZE,
    height: CELL_SIZE,
    alignItems: "center",
    justifyContent: "center",
  },
  dayCellInner: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: "center",
    justifyContent: "center",
  },
  dayNumber: {
    fontSize: 15,
    fontWeight: "400",
  },
  dayNumberSelected: {
    fontWeight: "700",
  },
  // Dot indicator for days with recordings
  recordingDot: {
    width: 5,
    height: 5,
    borderRadius: 2.5,
    position: "absolute",
    bottom: 4,
  },
  // Today underline (when not selected)
  todayUnderline: {
    position: "absolute",
    bottom: 3,
    width: 16,
    height: 2,
    borderRadius: 1,
  },
  // Space filter strip
  filterStrip: {
    flexDirection: "row",
    paddingHorizontal: 16,
    paddingVertical: 8,
    gap: 8,
  },
  filterChip: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    borderWidth: 1,
  },
  filterChipText: {
    fontSize: 13,
    fontWeight: "600",
  },
  // Day recordings list
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 24,
  },
  recordingItem: {
    borderRadius: 8,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  recordingInfo: {
    flex: 1,
    minWidth: 0,
  },
  recordingTitle: {
    fontSize: 15,
    fontWeight: "600",
  },
  recordingMeta: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    marginTop: 4,
  },
  // Badge pill — mirrors Home.styles badge
  badge: {
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: "600",
  },
  durationText: {
    fontSize: 12,
  },
  // Empty state
  emptyContainer: {
    alignItems: "center",
    justifyContent: "center",
    paddingTop: 32,
    gap: 8,
  },
  emptyText: {
    fontSize: 15,
  },
  // Loading overlay for day list
  loadingContainer: {
    paddingTop: 32,
    alignItems: "center",
  },
  // Separator between grid and list
  divider: {
    height: 1,
    marginHorizontal: 16,
    marginBottom: 4,
  },
});
