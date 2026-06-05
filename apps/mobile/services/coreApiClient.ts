import { createMatomeApiClient } from '@matome/api-client';

import {
  getRefreshToken,
  getToken,
  removeRefreshToken,
  removeToken,
  saveRefreshToken,
  saveToken,
} from '@/utils/storage';

const DEFAULT_CORE_API_URL = 'http://localhost:4000';

export const CORE_API_URL =
  process.env.EXPO_PUBLIC_CORE_API_URL || DEFAULT_CORE_API_URL;

const refreshCoreToken = async (): Promise<string | undefined> => {
  const refreshToken = await getRefreshToken();
  if (!refreshToken) return undefined;

  const response = await fetch(new URL('/api/auth/refresh', CORE_API_URL).toString(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });

  if (!response.ok) {
    await Promise.all([removeToken(), removeRefreshToken()]);
    return undefined;
  }

  const auth = await response.json();
  if (typeof auth?.access_token !== 'string' || typeof auth?.refresh_token !== 'string') {
    await Promise.all([removeToken(), removeRefreshToken()]);
    return undefined;
  }

  await saveToken(auth.access_token);
  await saveRefreshToken(auth.refresh_token);
  return auth.access_token;
};

const authorizedFetch = async (
  input: RequestInfo | URL,
  init: RequestInit = {},
): Promise<Response> => {
  const requestWithToken = async (token: string | null): Promise<Response> => {
    const headers = new Headers(init.headers);
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
    }

    return fetch(input, { ...init, headers });
  };

  const response = await requestWithToken(await getToken());
  if (response.status !== 401) {
    return response;
  }

  const refreshedToken = await refreshCoreToken();
  if (!refreshedToken) {
    return response;
  }

  return requestWithToken(refreshedToken);
};

export const coreApiClient = createMatomeApiClient({
  baseUrl: CORE_API_URL,
  accessToken: async () => (await getToken()) ?? undefined,
  fetch: authorizedFetch,
});

export const coreApiFetch = async (
  path: string,
  options: RequestInit = {},
): Promise<Response> => {
  const headers = new Headers(options.headers);

  return authorizedFetch(new URL(path, CORE_API_URL).toString(), {
    ...options,
    headers,
  });
};
