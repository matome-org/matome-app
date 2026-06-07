'use server';

import { redirect } from 'next/navigation';
import { createMatomeApiClient, MatomeApiError, type RecordingPatch } from '@matome/api-client';
import { createServerApiClient } from '@/lib/api';
import { clearAuthCookies, getApiBaseUrl, setAuthCookies } from '@/lib/session';

type CreateRecordingUploadInput = {
  title: string;
  mediaType: string;
  duration?: number;
  workspaceId?: number;
};

export async function loginAction(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');

  if (!email || !password) {
    redirect('/login?error=missing_credentials');
  }

  const client = createMatomeApiClient({ baseUrl: getApiBaseUrl() });

  try {
    const auth = await client.login({ email, password });
    await setAuthCookies(auth);
  } catch (error) {
    if (error instanceof MatomeApiError && error.status === 401) {
      redirect('/login?error=invalid_credentials');
    }

    throw error;
  }

  redirect('/app');
}

export async function logoutAction() {
  await clearAuthCookies();
  redirect('/login');
}

export async function createRecordingUploadAction(input: CreateRecordingUploadInput) {
  const title = input.title.trim();
  const mediaType = input.mediaType.trim();

  if (!title || !mediaType) {
    throw new Error('A title and media type are required before upload.');
  }

  const duration =
    typeof input.duration === 'number' && Number.isFinite(input.duration) && input.duration >= 0
      ? Math.round(input.duration)
      : undefined;
  const workspaceId =
    typeof input.workspaceId === 'number' && Number.isInteger(input.workspaceId)
      ? input.workspaceId
      : undefined;

  return createServerApiClient().createRecording({
    title,
    media_type: mediaType,
    status: 'pending',
    ...(duration !== undefined ? { duration } : {}),
    ...(workspaceId !== undefined ? { workspace_id: workspaceId } : {}),
  });
}

export async function processRecordingUploadAction(recordingId: number) {
  if (!Number.isInteger(recordingId)) {
    throw new Error('A valid recording id is required to queue processing.');
  }

  return createServerApiClient().processRecording(recordingId);
}

export async function patchRecordingAction(
  recordingId: number,
  patch: { title?: string; transcript?: string; workspaceId?: number | null },
) {
  if (!Number.isInteger(recordingId)) {
    throw new Error('A valid recording id is required.');
  }

  const body: { title?: string; transcript?: string; workspace_id?: number | null } = {};

  if (typeof patch.title === 'string') {
    body.title = patch.title.trim();
  }

  if (typeof patch.transcript === 'string') {
    body.transcript = patch.transcript;
  }

  if (patch.workspaceId === null) {
    // Move back to Inbox: Core treats a null workspace_id as unassigned
    // (validate_workspace_owner short-circuits on nil).
    body.workspace_id = null;
  } else if (typeof patch.workspaceId === 'number' && Number.isInteger(patch.workspaceId)) {
    body.workspace_id = patch.workspaceId;
  }

  return createServerApiClient().patchRecording(recordingId, body as RecordingPatch);
}

export async function getRecordingDownloadUrlAction(recordingId: number) {
  if (!Number.isInteger(recordingId)) {
    throw new Error('A valid recording id is required.');
  }

  return createServerApiClient().getRecordingDownloadUrl(recordingId);
}

export async function createSpaceAction(input: { name: string; description?: string }) {
  const name = input.name.trim();

  if (!name) {
    throw new Error('A space name is required.');
  }

  const description = input.description?.trim();

  return createServerApiClient().createSpace({
    name,
    ...(description ? { description } : {}),
  });
}

export async function updateSpaceAction(
  spaceId: number,
  input: { name?: string; description?: string },
) {
  if (!Number.isInteger(spaceId)) {
    throw new Error('A valid space id is required.');
  }

  const body: { name?: string; description?: string } = {};

  if (typeof input.name === 'string' && input.name.trim()) {
    body.name = input.name.trim();
  }

  if (typeof input.description === 'string') {
    body.description = input.description.trim();
  }

  return createServerApiClient().patchSpace(spaceId, body);
}

export async function deleteSpaceAction(spaceId: number) {
  if (!Number.isInteger(spaceId)) {
    throw new Error('A valid space id is required.');
  }

  return createServerApiClient().deleteSpace(spaceId);
}
