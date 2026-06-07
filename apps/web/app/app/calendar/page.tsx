import Link from 'next/link';
import { getServerT } from '@/lib/i18n/server';
import { loadReviewData } from '../review-data';

export default async function CalendarPage() {
  const [{ t }, data] = await Promise.all([getServerT(), loadReviewData()]);

  return (
    <section className="review-main" aria-labelledby="calendar-title">
      <header className="hero-row">
        <div>
          <p className="eyebrow">{t('calendar.title')}</p>
          <h1 id="calendar-title">{t('web.calendarTitle')}</h1>
          <p className="lede">{t('web.dashLede')}</p>
        </div>
      </header>

      <section className="surface-card" aria-labelledby="calendar-list-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">{t('calendar.title')}</p>
            <h2 id="calendar-list-title">{t('web.calendarTitle')}</h2>
          </div>
          <span>{data.calendarDays.length}</span>
        </div>
        <div className="calendar-grid">
          {data.calendarDays.map((day) => (
            <div className="calendar-day" key={day.key}>
              <strong>{day.label}</strong>
              <p>{day.recordings.length} {t('inbox.recordings')}</p>
              {day.recordings.slice(0, 3).map((recording) => (
                <Link href={`/app/recordings/${recording.id}`} key={recording.id}>{recording.title}</Link>
              ))}
            </div>
          ))}
          {data.calendarDays.length === 0 ? <p className="empty-state">{t('web.noCalendar')}</p> : null}
        </div>
      </section>
    </section>
  );
}
