import { getInboxRecordings, recordToCard } from "@/services/recordingService";
import i18n from "@/config/i18n";

export type BadgeType = "Work" | "Personal" | "Inbox";

export interface RecordingCard {
  id: string;
  title: string;
  summary?: string;
  timestamp: string;
  duration: string;
  notes?: string;
  badge: BadgeType;
  isProcessing: boolean;
  isActive?: boolean;
}

export interface HomeSection {
  title: string;
  recordings: RecordingCard[];
}

export interface HomeData {
  sections: HomeSection[];
}

/**
 * Get section title based on date
 */
const getSectionTitle = (date: Date): string => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);

  const recordDate = new Date(date);
  recordDate.setHours(0, 0, 0, 0);

  if (recordDate.getTime() === today.getTime()) {
    return i18n.t("common.today");
  } else if (recordDate.getTime() === yesterday.getTime()) {
    return i18n.t("common.yesterday");
  } else {
    // Format as "Mon DD, YYYY" or similar
    return recordDate.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year:
        recordDate.getFullYear() !== today.getFullYear()
          ? "numeric"
          : undefined,
    });
  }
};

/**
 * Fetch home data from SQLite database, grouped by date
 * @returns Promise that resolves with home data
 */
export const fetchHomeData = async (): Promise<HomeData> => {
  try {
    // Get inbox recordings (workspaceId IS NULL)
    const records = await getInboxRecordings();

    console.log("RECORDS", JSON.stringify(records, null, 4));

    // Convert to cards
    const cards = records.map(recordToCard);

    // Group by date
    const sectionsMap = new Map<string, RecordingCard[]>();

    cards.forEach((card) => {
      // Find the record to get createdAt
      const record = records.find((r) => r.id === card.id);
      if (!record) return;

      const date = new Date(record.createdAt);
      const sectionTitle = getSectionTitle(date);

      if (!sectionsMap.has(sectionTitle)) {
        sectionsMap.set(sectionTitle, []);
      }

      sectionsMap.get(sectionTitle)!.push(card);
    });

    // Convert map to array and sort sections
    const sections: HomeSection[] = Array.from(sectionsMap.entries())
      .map(([title, recordings]) => ({
        title,
        recordings,
      }))
      .sort((a, b) => {
        // Sort sections: Today first, then Yesterday, then by date (newest first)
        const todayLabel = i18n.t("common.today");
        const yesterdayLabel = i18n.t("common.yesterday");
        if (a.title === todayLabel) return -1;
        if (b.title === todayLabel) return 1;
        if (a.title === yesterdayLabel) return -1;
        if (b.title === yesterdayLabel) return 1;

        // For other dates, compare the dates
        const dateA = new Date(a.title);
        const dateB = new Date(b.title);
        return dateB.getTime() - dateA.getTime();
      });

    return { sections };
  } catch (error) {
    console.error("Error fetching home data:", error);
    // Return empty data on error
    return { sections: [] };
  }
};
