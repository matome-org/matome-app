'use client';

import { useCallback, useEffect, useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { useTranslation } from 'react-i18next';
import type { Recording } from '@matome/api-client';
import {
  getRecordingDownloadUrlAction,
  patchRecordingAction,
  processRecordingUploadAction,
} from '@/app/actions';

const formatClock = (seconds: number) => {
  if (!Number.isFinite(seconds)) {
    return '0:00';
  }
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

function AudioPlayer({ recordingId }: { recordingId: number }) {
  const { t } = useTranslation();
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [src, setSrc] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [playing, setPlaying] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const { download } = await getRecordingDownloadUrlAction(recordingId);
      setSrc(download.url);
    } catch {
      setError(t('toast.audioFailed'));
    } finally {
      setLoading(false);
    }
  }, [recordingId, t]);

  const togglePlay = useCallback(() => {
    const audio = audioRef.current;
    if (!audio) {
      return;
    }
    if (audio.paused) {
      void audio.play();
    } else {
      audio.pause();
    }
  }, []);

  if (!src) {
    return (
      <div className="audio-player">
        <button className="button secondary" type="button" onClick={() => void load()} disabled={loading}>
          {loading ? t('recording.loading') : '▶ ' + t('details.summary')}
        </button>
        {error ? <small className="record-message">{error}</small> : null}
      </div>
    );
  }

  return (
    <div className={`audio-player ${playing ? 'is-playing' : ''}`}>
      <audio
        ref={audioRef}
        src={src}
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
        onTimeUpdate={(event) => setPosition(event.currentTarget.currentTime)}
        onLoadedMetadata={(event) => setDuration(event.currentTarget.duration)}
        onEnded={() => setPlaying(false)}
        onError={() => setError(t('toast.audioFailed'))}
      />
      <button className="button" type="button" onClick={togglePlay} aria-label="play/pause">
        {playing ? '❚❚' : '▶'}
      </button>
      <div className="audio-equalizer" aria-hidden>
        {Array.from({ length: 16 }).map((_, index) => (
          <span key={index} style={{ animationDelay: `${index * 60}ms` }} />
        ))}
      </div>
      <input
        type="range"
        min={0}
        max={duration || 0}
        step={0.1}
        value={position}
        onChange={(event) => {
          const audio = audioRef.current;
          if (audio) {
            audio.currentTime = Number(event.target.value);
            setPosition(Number(event.target.value));
          }
        }}
        aria-label="seek"
      />
      <span className="audio-clock">
        {formatClock(position)} / {formatClock(duration)}
      </span>
      {error ? <small className="record-message">{error}</small> : null}
    </div>
  );
}

export function RecordingDetailClient({ recording }: { recording: Recording }) {
  const router = useRouter();
  const { t } = useTranslation();
  const [isPending, startTransition] = useTransition();

  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState(recording.title);
  const [transcript, setTranscript] = useState(recording.transcript ?? '');
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const dirty = editing && (title !== recording.title || transcript !== (recording.transcript ?? ''));

  // Unsaved-changes guard.
  useEffect(() => {
    if (!dirty) {
      return;
    }
    const handler = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = '';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [dirty]);

  const save = useCallback(async () => {
    try {
      setSaving(true);
      setMessage(null);
      await patchRecordingAction(recording.id, { title: title.trim() || recording.title, transcript });
      setEditing(false);
      setMessage(t('toast.notesSaved'));
      startTransition(() => router.refresh());
    } catch {
      setMessage(t('toast.notesFailed'));
    } finally {
      setSaving(false);
    }
  }, [recording.id, recording.title, router, t, title, transcript]);

  const cancelEdit = useCallback(() => {
    if (dirty && !window.confirm(t('recording.draftHint'))) {
      return;
    }
    setTitle(recording.title);
    setTranscript(recording.transcript ?? '');
    setEditing(false);
    setMessage(null);
  }, [dirty, recording.title, recording.transcript, t]);

  const retry = useCallback(async () => {
    try {
      setMessage(null);
      await processRecordingUploadAction(recording.id);
      setMessage(t('recording.processing'));
      startTransition(() => router.refresh());
    } catch {
      setMessage(t('recording.transcriptionFailed'));
    }
  }, [recording.id, router, t]);

  return (
    <div className="detail-interactive">
      <article className="surface-card span-3" aria-label="player">
        <p className="eyebrow">{t('recording.title')}</p>
        <AudioPlayer recordingId={recording.id} />
        {recording.status === 'failed' ? (
          <div className="retry-row">
            <p className="alert">{recording.error_reason ?? t('recording.transcriptionFailed')}</p>
            <button className="button" type="button" onClick={() => void retry()}>
              {t('common.retry')}
            </button>
          </div>
        ) : null}
      </article>

      <article className="surface-card span-3" aria-labelledby="notes-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">{t('details.notes')}</p>
            <h2 id="notes-title">{recording.title}</h2>
          </div>
          {editing ? (
            <div className="record-controls">
              <button className="button" type="button" onClick={() => void save()} disabled={saving || isPending}>
                {t('common.save')}
              </button>
              <button className="button ghost" type="button" onClick={cancelEdit} disabled={saving}>
                {t('common.cancel')}
              </button>
            </div>
          ) : (
            <button className="button secondary" type="button" onClick={() => setEditing(true)}>
              {t('details.edit')}
            </button>
          )}
        </div>

        {editing ? (
          <div className="form-stack">
            <label className="field">
              <span>{t('details.notes')}</span>
              <input value={title} onChange={(event) => setTitle(event.target.value)} />
            </label>
            <label className="field">
              <span>{t('details.summary')}</span>
              <textarea
                rows={8}
                value={transcript}
                onChange={(event) => setTranscript(event.target.value)}
                placeholder={t('details.notesPlaceholder')}
              />
            </label>
          </div>
        ) : (
          <p className="transcript-copy">
            {recording.transcript || t('details.noSummary')}
          </p>
        )}
        {message ? <small className="record-message">{message}</small> : null}
      </article>
    </div>
  );
}
