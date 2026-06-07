import Link from 'next/link';
import { redirect } from 'next/navigation';
import { logoutAction } from '@/app/actions';
import { getCurrentUser } from '@/lib/session';
import { LiveRecordingStatus } from './LiveRecordingStatus';
import { RecordRecordingPanel } from './RecordRecordingPanel';
import { UploadRecordingPanel } from './UploadRecordingPanel';
import { formatDateTime, formatDuration, getSpaceName, loadReviewData, statusLabel } from './review-data';

type AuthenticatedShellPageProps = {
  searchParams: Promise<{ q?: string }>;
};

export default async function AuthenticatedShellPage({ searchParams }: AuthenticatedShellPageProps) {
  const [user, params] = await Promise.all([getCurrentUser(), searchParams]);

  if (!user) {
    redirect('/login');
  }

  const query = params.q?.trim() ?? '';
  const data = await loadReviewData(query);

  return (
    <main className="review-shell">
      <aside className="side-rail">
        <Link className="brand" href="/app">Matome</Link>
        <nav className="side-nav" aria-label="Review surfaces">
          <a href="#inbox">Inbox</a>
          <a href="#upload">Upload</a>
          <a href="#search">Search</a>
          <a href="#spaces">Spaces</a>
          <a href="#calendar">Calendar</a>
        </nav>
        <form action={logoutAction}>
          <button className="button secondary sign-out" type="submit">Sign out</button>
        </form>
      </aside>

      <section className="review-main" aria-labelledby="dashboard-title">
        <header className="hero-row">
          <div>
            <p className="eyebrow">Core API review desk · {user.email}</p>
            <h1 id="dashboard-title">Review every recording without leaving the web.</h1>
            <p className="lede">Inbox, search, spaces, calendar, and detail views are backed by live Core data.</p>
          </div>
          <LiveRecordingStatus />
        </header>

        <section className="metrics-grid" aria-label="Recording metrics">
          <div><span>{data.recordings.length}</span><p>Total recordings</p></div>
          <div><span>{data.inboxCount}</span><p>Inbox</p></div>
          <div><span>{data.processingCount}</span><p>Processing</p></div>
          <div><span>{data.doneCount}</span><p>Ready</p></div>
          <div><span>{data.failedCount}</span><p>Needs review</p></div>
        </section>

        <section className="surface-grid two-column" id="capture">
          <RecordRecordingPanel />
          <UploadRecordingPanel />
        </section>

        <section className="surface-card search-card" id="search" aria-labelledby="search-title">
          <div>
            <p className="eyebrow">Search</p>
            <h2 id="search-title">Find summaries, transcripts, and spaces</h2>
          </div>
          <form className="search-form" action="/app">
            <input name="q" placeholder="Search recordings" defaultValue={query} aria-label="Search recordings" />
            <button className="button" type="submit">Search</button>
            {query ? <Link className="button secondary" href="/app">Clear</Link> : null}
          </form>
        </section>

        <section className="surface-grid two-column">
          <article className="surface-card" id="inbox" aria-labelledby="inbox-title">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Inbox</p>
                <h2 id="inbox-title">Latest recordings</h2>
              </div>
              <span>{data.recordings.length}</span>
            </div>
            <div className="recording-list">
              {data.recordings.map((recording) => (
                <Link className="recording-row" href={`/app/recordings/${recording.id}`} key={recording.id}>
                  <div>
                    <strong>{recording.title}</strong>
                    <p>{recording.summary || recording.transcript || 'Processing output is not ready yet.'}</p>
                    <small>{getSpaceName(data.spaces, recording.workspace_id)} · {formatDateTime(recording.inserted_at)} · {formatDuration(recording.duration)}</small>
                  </div>
                  <span className={`status-chip ${recording.status}`}>{statusLabel(recording.status)}</span>
                </Link>
              ))}
              {data.recordings.length === 0 ? <p className="empty-state">No recordings match this view.</p> : null}
            </div>
          </article>

          <article className="surface-card" id="spaces" aria-labelledby="spaces-title">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Spaces</p>
                <h2 id="spaces-title">Review by workspace</h2>
              </div>
              <span>{data.spaces.length}</span>
            </div>
            <div className="space-list">
              <div className="space-row">
                <div><strong>Inbox</strong><p>Unassigned recordings</p></div>
                <span>{data.inboxCount}</span>
              </div>
              {data.spaces.map((space) => {
                const count = data.recordings.filter((recording) => recording.workspace_id === space.id).length;

                return (
                  <div className="space-row" key={space.id}>
                    <div><strong>{space.name}</strong><p>{space.description || 'No description'}</p></div>
                    <span>{count}</span>
                  </div>
                );
              })}
              {data.spaces.length === 0 ? <p className="empty-state">No spaces yet.</p> : null}
            </div>
          </article>
        </section>

        <section className="surface-card" id="calendar" aria-labelledby="calendar-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Calendar</p>
              <h2 id="calendar-title">Recording days</h2>
            </div>
            <span>{data.calendarDays.length}</span>
          </div>
          <div className="calendar-grid">
            {data.calendarDays.map((day) => (
              <div className="calendar-day" key={day.key}>
                <strong>{day.label}</strong>
                <p>{day.recordings.length} recording{day.recordings.length === 1 ? '' : 's'}</p>
                {day.recordings.slice(0, 3).map((recording) => (
                  <Link href={`/app/recordings/${recording.id}`} key={recording.id}>{recording.title}</Link>
                ))}
              </div>
            ))}
            {data.calendarDays.length === 0 ? <p className="empty-state">No calendar activity yet.</p> : null}
          </div>
        </section>
      </section>
    </main>
  );
}
