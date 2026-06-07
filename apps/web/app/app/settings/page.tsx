import Link from 'next/link';
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
    <main className="review-shell detail-shell">
      <aside className="side-rail">
        <Link className="brand" href="/app">Matome</Link>
        <nav className="side-nav" aria-label="Review surfaces">
          <Link href="/app#inbox">{t('inbox.title')}</Link>
          <Link href="/app#spaces">{t('spaces.title')}</Link>
          <Link href="/app#calendar">{t('calendar.title')}</Link>
          <Link href="/app/settings" aria-current="page">{t('settings.title')}</Link>
        </nav>
      </aside>

      <section className="review-main" aria-labelledby="settings-title">
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
    </main>
  );
}
