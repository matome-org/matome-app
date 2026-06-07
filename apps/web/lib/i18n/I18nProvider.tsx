'use client';

import { useState } from 'react';
import { I18nextProvider } from 'react-i18next';

import { createI18nInstance, type Locale } from './config';

/**
 * Client-side i18n provider. Initialised once per mount with the server-resolved
 * locale so the first client render matches the SSR output (no hydration drift).
 */
export function I18nProvider({
  locale,
  children,
}: {
  locale: Locale;
  children: React.ReactNode;
}) {
  const [instance] = useState(() => createI18nInstance(locale));
  return <I18nextProvider i18n={instance}>{children}</I18nextProvider>;
}
