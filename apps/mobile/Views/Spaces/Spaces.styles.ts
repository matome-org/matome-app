import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 100,
  },
  // Header
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    paddingHorizontal: 20,
    paddingBottom: 12,
  },
  title: {
    fontSize: 28,
    fontWeight: "700",
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 13,
    marginTop: 2,
  },
  addBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 6,
  },
  // Section labels
  sectionHeader: {
    paddingHorizontal: 20,
    paddingTop: 4,
    paddingBottom: 8,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1.2,
  },
  // Smart spaces horizontal rail
  smartRail: {
    paddingHorizontal: 16,
    gap: 10,
    paddingBottom: 16,
  },
  smartCard: {
    width: 110,
    borderRadius: 14,
    padding: 12,
    gap: 10,
    borderWidth: 1,
  },
  smartIcon: {
    width: 30,
    height: 30,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
  },
  smartLabel: {
    fontSize: 12,
    fontWeight: "700",
    lineHeight: 16,
  },
  // Rich list
  listContainer: {
    paddingHorizontal: 16,
    gap: 8,
  },
  spaceListItem: {
    borderRadius: 14,
    padding: 14,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    borderWidth: 1,
  },
  spaceIcon: {
    width: 44,
    height: 44,
    borderRadius: 10,
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  spaceInfo: {
    flex: 1,
    minWidth: 0,
  },
  spaceNameRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "baseline",
  },
  spaceName: {
    fontSize: 15,
    fontWeight: "700",
    flex: 1,
  },
  spaceCount: {
    fontSize: 13,
    fontWeight: "600",
  },
  spaceDetail: {
    fontSize: 12,
    marginTop: 2,
  },
  // Empty state
  emptyState: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    gap: 12,
    paddingTop: 80,
    paddingBottom: 80,
    paddingHorizontal: 32,
  },
  emptyText: {
    fontSize: 16,
    fontWeight: "600",
  },
  emptySubtext: {
    fontSize: 14,
    textAlign: "center",
  },
});
