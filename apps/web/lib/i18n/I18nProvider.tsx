'use client';

import { useState } from 'react';
import { createInstance } from 'i18next';
import { I18nextProvider, initReactI18next } from 'react-i18next';

import { i18nInitOptions, type Locale } from './config';

/**
 * Client-side i18n provider. Builds a react-i18next-bound instance once per
 * mount with the server-resolved locale so the first client render matches the
 * SSR output (no hydration drift). react-i18next is imported only here so it
 * never enters the server graph.
 */
export function I18nProvider({
  locale,
  children,
}: {
  locale: Locale;
  children: React.ReactNode;
}) {
  const [instance] = useState(() => {
    const i = createInstance();
    i.use(initReactI18next).init({ ...i18nInitOptions, lng: locale });
    return i;
  });
  return <I18nextProvider i18n={instance}>{children}</I18nextProvider>;
}
