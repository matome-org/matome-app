import React, { useEffect, useState } from "react";
import { useRouter } from "expo-router";

import { fetchHomeData, HomeData } from "@/processes/homeData";
import { useAuthStore } from "@/stores/authStore";

import { Home } from "./Home";

const HomeContainer: React.FC = () => {
  const [data, setData] = useState<HomeData>({ sections: [] });
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();
  const signOut = useAuthStore((state) => state.signOut);

  useEffect(() => {
    const loadData = async () => {
      try {
        setIsLoading(true);
        const homeData = await fetchHomeData();
        setData(homeData);
      } catch (error) {
        console.error("Error loading home data:", error);
      } finally {
        setIsLoading(false);
      }
    };

    loadData();
  }, []);

  const handleCardPress = (id: string) => {
    router.push(`/inbox/${id}`);
  };

  const handleSearchPress = () => {
    // Navigate to search screen when implemented
    console.log("Search pressed");
    // router.push('/search');
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
      onCardPress={handleCardPress}
      onSearchPress={handleSearchPress}
      onSignOutPress={handleSignOutPress}
    />
  );
};

export default HomeContainer;
