'use client';

import { useTranslation } from 'react-i18next';
import { useLocale } from '@/lib/i18n/useLocale';
import { useTheme } from '@/lib/theme/useTheme';
import type { Theme } from '@/lib/theme/config';
import type { Locale } from '@/lib/i18n/config';

export function SettingsClient({ initialTheme }: { initialTheme: Theme }) {
  const { t } = useTranslation();
  const { theme, setTheme } = useTheme(initialTheme);
  const { locale, setLocale } = useLocale();

  return (
    <div className="settings-stack">
      <section className="surface-card" aria-labelledby="appearance-title">
        <p className="eyebrow">{t('settings.appearance')}</p>
        <h2 id="appearance-title">{t('settings.theme')}</h2>
        <div className="segmented" role="group" aria-label={t('settings.theme')}>
          {(['light', 'dark'] as Theme[]).map((value) => (
            <button
              key={value}
              type="button"
              className={`button ${theme === value ? '' : 'secondary'}`}
              aria-pressed={theme === value}
              onClick={() => setTheme(value)}
            >
              {value === 'light' ? t('settings.themeLight') : t('settings.themeDark')}
            </button>
          ))}
        </div>
      </section>

      <section className="surface-card" aria-labelledby="language-title">
        <p className="eyebrow">{t('settings.appearance')}</p>
        <h2 id="language-title">{t('settings.language')}</h2>
        <div className="segmented" role="group" aria-label={t('settings.language')}>
          {(['en', 'ja'] as Locale[]).map((value) => (
            <button
              key={value}
              type="button"
              className={`button ${locale === value ? '' : 'secondary'}`}
              aria-pressed={locale === value}
              onClick={() => setLocale(value)}
            >
              {value === 'en' ? t('settings.langEn') : t('settings.langJa')}
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}
