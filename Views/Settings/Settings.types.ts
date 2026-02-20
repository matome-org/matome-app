import { ThemeMode } from "@/stores/themeStore";

export interface SettingsProps {
  themeMode: ThemeMode;
  onThemeChange: (mode: ThemeMode) => void;
  onBack: () => void;
  onSignOut: () => void;
}
