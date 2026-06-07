'use client';

import { useTransition } from 'react';
import { useTranslation } from 'react-i18next';

import { setLocaleAction } from './actions';
import { normalizeLocale, type Locale } from './config';

/**
 * App-wide locale switch hook for Client Components. Updates the live i18next
 * language immediately, then persists the choice via the server action so SSR
 * picks it up on the next request.
 */
export function useLocale(): {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  pending: boolean;
} {
  const { i18n } = useTranslation();
  const [pending, startTransition] = useTransition();

  const setLocale = (locale: Locale) => {
    const next = normalizeLocale(locale);
    void i18n.changeLanguage(next);
    startTransition(() => {
      void setLocaleAction(next);
    });
  };

  return { locale: normalizeLocale(i18n.language), setLocale, pending };
}
