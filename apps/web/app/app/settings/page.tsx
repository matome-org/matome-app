import { redirect } from 'next/navigation';
import { logoutAction } from '@/app/actions';
import { getCurrentUser } from '@/lib/session';
import { getServerT } from '@/lib/i18n/server';
import { getTheme } from '@/lib/theme/server';
import { SettingsClient } from './SettingsClient';

export default async function SettingsPage() {
  const [user, { t }, theme] = await Promise.all([getCurrentUser(), getServerT(), getTheme()]);

  if (!user) {
    redirect('/login');
  }

  return (
    <section className="review-main detail-main" aria-labelledby="settings-title">
      <header className="hero-row">
        <div>
          <p className="eyebrow">{t('settings.account')} · {user.email}</p>
          <h1 id="settings-title">{t('settings.title')}</h1>
        </div>
      </header>

      <SettingsClient initialTheme={theme} />

      <section className="surface-card" aria-labelledby="account-title">
        <p className="eyebrow">{t('settings.account')}</p>
        <h2 id="account-title">{t('settings.signOut')}</h2>
        <form action={logoutAction}>
          <button className="button secondary sign-out" type="submit">{t('settings.signOut')}</button>
        </form>
      </section>
    </section>
  );
}
