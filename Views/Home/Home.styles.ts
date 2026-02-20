import { StyleSheet } from "react-native";

export const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 16,
    paddingBottom: 100,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: "600",
    marginTop: 24,
    marginBottom: 12,
    marginHorizontal: 4,
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  cardList: {
    gap: 12,
  },
  recordCard: {
    borderRadius: 8,
    padding: 16,
    flexDirection: "row",
    gap: 16,
    borderWidth: 1,
    borderColor: "gray",
  },
  cardIconArea: {
    alignItems: "center",
    minWidth: 40,
    gap: 8,
  },
  playButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: "center",
    alignItems: "center",
  },
  playButtonActive: {
    // Active state handled by theme
  },
  cardContent: {
    flex: 1,
    gap: 6,
    minWidth: 0,
  },
  cardHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  cardTitle: {
    fontWeight: "600",
    fontSize: 16,
    flex: 1,
  },
  metaText: {
    fontSize: 12,
  },
  cardSummary: {
    fontSize: 14,
    lineHeight: 19.6, // 1.4 * 14
  },
  processingText: {
    fontSize: 13,
    fontStyle: "italic",
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  cardFooter: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    marginTop: 6,
  },
  badge: {
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: "600",
  },
  badgeWork: {
    // Work badge styling handled by theme
  },
  badgePersonal: {
    // Personal badge styling handled by theme
  },
  badgeInbox: {
    // Inbox badge styling handled by theme
  },
});
