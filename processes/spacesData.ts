import { getWorkspaces, getRecordingsInWorkspace } from "@/services/workspaceService";

export interface SpaceCard {
  id: string;
  name: string;
  count: number;
}

/**
 * Fetch all spaces with recording counts
 */
export const fetchSpacesData = async (): Promise<SpaceCard[]> => {
  try {
    const workspaces = await getWorkspaces();

    const spaceCards = await Promise.all(
      workspaces.map(async (ws) => {
        const recordings = await getRecordingsInWorkspace(ws.id);
        return { id: ws.id, name: ws.name, count: recordings.length };
      }),
    );

    return spaceCards;
  } catch (error) {
    console.error("Error fetching spaces data:", error);
    return [];
  }
};
