import React, { useCallback, useEffect, useState } from "react";
import { useRouter } from "expo-router";

import { fetchHomeData, HomeData } from "@/processes/homeData";
import { fetchSpacesData, SpaceCard } from "@/processes/spacesData";
import { useRecordingsStore } from "@/stores/recordingsStore";
import { updateRecording } from "@/services/recordingService";
import { MoveToSpaceSheet } from "@/components/MoveToSpaceSheet";

import { Home } from "./Home";

const HomeContainer: React.FC = () => {
  const [data, setData] = useState<HomeData>({ sections: [] });
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedRecordingId, setSelectedRecordingId] = useState<string | null>(null);
  const [spaces, setSpaces] = useState<SpaceCard[]>([]);
  const router = useRouter();
  const refreshKey = useRecordingsStore((state) => state.refreshKey);
  const triggerRefresh = useRecordingsStore((state) => state.triggerRefresh);

  const loadData = useCallback(async (silent = false) => {
    try {
      if (!silent) setIsLoading(true);
      const homeData = await fetchHomeData();
      setData(homeData);
    } catch (error) {
      console.error("Error loading home data:", error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, []);

  // Initial load + auto-refresh when a recording is saved
  useEffect(() => {
    loadData(refreshKey > 0);
  }, [refreshKey, loadData]);

  const handleRefresh = useCallback(() => {
    setIsRefreshing(true);
    loadData(true);
  }, [loadData]);

  const handleCardPress = (id: string) => {
    router.push(`/inbox/${id}`);
  };

  const handleCardLongPress = useCallback(async (id: string) => {
    try {
      const spaceData = await fetchSpacesData();
      setSpaces(spaceData);
      setSelectedRecordingId(id);
    } catch (error) {
      console.error("Error fetching spaces for move sheet:", error);
    }
  }, []);

  const handleMoveToSpace = useCallback(async (spaceId: string) => {
    if (!selectedRecordingId) return;
    try {
      await updateRecording(selectedRecordingId, { workspaceId: spaceId });
      setSelectedRecordingId(null);
      triggerRefresh();
    } catch (error) {
      console.error("Error moving recording to space:", error);
    }
  }, [selectedRecordingId, triggerRefresh]);

  const handleMoveSheetClose = useCallback(() => {
    setSelectedRecordingId(null);
  }, []);

  const handleSearchPress = () => {
    console.log("Search pressed");
  };

  const handleSettingsPress = useCallback(() => {
    router.push('/inbox/settings');
  }, [router]);

  if (!data && !isLoading) {
    return null;
  }

  return (
    <>
      <Home
        data={data}
        isLoading={isLoading}
        isRefreshing={isRefreshing}
        onCardPress={handleCardPress}
        onCardLongPress={handleCardLongPress}
        onSearchPress={handleSearchPress}
        onSettingsPress={handleSettingsPress}
        onRefresh={handleRefresh}
      />
      <MoveToSpaceSheet
        visible={selectedRecordingId !== null}
        spaces={spaces}
        onMove={handleMoveToSpace}
        onClose={handleMoveSheetClose}
      />
    </>
  );
};

export default HomeContainer;
