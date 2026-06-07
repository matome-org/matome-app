'use server';

import { cookies } from 'next/headers';
import { revalidatePath } from 'next/cache';

import { THEME_COOKIE, normalizeTheme } from './config';

/** Persist the chosen theme to a cookie and refresh server-rendered content. */
export async function setThemeAction(theme: string) {
  const next = normalizeTheme(theme);
  const store = await cookies();
  store.set(THEME_COOKIE, next, {
    path: '/',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365,
  });
  revalidatePath('/', 'layout');
}
