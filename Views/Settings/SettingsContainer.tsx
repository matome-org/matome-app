import React, { useCallback } from "react";
import { useRouter } from "expo-router";

import { useAuthStore } from "@/stores/authStore";
import { useThemeStore, ThemeMode } from "@/stores/themeStore";

import { Settings } from "./Settings";

const SettingsContainer: React.FC = () => {
  const router = useRouter();
  const themeMode = useThemeStore((state) => state.themeMode);
  const setThemeMode = useThemeStore((state) => state.setThemeMode);
  const signOut = useAuthStore((state) => state.signOut);

  const handleThemeChange = useCallback(
    (mode: ThemeMode) => {
      setThemeMode(mode);
    },
    [setThemeMode],
  );

  const handleBack = useCallback(() => {
    router.back();
  }, [router]);

  const handleSignOut = useCallback(async () => {
    await signOut();
  }, [signOut]);

  return (
    <Settings
      themeMode={themeMode}
      onThemeChange={handleThemeChange}
      onBack={handleBack}
      onSignOut={handleSignOut}
    />
  );
};

export default SettingsContainer;
