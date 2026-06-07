import 'server-only';
import { cookies } from 'next/headers';
import type { TFunction } from 'i18next';

import { LOCALE_COOKIE, createI18nInstance, normalizeLocale, type Locale } from './config';

/** Resolve the active locale for the current request from the locale cookie. */
export async function getLocale(): Promise<Locale> {
  const store = await cookies();
  return normalizeLocale(store.get(LOCALE_COOKIE)?.value);
}

/**
 * Server-side translator for use in Server Components. Returns the resolved
 * locale plus a `t` function bound to it.
 */
export async function getServerT(): Promise<{ locale: Locale; t: TFunction }> {
  const locale = await getLocale();
  const instance = createI18nInstance(locale);
  return { locale, t: instance.getFixedT(locale) };
}
