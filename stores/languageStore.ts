import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import * as SecureStore from 'expo-secure-store';

import i18n from '@/config/i18n';

export type Language = 'en' | 'ja';

interface LanguageState {
  language: Language;
  setLanguage: (lang: Language) => void;
}

const secureStorage = {
  getItem: (name: string) => SecureStore.getItemAsync(name),
  setItem: (name: string, value: string) => SecureStore.setItemAsync(name, value),
  removeItem: (name: string) => SecureStore.deleteItemAsync(name),
};

export const useLanguageStore = create<LanguageState>()(
  persist(
    (set) => ({
      language: 'en',
      setLanguage: (language: Language) => {
        i18n.changeLanguage(language);
        set({ language });
      },
    }),
    {
      name: 'language-store',
      storage: createJSONStorage(() => secureStorage),
      onRehydrateStorage: () => (state) => {
        if (state) i18n.changeLanguage(state.language);
      },
    },
  ),
);
