import { createMatomeApiClient, type AuthResponse, type Recording, type User } from '@matome/api-client';

const API_BASE_URL = import.meta.env.VITE_MATOME_CORE_API_URL ?? 'http://127.0.0.1:4000';
const ACCESS_TOKEN_KEY = 'matome.desktop.accessToken';
const REFRESH_TOKEN_KEY = 'matome.desktop.refreshToken';

export type DesktopSession = {
  user: User;
  accessToken: string;
  refreshToken: string;
};

const getStoredAccessToken = () => localStorage.getItem(ACCESS_TOKEN_KEY) ?? undefined;

const api = createMatomeApiClient({
  baseUrl: API_BASE_URL,
  accessToken: getStoredAccessToken,
});

const persistSession = (auth: AuthResponse): DesktopSession => {
  localStorage.setItem(ACCESS_TOKEN_KEY, auth.access_token);
  localStorage.setItem(REFRESH_TOKEN_KEY, auth.refresh_token);

  return {
    user: auth.user,
    accessToken: auth.access_token,
    refreshToken: auth.refresh_token,
  };
};

export async function login(email: string, password: string) {
  return persistSession(await api.login({ email, password }));
}

export async function restoreSession(): Promise<DesktopSession | null> {
  const accessToken = localStorage.getItem(ACCESS_TOKEN_KEY);
  const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);

  if (!accessToken || !refreshToken) {
    return null;
  }

  try {
    const { user } = await api.me();

    return { user, accessToken, refreshToken };
  } catch {
    clearSession();
    return null;
  }
}

export async function loadRecordings(query?: string): Promise<Recording[]> {
  const { recordings } = await api.listRecordings(query ? { q: query } : undefined);
  return recordings;
}

export type UploadRecordingFileInput = {
  file: Blob;
  title: string;
  mediaType: string;
  duration?: number;
};

export async function uploadRecordingFile({ file, title, mediaType, duration }: UploadRecordingFileInput): Promise<Recording> {
  const { recording, upload } = await api.createRecording({
    title,
    media_type: mediaType,
    duration,
    status: 'pending',
  });
  const uploadResponse = await fetch(upload.url, {
    method: upload.method,
    headers: upload.headers ?? {},
    body: file,
  });

  if (!uploadResponse.ok) {
    throw new Error(`Storage upload failed with status ${uploadResponse.status}`);
  }

  const { recording: processingRecording } = await api.processRecording(recording.id);
  return processingRecording;
}

export function clearSession() {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}

export { API_BASE_URL };
