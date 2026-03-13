import { ThemeMode } from "@/stores/themeStore";
import { Language } from "@/stores/languageStore";

export interface SettingsProps {
  themeMode: ThemeMode;
  onThemeChange: (mode: ThemeMode) => void;
  language: Language;
  onLanguageChange: (lang: Language) => void;
  onBack: () => void;
  onSignOut: () => void;
}
