import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { MatomeApiError, type Recording, type Space } from '@matome/api-client';
import { createServerApiClient } from '@/lib/api';
import { getCurrentUser } from '@/lib/session';
import { formatDateTime, formatDuration, getSpaceName, statusLabel } from '../../review-data';
import { LiveRecordingStatus } from '../../LiveRecordingStatus';
import { RecordingDetailClient } from './RecordingDetailClient';

type RecordingDetailPageProps = {
  params: Promise<{ id: string }>;
};

export default async function RecordingDetailPage({ params }: RecordingDetailPageProps) {
  const [user, { id }] = await Promise.all([getCurrentUser(), params]);

  if (!user) {
    redirect('/login');
  }

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
          <Link href="/app#inbox">Inbox</Link>
          <Link href="/app#search">Search</Link>
          <Link href="/app#spaces">Spaces</Link>
          <Link href="/app#calendar">Calendar</Link>
        </nav>
      </aside>
      <section className="review-main" aria-labelledby="recording-title">
        <header className="hero-row">
          <div>
            <p className="eyebrow">{getSpaceName(workspaces, recording.workspace_id)} · {formatDateTime(recording.inserted_at)}</p>
            <h1 id="recording-title">{recording.title}</h1>
            <p className="lede">{formatDuration(recording.duration)} · Updated {formatDateTime(recording.updated_at)}</p>
          </div>
          <div className="hero-actions">
            <LiveRecordingStatus />
            <span className={`status-chip ${recording.status}`}>{statusLabel(recording.status)}</span>
          </div>
        </header>

        <div className="detail-grid">
          <article className="surface-card span-2" aria-labelledby="summary-title">
            <p className="eyebrow">Summary</p>
            <h2 id="summary-title">Review notes</h2>
            <p className="body-copy">{recording.summary || 'No summary has been generated for this recording yet.'}</p>
          </article>
          <article className="surface-card" aria-labelledby="meta-title">
            <p className="eyebrow">Status</p>
            <h2 id="meta-title">Processing</h2>
            <dl className="meta-list">
              <div><dt>Media</dt><dd>{recording.media_type ?? 'audio'}</dd></div>
              <div><dt>Badge</dt><dd>{recording.badge ?? 'None'}</dd></div>
              <div><dt>Error</dt><dd>{recording.error_reason ?? 'None'}</dd></div>
            </dl>
          </article>
          <RecordingDetailClient recording={recording} spaces={workspaces} />
        </div>
      </section>
    </main>
  );
}
