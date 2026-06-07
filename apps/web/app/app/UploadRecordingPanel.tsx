'use client';

import { useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
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
  const inputRef = useRef<HTMLInputElement>(null);
  const [state, setState] = useState<UploadState>('idle');
  const [message, setMessage] = useState('Drop audio or image media here, or choose a file.');
  const [targetSpace, setTargetSpace] = useState<string>('');
  const [isPending, startTransition] = useTransition();

  const uploadFile = async (file: File) => {
    if (!isSupportedFile(file)) {
      setState('failed');
      setMessage('Choose an audio or image file so Core can route it through the AI pipeline.');
      return;
    }

    try {
      setState('creating');
      setMessage(`Creating pending recording for ${file.name}...`);

      const { recording, upload } = await createRecordingUploadAction({
        title: titleFromFile(file),
        mediaType: inferMediaType(file),
        ...(targetSpace ? { workspaceId: Number(targetSpace) } : {}),
      });

      setState('uploading');
      setMessage('Uploading media directly to Storage with Core presigned URL...');

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
      setMessage('Upload complete. Asking Core to queue processing...');
      await processRecordingUploadAction(recording.id);

      setState('queued');
      setMessage('Processing queued. Live Channels will refresh this dashboard as status changes.');
      startTransition(() => router.refresh());
    } catch (error) {
      setState('failed');
      setMessage(error instanceof Error ? error.message : 'Upload failed before processing could be queued.');
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
        <p className="eyebrow">Upload</p>
        <h2 id="upload-title">Send media through Core</h2>
        <p className="body-copy">Web stays upload-only: it creates a pending recording, uses Core&apos;s presigned Storage URL, then watches Channels for status.</p>
      </div>
      {spaces.length > 0 ? (
        <label className="field">
          <span>Space</span>
          <select value={targetSpace} onChange={(event) => setTargetSpace(event.target.value)}>
            <option value="">Inbox</option>
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
        <span>{state === 'idle' || state === 'failed' || state === 'queued' ? 'Choose file' : 'Working...'}</span>
        <small>{message}</small>
      </label>
    </section>
  );
}
