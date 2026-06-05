import type { Recording, RecordingCreateResponse, PresignedUrl } from '@matome/api-client';
import * as FileSystem from 'expo-file-system/legacy';
import { Socket } from 'phoenix';

import { coreApiClient, coreApiFetch, CORE_API_URL } from '@/services/coreApiClient';
import { getToken } from '@/utils/storage';

type RecordingStatusPayload = {
  recording_id: number;
  status: Recording['status'];
  summary?: string | null;
  transcript?: string | null;
  error_reason?: string | null;
  duration?: number | null;
  badge?: string | null;
  updated_at?: string;
};

const PROCESSING_TIMEOUT_MS = 10 * 60 * 1000;
const POLL_INTERVAL_MS = 2000;

const socketUrl = (): string => {
  const url = new URL(CORE_API_URL);
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  url.pathname = '/socket';
  url.search = '';
  return url.toString();
};

export const createPendingCoreRecording = async ({
  title,
  durationSeconds,
  badge,
  mediaType = 'audio',
}: {
  title: string;
  durationSeconds: number;
  badge: string;
  mediaType?: 'audio' | 'meeting' | 'image';
}): Promise<RecordingCreateResponse> => {
  return coreApiClient.createRecording({
    title,
    status: 'pending',
    media_type: mediaType,
    duration: Math.round(durationSeconds),
    badge,
  });
};

export const uploadCoreRecordingFile = async (
  upload: PresignedUrl,
  fileUri: string,
): Promise<void> => {
  const httpMethod = upload.method === 'POST' ? 'POST' : 'PUT';
  const result = await FileSystem.uploadAsync(upload.url, fileUri, {
    httpMethod,
    headers: upload.headers ?? {},
    uploadType: FileSystem.FileSystemUploadType.BINARY_CONTENT,
  });

  if (result.status < 200 || result.status >= 300) {
    throw new Error(`Recording upload failed with status ${result.status}`);
  }
};

export const uploadCoreRecordingAudio = uploadCoreRecordingFile;

export const enqueueCoreRecordingProcessing = async (
  recordingId: number,
): Promise<void> => {
  const response = await coreApiFetch(`/api/recordings/${recordingId}/process`, {
    method: 'POST',
  });

  if (!response.ok) {
    throw new Error(`Recording processing failed to enqueue (${response.status})`);
  }
};

export const waitForCoreRecordingResult = async (
  recording: Recording,
): Promise<Recording> => {
  const token = await getToken();
  if (!token) {
    throw new Error('Core API token is missing');
  }

  return new Promise((resolve, reject) => {
    const socket = new Socket(socketUrl(), { params: { token } });
    const channel = socket.channel(`user:${recording.owner_id}`);
    let settled = false;
    let pollTimer: ReturnType<typeof setInterval> | undefined;

    const cleanup = () => {
      if (pollTimer) clearInterval(pollTimer);
      channel.leave();
      socket.disconnect();
    };

    const settle = (fn: () => void) => {
      if (settled) return;
      settled = true;
      cleanup();
      fn();
    };

    const resolveFromPayload = (payload: RecordingStatusPayload) => {
      if (payload.recording_id !== recording.id) return;
      if (payload.status === 'done') {
        settle(() => resolve({
          ...recording,
          status: payload.status,
          summary: payload.summary,
          transcript: payload.transcript,
          error_reason: payload.error_reason,
          duration: payload.duration,
          badge: payload.badge,
          updated_at: payload.updated_at ?? recording.updated_at,
        }));
      } else if (payload.status === 'failed') {
        settle(() => reject(new Error(payload.error_reason || 'recording_processing_failed')));
      }
    };

    socket.connect();
    channel.on('recording:status', resolveFromPayload);
    channel.join().receive('error', (payload) => {
      settle(() => reject(new Error(`Recording status channel join failed: ${JSON.stringify(payload)}`)));
    });

    pollTimer = setInterval(async () => {
      try {
        const { recording: latest } = await coreApiClient.getRecording(recording.id);
        if (latest.status === 'done') {
          settle(() => resolve(latest));
        } else if (latest.status === 'failed') {
          settle(() => reject(new Error(latest.error_reason || 'recording_processing_failed')));
        }
      } catch {
        // Channel remains the primary path; ignore transient poll failures.
      }
    }, POLL_INTERVAL_MS);

    setTimeout(() => {
      settle(() => reject(new Error('Recording processing timed out')));
    }, PROCESSING_TIMEOUT_MS);
  });
};
