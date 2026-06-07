import { createInstance, type i18n, type Resource } from 'i18next';

import en from '@/locales/en';
import ja from '@/locales/ja';

export const locales = ['en', 'ja'] as const;
export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = 'en';

/** Cookie that persists the user's chosen locale across requests. */
export const LOCALE_COOKIE = 'matome_locale';

/** Inlined resources — shared by the server translator and the client provider. */
export const resources: Resource = {
  en: { translation: en },
  ja: { translation: ja },
};

export const i18nInitOptions = {
  fallbackLng: defaultLocale,
  supportedLngs: locales as unknown as string[],
  resources,
  interpolation: { escapeValue: false },
};

export function isLocale(value: string | undefined | null): value is Locale {
  return value === 'en' || value === 'ja';
}

export function normalizeLocale(value: string | undefined | null): Locale {
  return isLocale(value) ? value : defaultLocale;
}

/**
 * Plain i18next instance (no react-i18next binding) for use in Server
 * Components. Keeping react-i18next out of this module avoids pulling
 * React.createContext into the RSC/server build graph.
 */
export function createI18nInstance(locale: Locale): i18n {
  const instance = createInstance();
  instance.init({ ...i18nInitOptions, lng: locale });
  return instance;
}
