import 'server-only';
import { cookies } from 'next/headers';

import { THEME_COOKIE, normalizeTheme, type Theme } from './config';

/** Resolve the active theme for the current request from the theme cookie. */
export async function getTheme(): Promise<Theme> {
  const store = await cookies();
  return normalizeTheme(store.get(THEME_COOKIE)?.value);
}
