import { useColorScheme } from 'react-native';
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import * as SecureStore from 'expo-secure-store';

export type ThemeMode = 'light' | 'dark' | 'system';

interface ThemeState {
  themeMode: ThemeMode;
  setThemeMode: (mode: ThemeMode) => void;
}

const secureStorage = {
  getItem: (name: string) => SecureStore.getItemAsync(name),
  setItem: (name: string, value: string) => SecureStore.setItemAsync(name, value),
  removeItem: (name: string) => SecureStore.deleteItemAsync(name),
};

export const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      themeMode: 'system',
      setThemeMode: (mode: ThemeMode) => set({ themeMode: mode }),
    }),
    {
      name: 'theme-store',
      storage: createJSONStorage(() => secureStorage),
    },
  ),
);

// Hook to get the current effective theme
export const useEffectiveTheme = (): 'light' | 'dark' => {
  const systemColorScheme = useColorScheme();
  const themeMode = useThemeStore((state) => state.themeMode);

  if (themeMode === 'system') {
    return systemColorScheme === 'dark' ? 'dark' : 'light';
  }

  return themeMode;
};
