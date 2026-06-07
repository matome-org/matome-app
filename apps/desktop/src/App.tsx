import { startTransition, useEffect, useState } from 'react';
import type { Recording, User } from '@matome/api-client';
import { invoke } from '@tauri-apps/api/core';
import { API_BASE_URL, clearSession, loadRecordings, login, restoreSession, uploadRecordingFile } from './api';

type LoadState = 'idle' | 'loading' | 'ready' | 'error';
type CaptureState = 'idle' | 'recording' | 'uploading';

type DesktopRecordingPayload = {
  file_name: string;
  mime_type: string;
  duration_seconds: number;
  bytes: number[];
};

const formatDate = (value: string) =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

const statusLabel = (status: Recording['status']) =>
  ({ pending: 'Pending', processing: 'Processing', done: 'Ready', failed: 'Needs review' })[status];

const titleFromFileName = (name: string) => name.replace(/\.[^.]+$/, '').replace(/[-_]+/g, ' ').trim() || name;

const mediaTypeFromFile = (file: File) => (file.type.startsWith('image/') ? 'image' : 'audio');

const isSupportedUpload = (file: File) => file.type.startsWith('audio/') || file.type.startsWith('image/');

export function App() {
  const [user, setUser] = useState<User | null>(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [query, setQuery] = useState('');
  const [recordings, setRecordings] = useState<Recording[]>([]);
  const [state, setState] = useState<LoadState>('loading');
  const [captureState, setCaptureState] = useState<CaptureState>('idle');
  const [captureMessage, setCaptureMessage] = useState('Record from the native microphone or drop audio/image media here.');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function boot() {
      const session = await restoreSession();

      if (cancelled) {
        return;
      }

      if (!session) {
        setState('idle');
        return;
      }

      setUser(session.user);
      await refreshRecordings();
    }

    void boot();

    return () => {
      cancelled = true;
    };
    // Mount-only session boot; refreshRecordings is intentionally not a dep.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function refreshRecordings(nextQuery = query) {
    setState('loading');
    setError(null);

    try {
      const nextRecordings = await loadRecordings(nextQuery.trim() || undefined);
      startTransition(() => {
        setRecordings(nextRecordings);
        setState('ready');
      });
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Unable to load recordings.');
      setState('error');
    }
  }

  async function handleLogin(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState('loading');
    setError(null);

    try {
      const session = await login(email.trim(), password);
      setUser(session.user);
      setPassword('');
      await refreshRecordings('');
    } catch (loginError) {
      setError(loginError instanceof Error ? loginError.message : 'Unable to sign in.');
      setState('idle');
    }
  }

  function handleLogout() {
    clearSession();
    setUser(null);
    setRecordings([]);
    setQuery('');
    setState('idle');
  }

  async function uploadDesktopFile(file: File, duration?: number) {
    if (!isSupportedUpload(file)) {
      setError('Choose an audio or image file so Core can route it through the processing pipeline.');
      return;
    }

    setCaptureState('uploading');
    setCaptureMessage(`Uploading ${file.name} through Core presigned storage...`);
    setError(null);

    try {
      await uploadRecordingFile({
        file,
        title: titleFromFileName(file.name),
        mediaType: mediaTypeFromFile(file),
        duration,
      });
      setCaptureMessage('Upload complete. Core processing has been queued.');
      await refreshRecordings();
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : 'Unable to upload recording.');
      setCaptureMessage('Upload failed before Core processing could be queued.');
    } finally {
      setCaptureState('idle');
    }
  }

  async function handleStartRecording() {
    setError(null);
    setCaptureMessage('Listening through the native microphone...');

    try {
      await invoke('start_desktop_recording');
      setCaptureState('recording');
    } catch (recordingError) {
      setCaptureMessage('Native microphone capture could not start.');
      setError(recordingError instanceof Error ? recordingError.message : String(recordingError));
    }
  }

  async function handleStopRecording() {
    setCaptureState('uploading');
    setCaptureMessage('Finalizing desktop WAV recording...');

    try {
      const recording = await invoke<DesktopRecordingPayload>('stop_desktop_recording');
      const file = new File([new Uint8Array(recording.bytes)], recording.file_name, { type: recording.mime_type });
      await uploadDesktopFile(file, recording.duration_seconds);
    } catch (recordingError) {
      setCaptureState('idle');
      setCaptureMessage('Native microphone capture could not finish.');
      setError(recordingError instanceof Error ? recordingError.message : String(recordingError));
    }
  }

  function handleDrop(event: React.DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    const [file] = Array.from(event.dataTransfer.files);

    if (file) {
      void uploadDesktopFile(file);
    }
  }

  if (!user) {
    return (
      <main className="desktop-auth-shell">
        <section className="auth-panel" aria-labelledby="login-title">
          <p className="eyebrow">Native Tauri desktop</p>
          <h1 id="login-title">Matome review desk</h1>
          <p className="lede">Sign in to the Core API at {API_BASE_URL} and review your recordings in a native shell.</p>
          <form className="form-stack" onSubmit={handleLogin}>
            <label className="field">
              <span>Email</span>
              <input autoComplete="email" inputMode="email" onChange={(event) => setEmail(event.target.value)} required type="email" value={email} />
            </label>
            <label className="field">
              <span>Password</span>
              <input autoComplete="current-password" onChange={(event) => setPassword(event.target.value)} required type="password" value={password} />
            </label>
            {error ? <p className="alert">{error}</p> : null}
            <button className="button" disabled={state === 'loading'} type="submit">
              {state === 'loading' ? 'Signing in...' : 'Sign in'}
            </button>
          </form>
        </section>
      </main>
    );
  }

  const readyCount = recordings.filter((recording) => recording.status === 'done').length;
  const processingCount = recordings.filter((recording) => recording.status === 'processing').length;
  const failedCount = recordings.filter((recording) => recording.status === 'failed').length;

  return (
    <main className="review-shell">
      <aside className="side-rail">
        <a className="brand" href="#top">Matome</a>
        <nav className="side-nav" aria-label="Desktop review surfaces">
          <a href="#inbox">Inbox</a>
          <a href="#search">Search</a>
          <a href="#recordings">Recordings</a>
        </nav>
        <button className="button secondary sign-out" onClick={handleLogout} type="button">Sign out</button>
      </aside>

      <section className="review-main" id="top" aria-labelledby="dashboard-title">
        <header className="hero-row">
          <div>
            <p className="eyebrow">Desktop review desk · {user.email}</p>
            <h1 id="dashboard-title">Native shell, shared Matome data.</h1>
            <p className="lede">This Tauri app reuses the workspace API client and design tokens to read live Core recordings.</p>
          </div>
          <button className="button secondary" disabled={state === 'loading'} onClick={() => void refreshRecordings()} type="button">
            {state === 'loading' ? 'Refreshing...' : 'Refresh'}
          </button>
        </header>

        <section className={`surface-card capture-card ${captureState}`} id="capture" aria-labelledby="capture-title">
          <div>
            <p className="eyebrow">Native capture</p>
            <h2 id="capture-title">Record or drop media into Core</h2>
            <p className="lede">Desktop is the native capture surface: microphone audio becomes a WAV file, while dropped files use the same presigned upload and process flow.</p>
          </div>
          <div className="capture-actions">
            {captureState === 'recording' ? (
              <button className="button danger" onClick={() => void handleStopRecording()} type="button">Stop and upload</button>
            ) : (
              <button className="button" disabled={captureState === 'uploading'} onClick={() => void handleStartRecording()} type="button">
                {captureState === 'uploading' ? 'Working...' : 'Start mic recording'}
              </button>
            )}
            <label className="desktop-dropzone" onDragOver={(event) => event.preventDefault()} onDrop={handleDrop}>
              <input
                accept="audio/*,image/*"
                disabled={captureState !== 'idle'}
                onChange={(event) => {
                  const [file] = Array.from(event.currentTarget.files ?? []);
                  if (file) {
                    void uploadDesktopFile(file);
                  }
                  event.currentTarget.value = '';
                }}
                type="file"
              />
              <span>{captureState === 'recording' ? 'Recording in progress' : 'Drop or choose media'}</span>
              <small>{captureMessage}</small>
            </label>
          </div>
        </section>

        <section className="metrics-grid" id="inbox" aria-label="Recording metrics">
          <div><span>{recordings.length}</span><p>Total recordings</p></div>
          <div><span>{processingCount}</span><p>Processing</p></div>
          <div><span>{readyCount}</span><p>Ready</p></div>
          <div><span>{failedCount}</span><p>Needs review</p></div>
        </section>

        <section className="surface-card search-card" id="search" aria-labelledby="search-title">
          <div>
            <p className="eyebrow">Search</p>
            <h2 id="search-title">Find summaries and transcripts</h2>
          </div>
          <form className="search-form" onSubmit={(event) => { event.preventDefault(); void refreshRecordings(); }}>
            <input aria-label="Search recordings" onChange={(event) => setQuery(event.target.value)} placeholder="Search recordings" value={query} />
            <button className="button" disabled={state === 'loading'} type="submit">Search</button>
            {query ? <button className="button secondary" onClick={() => { setQuery(''); void refreshRecordings(''); }} type="button">Clear</button> : null}
          </form>
        </section>

        {error ? <p className="alert">{error}</p> : null}

        <section className="surface-card" id="recordings" aria-labelledby="recordings-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Recordings</p>
              <h2 id="recordings-title">Latest Core API results</h2>
            </div>
            <span>{state === 'loading' ? 'Loading' : `${recordings.length}`}</span>
          </div>
          <div className="recording-list">
            {recordings.map((recording) => (
              <article className="recording-row" key={recording.id}>
                <div>
                  <strong>{recording.title}</strong>
                  <p>{recording.summary || recording.transcript || 'Processing output is not ready yet.'}</p>
                  <small>{formatDate(recording.inserted_at)}{recording.duration ? ` · ${Math.round(recording.duration)}s` : ''}</small>
                </div>
                <span className={`status-chip ${recording.status}`}>{statusLabel(recording.status)}</span>
              </article>
            ))}
            {state !== 'loading' && recordings.length === 0 ? <p className="empty-state">No recordings match this view.</p> : null}
          </div>
        </section>
      </section>
    </main>
  );
}
