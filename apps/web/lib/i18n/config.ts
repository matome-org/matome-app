import { createInstance, type i18n, type Resource } from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from '@/locales/en';
import ja from '@/locales/ja';

export const locales = ['en', 'ja'] as const;
export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = 'en';

/** Cookie that persists the user's chosen locale across requests. */
export const LOCALE_COOKIE = 'matome_locale';

const resources: Resource = {
  en: { translation: en },
  ja: { translation: ja },
};

export function isLocale(value: string | undefined | null): value is Locale {
  return value === 'en' || value === 'ja';
}

export function normalizeLocale(value: string | undefined | null): Locale {
  return isLocale(value) ? value : defaultLocale;
}

/**
 * Build a fully-initialised i18next instance for a given locale. Resources are
 * inlined (no async backend), so the instance renders synchronously on both the
 * server and the client — keeping SSR output and hydration in sync.
 */
export function createI18nInstance(locale: Locale): i18n {
  const instance = createInstance();
  instance.use(initReactI18next).init({
    lng: locale,
    fallbackLng: defaultLocale,
    supportedLngs: locales,
    resources,
    interpolation: { escapeValue: false },
  });
  return instance;
}
