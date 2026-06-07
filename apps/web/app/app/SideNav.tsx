'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useTranslation } from 'react-i18next';

const NAV_ITEMS = [
  { href: '/app/inbox', key: 'web.navInbox', match: ['/app/inbox', '/app/recordings'] },
  { href: '/app/calendar', key: 'calendar.title', match: ['/app/calendar'] },
  { href: '/app/spaces', key: 'spaces.title', match: ['/app/spaces'] },
  { href: '/app/record', key: 'web.navRecord', match: ['/app/record'] },
  { href: '/app/settings', key: 'web.navSettings', match: ['/app/settings'] },
];

export function SideNav() {
  const pathname = usePathname();
  const { t } = useTranslation();

  return (
    <nav className="side-nav" aria-label="Review surfaces">
      {NAV_ITEMS.map((item) => {
        const active = item.match.some(
          (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
        );

        return (
          <Link key={item.href} href={item.href} aria-current={active ? 'page' : undefined}>
            {t(item.key)}
          </Link>
        );
      })}
    </nav>
  );
}
