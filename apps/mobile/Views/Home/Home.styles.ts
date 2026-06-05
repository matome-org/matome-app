import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  // Top bar
  topBar: {
    paddingHorizontal: 16,
    paddingBottom: 0,
    borderBottomWidth: 1,
  },
  topBarRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    paddingVertical: 10,
  },
  wordmark: {
    fontSize: 13,
    fontWeight: "800",
    letterSpacing: 0.5,
    opacity: 0.55,
  },
  topBarTitle: {
    fontSize: 28,
    fontWeight: "700",
    letterSpacing: -0.5,
    marginTop: 2,
  },
  topBarSubtitle: {
    fontSize: 13,
    marginTop: 2,
  },
  topBarActions: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingTop: 6,
  },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  // Search bar — always visible
  searchBar: {
    flexDirection: "row",
    alignItems: "center",
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
    marginBottom: 10,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    padding: 0,
  },
  kbdHint: {
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: 6,
  },
  kbdHintText: {
    fontSize: 11,
    fontWeight: "600",
  },
  // Filter chips
  chipsScroll: {
    marginBottom: 8,
  },
  chipsContent: {
    gap: 8,
    paddingRight: 4,
  },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 999,
  },
  chipText: {
    fontSize: 13,
    fontWeight: "600",
  },
  // Content
  content: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 12,
  },
  // Section header
  sectionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "baseline",
    marginTop: 20,
    marginBottom: 10,
    paddingHorizontal: 4,
  },
  sectionTitle: {
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1.1,
  },
  sectionCount: {
    fontSize: 12,
  },
  cardList: {
    gap: 8,
  },
  // Empty states
  emptySearch: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingTop: 80,
    gap: 8,
  },
});
