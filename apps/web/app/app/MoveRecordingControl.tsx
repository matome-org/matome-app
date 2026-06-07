'use client';

import { useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { useTranslation } from 'react-i18next';
import type { Space } from '@matome/api-client';
import { patchRecordingAction } from '@/app/actions';

const INBOX_VALUE = 'inbox';

export function MoveRecordingControl({
  recordingId,
  currentWorkspaceId,
  spaces,
}: {
  recordingId: number;
  currentWorkspaceId?: number | null;
  spaces: Space[];
}) {
  const router = useRouter();
  const { t } = useTranslation();
  const [isPending, startTransition] = useTransition();

  const onChange = async (value: string) => {
    const workspaceId = value === INBOX_VALUE ? null : Number(value);
    await patchRecordingAction(recordingId, { workspaceId });
    startTransition(() => router.refresh());
  };

  return (
    <label className="move-control">
      <span className="sr-only">{t('spaces.title')}</span>
      <select
        defaultValue={currentWorkspaceId ? String(currentWorkspaceId) : INBOX_VALUE}
        disabled={isPending}
        onChange={(event) => void onChange(event.target.value)}
      >
        <option value={INBOX_VALUE}>Inbox</option>
        {spaces.map((space) => (
          <option key={space.id} value={String(space.id)}>
            {space.name}
          </option>
        ))}
      </select>
    </label>
  );
}
