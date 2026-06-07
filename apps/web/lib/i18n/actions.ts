'use server';

import { cookies } from 'next/headers';
import { revalidatePath } from 'next/cache';

import { LOCALE_COOKIE, normalizeLocale } from './config';

/** Persist the chosen locale to a cookie and refresh server-rendered content. */
export async function setLocaleAction(locale: string) {
  const next = normalizeLocale(locale);
  const store = await cookies();
  store.set(LOCALE_COOKIE, next, {
    path: '/',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365,
  });
  revalidatePath('/', 'layout');
}
