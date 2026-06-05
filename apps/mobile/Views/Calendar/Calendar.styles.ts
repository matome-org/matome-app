import { Dimensions, StyleSheet } from "react-native";

const { width: SCREEN_WIDTH } = Dimensions.get("window");

// 7 cells across the grid card (16px margin each side + 14px padding each side)
export const CELL_SIZE = Math.floor((SCREEN_WIDTH - 32 - 28) / 7);

export const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  listContent: {
    paddingBottom: 100,
  },
  // Month navigation
  monthHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 8,
  },
  monthTitle: {
    fontSize: 22,
    fontWeight: "700",
    letterSpacing: -0.4,
    textAlign: "center",
  },
  yearLabel: {
    fontSize: 13,
    textAlign: "center",
    marginTop: 1,
  },
  navButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
  },
  // Heatmap grid card
  gridCard: {
    marginHorizontal: 16,
    borderRadius: 16,
    borderWidth: 1,
    padding: 14,
  },
  weekdayRow: {
    flexDirection: "row",
    marginBottom: 4,
  },
  weekdayCell: {
    width: CELL_SIZE,
    alignItems: "center",
    paddingVertical: 4,
  },
  weekdayLabel: {
    fontSize: 10,
    fontWeight: "700",
    letterSpacing: 0.5,
  },
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
    width: CELL_SIZE - 4,
    height: CELL_SIZE - 4,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 8,
  },
  dayNumber: {
    fontSize: 12,
  },
  dayNumberSelected: {
    fontWeight: "700",
  },
  recordingDot: {
    width: 5,
    height: 5,
    borderRadius: 2.5,
    position: "absolute",
    bottom: 4,
  },
  todayUnderline: {
    position: "absolute",
    bottom: 2,
    width: 12,
    height: 2,
    borderRadius: 1,
  },
  // Heatmap legend
  legendRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-end",
    gap: 4,
    marginTop: 10,
  },
  legendLabel: {
    fontSize: 10,
  },
  legendDot: {
    width: 11,
    height: 11,
    borderRadius: 3,
  },
  // Space filter
  filterStrip: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  filterChip: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 999,
  },
  filterChipText: {
    fontSize: 13,
    fontWeight: "600",
  },
  // Day heading
  dayHeading: {
    paddingHorizontal: 20,
    paddingBottom: 10,
  },
  dayHeadingText: {
    fontSize: 18,
    fontWeight: "700",
  },
  dayCountText: {
    fontSize: 12,
    marginTop: 2,
  },
  // Recording items
  recordingItem: {
    borderRadius: 14,
    padding: 14,
    marginHorizontal: 16,
    marginBottom: 8,
    borderWidth: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  timelineDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    flexShrink: 0,
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
    marginTop: 5,
  },
  badge: {
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: "600",
  },
  durationText: {
    fontSize: 12,
  },
  emptyContainer: {
    alignItems: "center",
    justifyContent: "center",
    paddingTop: 32,
    gap: 8,
  },
  emptyText: {
    fontSize: 15,
  },
  loadingContainer: {
    paddingTop: 32,
    alignItems: "center",
  },
  divider: {
    height: 1,
    marginHorizontal: 16,
    marginBottom: 4,
  },
});
