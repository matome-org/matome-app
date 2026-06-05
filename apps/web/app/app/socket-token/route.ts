import { NextResponse } from 'next/server';
import { getAccessToken, getApiBaseUrl, getCurrentUser } from '@/lib/session';

const getSocketUrl = () => {
  const url = new URL(getApiBaseUrl());
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  url.pathname = '/socket/websocket';
  url.search = '';
  return url.toString();
};

export async function GET() {
  const [token, user] = await Promise.all([getAccessToken(), getCurrentUser()]);

  if (!token || !user) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  return NextResponse.json({ token, socketUrl: getSocketUrl(), userId: user.id });
}
