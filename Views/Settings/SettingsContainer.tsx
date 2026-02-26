import React, { useCallback } from "react";
import { useRouter } from "expo-router";

import { useAuthStore } from "@/stores/authStore";
import { useThemeStore, ThemeMode } from "@/stores/themeStore";
import { useLanguageStore, Language } from "@/stores/languageStore";

import { Settings } from "./Settings";

const SettingsContainer: React.FC = () => {
  const router = useRouter();
  const themeMode = useThemeStore((state) => state.themeMode);
  const setThemeMode = useThemeStore((state) => state.setThemeMode);
  const language = useLanguageStore((state) => state.language);
  const setLanguage = useLanguageStore((state) => state.setLanguage);
  const signOut = useAuthStore((state) => state.signOut);

  const handleThemeChange = useCallback(
    (mode: ThemeMode) => {
      setThemeMode(mode);
    },
    [setThemeMode],
  );

  const handleLanguageChange = useCallback(
    (lang: Language) => {
      setLanguage(lang);
    },
    [setLanguage],
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
      language={language}
      onLanguageChange={handleLanguageChange}
      onBack={handleBack}
      onSignOut={handleSignOut}
    />
  );
};

export default SettingsContainer;
