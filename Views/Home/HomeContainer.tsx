import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "expo-router";

import { fetchHomeData, HomeData } from "@/processes/homeData";
import { fetchSpacesData, SpaceCard } from "@/processes/spacesData";
import { useRecordingsStore } from "@/stores/recordingsStore";
import { useLanguageStore } from "@/stores/languageStore";
import { updateRecording } from "@/services/recordingService";
import { MoveToSpaceSheet } from "@/components/MoveToSpaceSheet";

import { Home } from "./Home";

const HomeContainer: React.FC = () => {
  const [data, setData] = useState<HomeData>({ sections: [] });
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedRecordingId, setSelectedRecordingId] = useState<string | null>(null);
  const [spaces, setSpaces] = useState<SpaceCard[]>([]);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const router = useRouter();
  const refreshKey = useRecordingsStore((state) => state.refreshKey);
  const triggerRefresh = useRecordingsStore((state) => state.triggerRefresh);
  const language = useLanguageStore((state) => state.language);

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

  // Re-fetch when language changes so section titles (Today/Yesterday) update
  useEffect(() => {
    loadData(true);
  }, [language, loadData]);

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

  const filteredData = useMemo(() => {
    if (!searchQuery.trim()) return data;
    const q = searchQuery.toLowerCase();
    const sections = data.sections
      .map((section) => ({
        ...section,
        recordings: section.recordings.filter(
          (r) =>
            r.title.toLowerCase().includes(q) ||
            r.summary?.toLowerCase().includes(q) ||
            r.notes?.toLowerCase().includes(q),
        ),
      }))
      .filter((section) => section.recordings.length > 0);
    return { sections };
  }, [data, searchQuery]);

  const handleSearchPress = useCallback(() => {
    setIsSearchOpen(true);
  }, []);

  const handleSearchChange = useCallback((query: string) => {
    setSearchQuery(query);
  }, []);

  const handleSearchClose = useCallback(() => {
    setIsSearchOpen(false);
    setSearchQuery("");
  }, []);

  const handleSettingsPress = useCallback(() => {
    router.push('/inbox/settings');
  }, [router]);

  if (!data && !isLoading) {
    return null;
  }

  return (
    <>
      <Home
        data={filteredData}
        isLoading={isLoading}
        isRefreshing={isRefreshing}
        isSearchOpen={isSearchOpen}
        searchQuery={searchQuery}
        onCardPress={handleCardPress}
        onCardLongPress={handleCardLongPress}
        onSearchPress={handleSearchPress}
        onSearchChange={handleSearchChange}
        onSearchClose={handleSearchClose}
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
