import { NextResponse, type NextRequest } from 'next/server';
import { createMatomeApiClient, MatomeApiError, type AuthResponse } from '@matome/api-client';
import {
  ACCESS_TOKEN_COOKIE,
  ACCESS_TOKEN_MAX_AGE_SECONDS,
  REFRESH_TOKEN_COOKIE,
  REFRESH_TOKEN_MAX_AGE_SECONDS,
  authCookieOptions,
} from './lib/auth-cookies';
import { getApiBaseUrl } from './lib/api-base';

const setAuthCookies = (response: NextResponse, auth: AuthResponse) => {
  response.cookies.set(ACCESS_TOKEN_COOKIE, auth.access_token, {
    ...authCookieOptions,
    maxAge: ACCESS_TOKEN_MAX_AGE_SECONDS,
  });
  response.cookies.set(REFRESH_TOKEN_COOKIE, auth.refresh_token, {
    ...authCookieOptions,
    maxAge: REFRESH_TOKEN_MAX_AGE_SECONDS,
  });
};

const clearAuthCookies = (response: NextResponse) => {
  response.cookies.delete(ACCESS_TOKEN_COOKIE);
  response.cookies.delete(REFRESH_TOKEN_COOKIE);
};

const redirectToLogin = (request: NextRequest) => {
  const response = NextResponse.redirect(new URL('/login', request.url));
  clearAuthCookies(response);
  return response;
};

const refreshAuth = async (refreshToken: string) => {
  const client = createMatomeApiClient({ baseUrl: getApiBaseUrl() });
  return client.refresh({ refresh_token: refreshToken });
};

const isAccessTokenValid = async (accessToken: string) => {
  const client = createMatomeApiClient({ baseUrl: getApiBaseUrl(), accessToken });

  try {
    await client.me();
    return true;
  } catch (error) {
    if (error instanceof MatomeApiError && error.status === 401) {
      return false;
    }

    throw error;
  }
};

export async function proxy(request: NextRequest) {
  const isProtectedRoute = request.nextUrl.pathname.startsWith('/app');
  const isLoginRoute = request.nextUrl.pathname === '/login';
  const accessToken = request.cookies.get(ACCESS_TOKEN_COOKIE)?.value;
  const refreshToken = request.cookies.get(REFRESH_TOKEN_COOKIE)?.value;

  if (accessToken && (await isAccessTokenValid(accessToken))) {
    if (isLoginRoute) {
      return NextResponse.redirect(new URL('/app', request.url));
    }

    return NextResponse.next();
  }

  if (refreshToken) {
    try {
      const auth = await refreshAuth(refreshToken);
      const response = NextResponse.redirect(new URL(isLoginRoute ? '/app' : request.nextUrl.pathname, request.url));
      setAuthCookies(response, auth);
      return response;
    } catch (error) {
      if (!(error instanceof MatomeApiError) || error.status !== 401) {
        throw error;
      }
    }
  }

  if (isProtectedRoute) {
    return redirectToLogin(request);
  }

  const response = NextResponse.next();
  clearAuthCookies(response);
  return response;
}

export const config = {
  matcher: ['/app/:path*', '/login'],
};
