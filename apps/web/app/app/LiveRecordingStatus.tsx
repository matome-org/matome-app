'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useTranslation } from 'react-i18next';

type SocketPayload = {
  token: string;
  socketUrl: string;
  userId: number;
};

type PhoenixMessage = [string | null, string | null, string, string, unknown];

const makeSocketUrl = ({ socketUrl, token }: SocketPayload) => {
  const url = new URL(socketUrl);
  url.searchParams.set('token', token);
  url.searchParams.set('vsn', '2.0.0');
  return url.toString();
};

export function LiveRecordingStatus() {
  const router = useRouter();
  const { t } = useTranslation();
  const [state, setState] = useState<'connecting' | 'live' | 'offline'>('connecting');
  const refreshTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    let socket: WebSocket | null = null;
    let heartbeat: ReturnType<typeof setInterval> | null = null;
    let closed = false;
    let ref = 0;

    const nextRef = () => String(++ref);
    const send = (topic: string, event: string, payload: unknown, joinRef: string | null = null) => {
      if (socket?.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify([joinRef, nextRef(), topic, event, payload]));
      }
    };

    const scheduleRefresh = () => {
      if (refreshTimer.current) {
        clearTimeout(refreshTimer.current);
      }

      refreshTimer.current = setTimeout(() => router.refresh(), 180);
    };

    const connect = async () => {
      try {
        const response = await fetch('/app/socket-token', { cache: 'no-store' });

        if (!response.ok) {
          setState('offline');
          return;
        }

        const payload = (await response.json()) as SocketPayload;
        const topic = `user:${payload.userId}`;
        const joinRef = nextRef();

        socket = new WebSocket(makeSocketUrl(payload));
        socket.addEventListener('open', () => {
          socket?.send(JSON.stringify([joinRef, nextRef(), topic, 'phx_join', {}]));
          heartbeat = setInterval(() => send('phoenix', 'heartbeat', {}), 30_000);
        });
        socket.addEventListener('message', (event) => {
          const message = JSON.parse(String(event.data)) as PhoenixMessage;
          const [, , incomingTopic, incomingEvent] = message;

          if (incomingTopic === topic && incomingEvent === 'phx_reply') {
            setState('live');
          }

          if (incomingTopic === topic && incomingEvent === 'recording:status') {
            setState('live');
            scheduleRefresh();
          }
        });
        socket.addEventListener('close', () => {
          if (!closed) {
            setState('offline');
          }
        });
        socket.addEventListener('error', () => setState('offline'));
      } catch {
        setState('offline');
      }
    };

    void connect();

    return () => {
      closed = true;
      socket?.close();

      if (heartbeat) {
        clearInterval(heartbeat);
      }

      if (refreshTimer.current) {
        clearTimeout(refreshTimer.current);
      }
    };
  }, [router]);

  return (
    <span className={`live-pill ${state}`}>
      {state === 'live' ? t('web.live') : state === 'connecting' ? t('web.connecting') : t('web.offline')}
    </span>
  );
}
