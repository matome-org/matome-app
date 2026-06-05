import { cookies } from 'next/headers';
import { cache } from 'react';
import { createMatomeApiClient, MatomeApiError, type AuthResponse, type User } from '@matome/api-client';
import {
  ACCESS_TOKEN_COOKIE,
  ACCESS_TOKEN_MAX_AGE_SECONDS,
  REFRESH_TOKEN_COOKIE,
  REFRESH_TOKEN_MAX_AGE_SECONDS,
  authCookieOptions,
} from './auth-cookies';
import { getApiBaseUrl } from './api-base';

export { getApiBaseUrl };

export const setAuthCookies = async (auth: AuthResponse) => {
  const cookieStore = await cookies();

  cookieStore.set(ACCESS_TOKEN_COOKIE, auth.access_token, {
    ...authCookieOptions,
    maxAge: ACCESS_TOKEN_MAX_AGE_SECONDS,
  });
  cookieStore.set(REFRESH_TOKEN_COOKIE, auth.refresh_token, {
    ...authCookieOptions,
    maxAge: REFRESH_TOKEN_MAX_AGE_SECONDS,
  });
};

export const clearAuthCookies = async () => {
  const cookieStore = await cookies();

  cookieStore.delete(ACCESS_TOKEN_COOKIE);
  cookieStore.delete(REFRESH_TOKEN_COOKIE);
};

export const getAccessToken = async () => {
  const cookieStore = await cookies();

  return cookieStore.get(ACCESS_TOKEN_COOKIE)?.value;
};

export const getCurrentUser = cache(async (): Promise<User | null> => {
  const accessToken = await getAccessToken();

  if (!accessToken) {
    return null;
  }

  const client = createMatomeApiClient({
    baseUrl: getApiBaseUrl(),
    accessToken,
  });

  try {
    const { user } = await client.me();
    return user;
  } catch (error) {
    if (error instanceof MatomeApiError && error.status === 401) {
      return null;
    }

    throw error;
  }
});
