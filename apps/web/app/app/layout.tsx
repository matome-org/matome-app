import type { ReactNode } from 'react';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { logoutAction } from '@/app/actions';
import { getCurrentUser } from '@/lib/session';
import { getServerT } from '@/lib/i18n/server';
import { LiveRecordingStatus } from './LiveRecordingStatus';
import { SideNav } from './SideNav';

export default async function AppLayout({ children }: { children: ReactNode }) {
  const [user, { t }] = await Promise.all([getCurrentUser(), getServerT()]);

  if (!user) {
    redirect('/login');
  }

  return (
    <div className="review-shell">
      <aside className="side-rail">
        <Link className="brand" href="/app/inbox">Matome</Link>
        <SideNav />
        <LiveRecordingStatus />
        <form action={logoutAction}>
          <button className="button secondary sign-out" type="submit">{t('settings.signOut')}</button>
        </form>
      </aside>
      {children}
    </div>
  );
}
