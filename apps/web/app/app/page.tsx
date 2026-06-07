import Link from 'next/link';
import { redirect } from 'next/navigation';
import { logoutAction } from '@/app/actions';
import { getCurrentUser } from '@/lib/session';
import { getServerT } from '@/lib/i18n/server';
import { LiveRecordingStatus } from './LiveRecordingStatus';
import { RecordRecordingPanel } from './RecordRecordingPanel';
import { UploadRecordingPanel } from './UploadRecordingPanel';
import { SpacesManager } from './SpacesManager';
import { MoveRecordingControl } from './MoveRecordingControl';
import { formatDateTime, formatDuration, getSpaceName, loadReviewData } from './review-data';

type AuthenticatedShellPageProps = {
  searchParams: Promise<{ q?: string }>;
};

export default async function AuthenticatedShellPage({ searchParams }: AuthenticatedShellPageProps) {
  const [user, params, { t }] = await Promise.all([getCurrentUser(), searchParams, getServerT()]);

  if (!user) {
    redirect('/login');
  }

  const localizedStatus = (status: string) =>
    t(`web.status${status.charAt(0).toUpperCase()}${status.slice(1)}`);

  const query = params.q?.trim() ?? '';
  const data = await loadReviewData(query);

  const spaceCounts = data.spaces.reduce<Record<number, number>>((acc, space) => {
    acc[space.id] = data.recordings.filter((recording) => recording.workspace_id === space.id).length;
    return acc;
  }, {});

  return (
    <main className="review-shell">
      <aside className="side-rail">
        <Link className="brand" href="/app">Matome</Link>
        <nav className="side-nav" aria-label="Review surfaces">
          <a href="#inbox">{t('inbox.title')}</a>
          <a href="#upload">{t('web.navUpload')}</a>
          <a href="#search">{t('web.navSearch')}</a>
          <a href="#spaces">{t('spaces.title')}</a>
          <a href="#calendar">{t('calendar.title')}</a>
          <Link href="/app/settings">{t('web.navSettings')}</Link>
        </nav>
        <form action={logoutAction}>
          <button className="button secondary sign-out" type="submit">{t('settings.signOut')}</button>
        </form>
      </aside>

      <section className="review-main" aria-labelledby="dashboard-title">
        <header className="hero-row">
          <div>
            <p className="eyebrow">{t('web.deskEyebrow')} · {user.email}</p>
            <h1 id="dashboard-title">{t('web.dashTitle')}</h1>
            <p className="lede">{t('web.dashLede')}</p>
          </div>
          <LiveRecordingStatus />
        </header>

        <section className="metrics-grid" aria-label="Recording metrics">
          <div><span>{data.recordings.length}</span><p>{t('web.metricTotal')}</p></div>
          <div><span>{data.inboxCount}</span><p>{t('web.metricInbox')}</p></div>
          <div><span>{data.processingCount}</span><p>{t('web.metricProcessing')}</p></div>
          <div><span>{data.doneCount}</span><p>{t('web.metricReady')}</p></div>
          <div><span>{data.failedCount}</span><p>{t('web.metricNeedsReview')}</p></div>
        </section>

        <section className="surface-grid two-column" id="capture">
          <RecordRecordingPanel />
          <UploadRecordingPanel spaces={data.spaces} />
        </section>

        <section className="surface-card search-card" id="search" aria-labelledby="search-title">
          <div>
            <p className="eyebrow">{t('web.navSearch')}</p>
            <h2 id="search-title">{t('web.searchTitle')}</h2>
          </div>
          <form className="search-form" action="/app">
            <input name="q" placeholder={t('web.searchPlaceholder')} defaultValue={query} aria-label={t('web.searchPlaceholder')} />
            <button className="button" type="submit">{t('web.searchButton')}</button>
            {query ? <Link className="button secondary" href="/app">{t('web.clear')}</Link> : null}
          </form>
        </section>

        <section className="surface-grid two-column">
          <article className="surface-card" id="inbox" aria-labelledby="inbox-title">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t('inbox.title')}</p>
                <h2 id="inbox-title">{t('web.inboxLatest')}</h2>
              </div>
              <span>{data.recordings.length}</span>
            </div>
            <div className="recording-list">
              {data.recordings.map((recording) => (
                <div className="recording-row" key={recording.id}>
                  <Link className="recording-row-main" href={`/app/recordings/${recording.id}`}>
                    <div>
                      <strong>{recording.title}</strong>
                      <p>{recording.summary || recording.transcript || t('web.notReady')}</p>
                      <small>{getSpaceName(data.spaces, recording.workspace_id)} · {formatDateTime(recording.inserted_at)} · {formatDuration(recording.duration)}</small>
                    </div>
                    <span className={`status-chip ${recording.status}`}>{localizedStatus(recording.status)}</span>
                  </Link>
                  <MoveRecordingControl
                    recordingId={recording.id}
                    currentWorkspaceId={recording.workspace_id}
                    spaces={data.spaces}
                  />
                </div>
              ))}
              {data.recordings.length === 0 ? <p className="empty-state">{t('web.noMatch')}</p> : null}
            </div>
          </article>

          <SpacesManager spaces={data.spaces} counts={spaceCounts} inboxCount={data.inboxCount} />
        </section>

        <section className="surface-card" id="calendar" aria-labelledby="calendar-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">{t('calendar.title')}</p>
              <h2 id="calendar-title">{t('web.calendarTitle')}</h2>
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
    </main>
  );
}
