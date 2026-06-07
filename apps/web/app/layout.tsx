import type { Metadata } from 'next';
import { cssVariables } from '@matome/ui';
import './globals.css';
import { I18nProvider } from '@/lib/i18n/I18nProvider';
import { getLocale } from '@/lib/i18n/server';
import { getTheme } from '@/lib/theme/server';

export const metadata: Metadata = {
  title: 'Matome Web',
  description: 'Web shell for Matome recordings.',
};

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const [locale, theme] = await Promise.all([getLocale(), getTheme()]);

  return (
    <html lang={locale} data-theme={theme}>
      <head>
        <style dangerouslySetInnerHTML={{ __html: cssVariables }} />
      </head>
      <body>
        <I18nProvider locale={locale}>{children}</I18nProvider>
      </body>
    </html>
  );
}
