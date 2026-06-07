import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { MatomeApiError, type Recording, type Space } from '@matome/api-client';
import { createServerApiClient } from '@/lib/api';
import { getCurrentUser } from '@/lib/session';
import { formatDateTime, formatDuration, getSpaceName } from '../../review-data';
import { LiveRecordingStatus } from '../../LiveRecordingStatus';
import { RecordingDetailClient } from './RecordingDetailClient';
import { getServerT } from '@/lib/i18n/server';

type RecordingDetailPageProps = {
  params: Promise<{ id: string }>;
};

export default async function RecordingDetailPage({ params }: RecordingDetailPageProps) {
  const [user, { id }, { t }] = await Promise.all([getCurrentUser(), params, getServerT()]);

  if (!user) {
    redirect('/login');
  }

  const localizedStatus = (status: string) =>
    t(`web.status${status.charAt(0).toUpperCase()}${status.slice(1)}`);

  const api = createServerApiClient();
  const recordingId = Number(id);

  if (!Number.isInteger(recordingId)) {
    notFound();
  }

  let recording: Recording;
  let workspaces: Space[];

  try {
    const [recordingResponse, spacesResponse] = await Promise.all([
      api.getRecording(recordingId),
      api.listSpaces(),
    ]);

    recording = recordingResponse.recording;
    workspaces = spacesResponse.workspaces;
  } catch (error) {
    if (error instanceof MatomeApiError && error.status === 404) {
      notFound();
    }

    throw error;
  }

  return (
    <main className="review-shell detail-shell">
      <aside className="side-rail">
        <Link className="brand" href="/app">Matome</Link>
        <nav className="side-nav" aria-label="Review surfaces">
          <Link href="/app#inbox">{t('inbox.title')}</Link>
          <Link href="/app#search">{t('web.navSearch')}</Link>
          <Link href="/app#spaces">{t('spaces.title')}</Link>
          <Link href="/app#calendar">{t('calendar.title')}</Link>
          <Link href="/app/settings">{t('web.navSettings')}</Link>
        </nav>
      </aside>
      <section className="review-main" aria-labelledby="recording-title">
        <header className="hero-row">
          <div>
            <p className="eyebrow">{getSpaceName(workspaces, recording.workspace_id)} · {formatDateTime(recording.inserted_at)}</p>
            <h1 id="recording-title">{recording.title}</h1>
            <p className="lede">{formatDuration(recording.duration)} · {formatDateTime(recording.updated_at)}</p>
          </div>
          <div className="hero-actions">
            <LiveRecordingStatus />
            <span className={`status-chip ${recording.status}`}>{localizedStatus(recording.status)}</span>
          </div>
        </header>

        <div className="detail-grid">
          <article className="surface-card span-2" aria-labelledby="summary-title">
            <p className="eyebrow">{t('details.summary')}</p>
            <h2 id="summary-title">{t('web.reviewNotes')}</h2>
            <p className="body-copy">{recording.summary || t('web.noSummaryYet')}</p>
          </article>
          <article className="surface-card" aria-labelledby="meta-title">
            <p className="eyebrow">{localizedStatus(recording.status)}</p>
            <h2 id="meta-title">{t('web.statusHeading')}</h2>
            <dl className="meta-list">
              <div><dt>{t('web.mediaLabel')}</dt><dd>{recording.media_type ?? 'audio'}</dd></div>
              <div><dt>{t('web.badgeLabel')}</dt><dd>{recording.badge ?? t('web.none')}</dd></div>
              <div><dt>{t('web.errorLabel')}</dt><dd>{recording.error_reason ?? t('web.none')}</dd></div>
            </dl>
          </article>
          <RecordingDetailClient recording={recording} spaces={workspaces} />
        </div>
      </section>
    </main>
  );
}
