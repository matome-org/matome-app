'use server';

import { redirect } from 'next/navigation';
import { createMatomeApiClient, MatomeApiError } from '@matome/api-client';
import { createServerApiClient } from '@/lib/api';
import { clearAuthCookies, getApiBaseUrl, setAuthCookies } from '@/lib/session';

type CreateRecordingUploadInput = {
  title: string;
  mediaType: string;
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

  return createServerApiClient().createRecording({ title, media_type: mediaType, status: 'pending' });
}

export async function processRecordingUploadAction(recordingId: number) {
  if (!Number.isInteger(recordingId)) {
    throw new Error('A valid recording id is required to queue processing.');
  }

  return createServerApiClient().processRecording(recordingId);
}
