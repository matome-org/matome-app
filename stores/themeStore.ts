import { useColorScheme } from 'react-native';
import { create } from 'zustand';

type ThemeMode = 'light' | 'dark' | 'system';

interface ThemeState {
  themeMode: ThemeMode;
  setThemeMode: (mode: ThemeMode) => void;
  getEffectiveTheme: () => 'light' | 'dark';
}

export const useThemeStore = create<ThemeState>((set, get) => ({
  themeMode: 'system',
  
  setThemeMode: (mode: ThemeMode) => {
    set({ themeMode: mode });
  },
  
  getEffectiveTheme: () => {
    const { themeMode } = get();
    if (themeMode === 'system') {
      // This will be called from a component that has access to useColorScheme
      // For now, default to light
      return 'light';
    }
    return themeMode;
  },
}));

// Hook to get the current effective theme
export const useEffectiveTheme = (): 'light' | 'dark' => {
  const systemColorScheme = useColorScheme();
  const themeMode = useThemeStore((state) => state.themeMode);
  
  if (themeMode === 'system') {
    return systemColorScheme === 'dark' ? 'dark' : 'light';
  }
  
  return themeMode;
};
