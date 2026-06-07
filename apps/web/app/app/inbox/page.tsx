import Link from 'next/link';
import { getCurrentUser } from '@/lib/session';
import { getServerT } from '@/lib/i18n/server';
import { MoveRecordingControl } from '../MoveRecordingControl';
import { formatDateTime, formatDuration, getSpaceName, loadReviewData } from '../review-data';

type InboxPageProps = {
  searchParams: Promise<{ q?: string }>;
};

export default async function InboxPage({ searchParams }: InboxPageProps) {
  const [user, params, { t }] = await Promise.all([getCurrentUser(), searchParams, getServerT()]);

  const localizedStatus = (status: string) =>
    t(`web.status${status.charAt(0).toUpperCase()}${status.slice(1)}`);

  const query = params.q?.trim() ?? '';
  const data = await loadReviewData(query);

  return (
    <section className="review-main" aria-labelledby="inbox-title">
      <header className="hero-row">
        <div>
          <p className="eyebrow">{t('web.deskEyebrow')} · {user?.email}</p>
          <h1 id="inbox-title">{t('inbox.title')}</h1>
          <p className="lede">{t('web.dashLede')}</p>
        </div>
      </header>

      <section className="metrics-grid" aria-label="Recording metrics">
        <div><span>{data.recordings.length}</span><p>{t('web.metricTotal')}</p></div>
        <div><span>{data.inboxCount}</span><p>{t('web.metricInbox')}</p></div>
        <div><span>{data.processingCount}</span><p>{t('web.metricProcessing')}</p></div>
        <div><span>{data.doneCount}</span><p>{t('web.metricReady')}</p></div>
        <div><span>{data.failedCount}</span><p>{t('web.metricNeedsReview')}</p></div>
      </section>

      <section className="surface-card search-card" id="search" aria-labelledby="search-title">
        <div>
          <p className="eyebrow">{t('web.navSearch')}</p>
          <h2 id="search-title">{t('web.searchTitle')}</h2>
        </div>
        <form className="search-form" action="/app/inbox">
          <input name="q" placeholder={t('web.searchPlaceholder')} defaultValue={query} aria-label={t('web.searchPlaceholder')} />
          <button className="button" type="submit">{t('web.searchButton')}</button>
          {query ? <Link className="button secondary" href="/app/inbox">{t('web.clear')}</Link> : null}
        </form>
      </section>

      <article className="surface-card" aria-labelledby="inbox-list-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">{t('inbox.title')}</p>
            <h2 id="inbox-list-title">{t('web.inboxLatest')}</h2>
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
    </section>
  );
}
