'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useTranslation } from 'react-i18next';
import { createRecordingUploadAction, processRecordingUploadAction } from '@/app/actions';

type RecorderStatus =
  | 'idle'
  | 'recording'
  | 'paused'
  | 'saving'
  | 'queued'
  | 'failed'
  | 'unsupported';

const BAR_COUNT = 48;

function pickMimeType(): string | undefined {
  if (typeof MediaRecorder === 'undefined') {
    return undefined;
  }

  const candidates = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/ogg'];
  return candidates.find((type) => MediaRecorder.isTypeSupported(type));
}

const formatElapsed = (ms: number) => {
  const total = Math.floor(ms / 1000);
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

export function RecordRecordingPanel() {
  const router = useRouter();
  const { t } = useTranslation();

  const [status, setStatus] = useState<RecorderStatus>('idle');
  const [elapsedMs, setElapsedMs] = useState(0);
  const [message, setMessage] = useState('');
  const [title, setTitle] = useState('');

  const recorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const startedAtRef = useRef(0);
  const accumulatedRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const isActive = status === 'recording' || status === 'paused' || status === 'saving';

  useEffect(() => {
    // Client-only feature detection: MediaRecorder is undefined during SSR, so
    // we keep the initial render as 'idle' and downgrade here once mounted.
    if (!pickMimeType()) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setStatus('unsupported');
    }
  }, []);

  // Warn before leaving with an in-progress recording (online-first: no persisted draft).
  useEffect(() => {
    if (!isActive) {
      return;
    }

    const handler = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = '';
    };

    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [isActive]);

  const stopDrawing = useCallback(() => {
    if (rafRef.current !== null) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }
  }, []);

  const drawWaveform = useCallback(() => {
    const canvas = canvasRef.current;
    const analyser = analyserRef.current;

    if (!canvas || !analyser) {
      return;
    }

    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return;
    }

    const data = new Uint8Array(analyser.frequencyBinCount);

    const render = () => {
      analyser.getByteFrequencyData(data);
      const { width, height } = canvas;
      ctx.clearRect(0, 0, width, height);

      const step = Math.floor(data.length / BAR_COUNT) || 1;
      const barWidth = width / BAR_COUNT;
      const accent = getComputedStyle(canvas).getPropertyValue('color') || '#6366f1';
      ctx.fillStyle = accent.trim() || '#6366f1';

      for (let i = 0; i < BAR_COUNT; i += 1) {
        const value = data[i * step] / 255;
        const barHeight = Math.max(2, value * height);
        ctx.fillRect(i * barWidth + 1, (height - barHeight) / 2, barWidth - 2, barHeight);
      }

      rafRef.current = requestAnimationFrame(render);
    };

    render();
  }, []);

  const teardownStream = useCallback(() => {
    stopDrawing();

    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;

    if (audioCtxRef.current && audioCtxRef.current.state !== 'closed') {
      void audioCtxRef.current.close();
    }
    audioCtxRef.current = null;
    analyserRef.current = null;
    recorderRef.current = null;
  }, [stopDrawing]);

  useEffect(() => () => teardownStream(), [teardownStream]);

  const tickTimer = useCallback(() => {
    setElapsedMs(accumulatedRef.current + (Date.now() - startedAtRef.current));
  }, []);

  const uploadRecording = useCallback(
    async (blob: Blob, mimeType: string, durationSeconds: number) => {
      try {
        setStatus('saving');
        setMessage(t('recording.processing'));

        const finalTitle =
          title.trim() || `${t('recording.title')} ${new Date().toLocaleString()}`;
        const { recording, upload } = await createRecordingUploadAction({
          title: finalTitle,
          mediaType: 'audio',
          duration: durationSeconds,
        });

        const headers = new Headers(upload.headers ?? undefined);
        if (!headers.has('content-type')) {
          headers.set('content-type', mimeType);
        }

        const response = await fetch(upload.url, { method: upload.method, headers, body: blob });
        if (!response.ok) {
          throw new Error(`Storage upload failed with status ${response.status}`);
        }

        await processRecordingUploadAction(recording.id);

        setStatus('queued');
        setMessage(t('recording.transcribing'));
        setTitle('');
        setElapsedMs(0);
        accumulatedRef.current = 0;
        router.refresh();
      } catch (error) {
        setStatus('failed');
        setMessage(error instanceof Error ? error.message : t('recording.saveFailed'));
      }
    },
    [router, t, title],
  );

  const startRecording = useCallback(async () => {
    const mimeType = pickMimeType();
    if (!mimeType) {
      setStatus('unsupported');
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      chunksRef.current = [];

      const recorder = new MediaRecorder(stream, { mimeType });
      recorderRef.current = recorder;

      const audioCtx = new AudioContext();
      audioCtxRef.current = audioCtx;
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 256;
      analyserRef.current = analyser;
      audioCtx.createMediaStreamSource(stream).connect(analyser);

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mimeType });
        const durationSeconds = Math.round(accumulatedRef.current / 1000);
        teardownStream();
        if (blob.size > 0) {
          void uploadRecording(blob, mimeType, durationSeconds);
        } else {
          setStatus('idle');
          setMessage('');
        }
      };

      recorder.start(250);
      accumulatedRef.current = 0;
      startedAtRef.current = Date.now();
      setElapsedMs(0);
      timerRef.current = setInterval(tickTimer, 200);
      setStatus('recording');
      setMessage('');
      drawWaveform();
    } catch {
      setStatus('failed');
      setMessage(t('recording.startFailed'));
    }
  }, [drawWaveform, t, teardownStream, tickTimer, uploadRecording]);

  const pauseRecording = useCallback(() => {
    const recorder = recorderRef.current;
    if (recorder?.state === 'recording') {
      recorder.pause();
      accumulatedRef.current += Date.now() - startedAtRef.current;
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
      stopDrawing();
      setStatus('paused');
    }
  }, [stopDrawing]);

  const resumeRecording = useCallback(() => {
    const recorder = recorderRef.current;
    if (recorder?.state === 'paused') {
      recorder.resume();
      startedAtRef.current = Date.now();
      timerRef.current = setInterval(tickTimer, 200);
      drawWaveform();
      setStatus('recording');
    }
  }, [drawWaveform, tickTimer]);

  const finishRecording = useCallback(() => {
    const recorder = recorderRef.current;
    if (recorder && recorder.state !== 'inactive') {
      if (recorder.state === 'recording') {
        accumulatedRef.current += Date.now() - startedAtRef.current;
      }
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
      stopDrawing();
      recorder.stop();
    }
  }, [stopDrawing]);

  const cancelRecording = useCallback(() => {
    const recorder = recorderRef.current;
    chunksRef.current = [];
    if (recorder && recorder.state !== 'inactive') {
      recorder.onstop = null;
      recorder.stop();
    }
    teardownStream();
    accumulatedRef.current = 0;
    setElapsedMs(0);
    setStatus('idle');
    setMessage('');
  }, [teardownStream]);

  if (status === 'unsupported') {
    return (
      <section className="surface-card record-card" aria-labelledby="record-title">
        <div>
          <p className="eyebrow">{t('recording.title')}</p>
          <h2 id="record-title">{t('recording.webUnavailableTitle')}</h2>
          <p className="body-copy">{t('recording.webUnavailableHint')}</p>
        </div>
      </section>
    );
  }

  return (
    <section className={`surface-card record-card ${status}`} aria-labelledby="record-title">
      <div>
        <p className="eyebrow">{t('recording.title')}</p>
        <h2 id="record-title">{t('recording.ready')}</h2>
        <p className="body-copy">
          {status === 'recording'
            ? t('recording.stopHint')
            : status === 'paused'
              ? t('recording.resumeHint')
              : t('recording.startHint')}
        </p>
      </div>

      <div className="record-stage">
        <canvas ref={canvasRef} width={480} height={64} className="record-waveform" aria-hidden />
        <span className="record-elapsed" role="timer">
          {formatElapsed(elapsedMs)}
        </span>
      </div>

      <label className="field">
        <span>{t('web.titleLabel')}</span>
        <input
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder={`${t('recording.title')}…`}
          disabled={status === 'saving' || status === 'queued'}
        />
      </label>

      <div className="record-controls">
        {status === 'idle' || status === 'queued' || status === 'failed' ? (
          <button className="button" type="button" onClick={() => void startRecording()}>
            {t('recording.ready')}
          </button>
        ) : null}
        {status === 'recording' ? (
          <button className="button secondary" type="button" onClick={pauseRecording}>
            {t('recording.pause')}
          </button>
        ) : null}
        {status === 'paused' ? (
          <button className="button secondary" type="button" onClick={resumeRecording}>
            {t('recording.draftResume')}
          </button>
        ) : null}
        {status === 'recording' || status === 'paused' ? (
          <>
            <button className="button" type="button" onClick={finishRecording}>
              {t('recording.finish')}
            </button>
            <button className="button ghost" type="button" onClick={cancelRecording}>
              {t('common.cancel')}
            </button>
          </>
        ) : null}
      </div>

      {message ? <small className="record-message">{message}</small> : null}
    </section>
  );
}
