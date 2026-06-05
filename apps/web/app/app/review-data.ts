import type { Recording, RecordingStatus, Space } from '@matome/api-client';
import { createServerApiClient } from '@/lib/api';

export type CalendarDay = {
  key: string;
  label: string;
  recordings: Recording[];
};

export type ReviewData = {
  recordings: Recording[];
  spaces: Space[];
  calendarDays: CalendarDay[];
  inboxCount: number;
  processingCount: number;
  doneCount: number;
  failedCount: number;
};

const statusRank: Record<RecordingStatus, number> = {
  processing: 0,
  pending: 1,
  failed: 2,
  done: 3,
};

export const formatDateTime = (value: string) =>
  new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

export const formatDuration = (duration?: number | null) => {
  if (!duration) {
    return 'No duration';
  }

  const minutes = Math.floor(duration / 60);
  const seconds = Math.round(duration % 60);

  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

export const statusLabel = (status: RecordingStatus) =>
  status.charAt(0).toUpperCase() + status.slice(1);

export const getSpaceName = (spaces: Space[], workspaceId?: number | null) => {
  if (!workspaceId) {
    return 'Inbox';
  }

  return spaces.find((space) => space.id === workspaceId)?.name ?? 'Unknown space';
};

export const buildCalendarDays = (recordings: Recording[]): CalendarDay[] => {
  const days = new Map<string, CalendarDay>();

  for (const recording of recordings) {
    const date = new Date(recording.inserted_at);
    const key = date.toISOString().slice(0, 10);
    const label = new Intl.DateTimeFormat('en', {
      weekday: 'long',
      month: 'short',
      day: 'numeric',
    }).format(date);

    const day = days.get(key) ?? { key, label, recordings: [] };
    day.recordings.push(recording);
    days.set(key, day);
  }

  return Array.from(days.values());
};

export const sortRecordings = (recordings: Recording[]) =>
  [...recordings].sort((first, second) => {
    const statusDelta = statusRank[first.status] - statusRank[second.status];

    if (statusDelta !== 0) {
      return statusDelta;
    }

    return new Date(second.inserted_at).getTime() - new Date(first.inserted_at).getTime();
  });

export const loadReviewData = async (query?: string): Promise<ReviewData> => {
  const api = createServerApiClient();
  const normalizedQuery = query?.trim();
  const [{ recordings }, { workspaces }] = await Promise.all([
    normalizedQuery ? api.searchRecordings({ q: normalizedQuery }) : api.listRecordings(),
    normalizedQuery ? api.searchSpaces({ q: normalizedQuery }) : api.listSpaces(),
  ]);
  const sortedRecordings = sortRecordings(recordings);

  return {
    recordings: sortedRecordings,
    spaces: workspaces,
    calendarDays: buildCalendarDays(sortedRecordings),
    inboxCount: sortedRecordings.filter((recording) => recording.workspace_id == null).length,
    processingCount: sortedRecordings.filter((recording) => recording.status === 'processing' || recording.status === 'pending').length,
    doneCount: sortedRecordings.filter((recording) => recording.status === 'done').length,
    failedCount: sortedRecordings.filter((recording) => recording.status === 'failed').length,
  };
};
