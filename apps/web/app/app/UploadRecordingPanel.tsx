'use client';

import { useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { useTranslation } from 'react-i18next';
import type { Space } from '@matome/api-client';
import { createRecordingUploadAction, processRecordingUploadAction } from '@/app/actions';

type UploadState = 'idle' | 'creating' | 'uploading' | 'processing' | 'queued' | 'failed';

const acceptedTypes = ['audio/', 'image/'];

const inferMediaType = (file: File) => {
  if (file.type.startsWith('image/')) {
    return 'image';
  }

  return 'audio';
};

const isSupportedFile = (file: File) => acceptedTypes.some((prefix) => file.type.startsWith(prefix));

const titleFromFile = (file: File) => file.name.replace(/\.[^.]+$/, '').replace(/[-_]+/g, ' ').trim() || file.name;

export function UploadRecordingPanel({ spaces = [] }: { spaces?: Space[] }) {
  const router = useRouter();
  const { t } = useTranslation();
  const inputRef = useRef<HTMLInputElement>(null);
  const [state, setState] = useState<UploadState>('idle');
  const [message, setMessage] = useState('');
  const [targetSpace, setTargetSpace] = useState<string>('');
  const [isPending, startTransition] = useTransition();

  const uploadFile = async (file: File) => {
    if (!isSupportedFile(file)) {
      setState('failed');
      setMessage(t('web.uploadDrop'));
      return;
    }

    try {
      setState('creating');
      setMessage(t('recording.processing'));

      const { recording, upload } = await createRecordingUploadAction({
        title: titleFromFile(file),
        mediaType: inferMediaType(file),
        ...(targetSpace ? { workspaceId: Number(targetSpace) } : {}),
      });

      setState('uploading');
      setMessage(t('recording.processing'));

      const headers = new Headers(upload.headers ?? undefined);
      const response = await fetch(upload.url, {
        method: upload.method,
        headers,
        body: file,
      });

      if (!response.ok) {
        throw new Error(`Storage upload failed with status ${response.status}`);
      }

      setState('processing');
      setMessage(t('recording.processing'));
      await processRecordingUploadAction(recording.id);

      setState('queued');
      setMessage(t('recording.transcribing'));
      startTransition(() => router.refresh());
    } catch (error) {
      setState('failed');
      setMessage(error instanceof Error ? error.message : t('recording.saveFailed'));
    } finally {
      if (inputRef.current) {
        inputRef.current.value = '';
      }
    }
  };

  const onFiles = (files: FileList | null) => {
    const [file] = Array.from(files ?? []);

    if (file) {
      void uploadFile(file);
    }
  };

  return (
    <section className={`surface-card upload-card ${state}`} id="upload" aria-labelledby="upload-title">
      <div>
        <p className="eyebrow">{t('web.uploadEyebrow')}</p>
        <h2 id="upload-title">{t('web.uploadTitle')}</h2>
        <p className="body-copy">{t('web.uploadCopy')}</p>
      </div>
      {spaces.length > 0 ? (
        <label className="field">
          <span>{t('web.space')}</span>
          <select value={targetSpace} onChange={(event) => setTargetSpace(event.target.value)}>
            <option value="">{t('web.inboxLabel')}</option>
            {spaces.map((space) => (
              <option key={space.id} value={String(space.id)}>
                {space.name}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      <label
        className="upload-dropzone"
        onDragOver={(event) => event.preventDefault()}
        onDrop={(event) => {
          event.preventDefault();
          onFiles(event.dataTransfer.files);
        }}
      >
        <input
          ref={inputRef}
          type="file"
          accept="audio/*,image/*"
          disabled={state === 'creating' || state === 'uploading' || state === 'processing' || isPending}
          onChange={(event) => onFiles(event.currentTarget.files)}
        />
        <span>{state === 'idle' || state === 'failed' || state === 'queued' ? t('web.chooseFile') : t('web.working')}</span>
        <small>{message || t('web.uploadDrop')}</small>
      </label>
    </section>
  );
}
