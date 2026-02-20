import React, { useCallback, useEffect, useState } from "react";
import { useRouter } from "expo-router";

import { fetchHomeData, HomeData } from "@/processes/homeData";
import { useAuthStore } from "@/stores/authStore";
import { useRecordingsStore } from "@/stores/recordingsStore";

import { Home } from "./Home";

const HomeContainer: React.FC = () => {
  const [data, setData] = useState<HomeData>({ sections: [] });
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const router = useRouter();
  const signOut = useAuthStore((state) => state.signOut);
  const refreshKey = useRecordingsStore((state) => state.refreshKey);

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

  const handleSearchPress = () => {
    console.log("Search pressed");
  };

  const handleSignOutPress = async () => {
    await signOut();
  };

  if (!data && !isLoading) {
    return null;
  }

  return (
    <Home
      data={data}
      isLoading={isLoading}
      isRefreshing={isRefreshing}
      onCardPress={handleCardPress}
      onSearchPress={handleSearchPress}
      onSignOutPress={handleSignOutPress}
      onRefresh={handleRefresh}
    />
  );
};

export default HomeContainer;
