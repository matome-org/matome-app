import { Alert } from "react-native";

import {
  createPendingCoreRecording,
  enqueueCoreRecordingProcessing,
  uploadCoreRecordingFile,
  waitForCoreRecordingResult,
} from "@/services/coreRecordingService";
import { createRecording, getRecordingById, updateRecording } from "@/services/recordingService";
import type { RecordingMediaType } from "@/services/recordingService";
import { formatDuration, formatTimestamp, generateTitle } from "@/services/audioRecordingService";
import type { BadgeType } from "@/processes/homeData";
import { coreApiClient } from "@/services/coreApiClient";
import { useRecordingsStore } from "@/stores/recordingsStore";

type UploadRecordingInput = {
  uri: string;
  title: string;
  mediaType: RecordingMediaType;
  badge?: BadgeType;
};

const syncUploadResult = async (
  recordingId: string,
  result: Awaited<ReturnType<typeof waitForCoreRecordingResult>>,
): Promise<void> => {
  await updateRecording(recordingId, {
    summary: result.summary ?? undefined,
    notes: result.transcript ?? "",
    title: generateTitle(result.transcript ?? result.summary ?? null),
    isProcessing: false,
    processingStatus: "done",
  });
};

const markUploadFailed = async (recordingId: string): Promise<void> => {
  await updateRecording(recordingId, {
    isProcessing: false,
    processingStatus: "failed",
  }).catch((error) => {
    console.error("Failed to persist upload failure state", error);
  });
};

export const uploadPickedRecording = async ({
  uri,
  title,
  mediaType,
  badge = "Inbox",
}: UploadRecordingInput): Promise<string> => {
  const created = await createPendingCoreRecording({
    title,
    durationSeconds: 0,
    badge,
    mediaType,
  });
  const recordingId = String(created.recording.id);
  const now = new Date();

  await createRecording({
    id: recordingId,
    title,
    timestamp: formatTimestamp(now),
    duration: formatDuration(0),
    badge,
    isProcessing: true,
    audioFilePath: uri,
    createdAt: now.getTime(),
    mediaType,
    processingStatus: "pending",
  });

  void (async () => {
    try {
      await uploadCoreRecordingFile(created.upload, uri);
      await updateRecording(recordingId, { processingStatus: "processing" });
      await enqueueCoreRecordingProcessing(created.recording.id);
      const result = await waitForCoreRecordingResult(created.recording);
      await syncUploadResult(recordingId, result);
      useRecordingsStore.getState().triggerRefresh();
    } catch (error) {
      console.error("Failed to upload picked recording through Core", error);
      await markUploadFailed(recordingId);
      useRecordingsStore.getState().triggerRefresh();
      Alert.alert("Failed to process import", "Tap Retry on the recording to try again.");
    }
  })();

  return recordingId;
};

export const retryUploadedRecording = async (recordingId: string): Promise<void> => {
  const row = await getRecordingById(recordingId);
  if (!row) return;

  await updateRecording(recordingId, {
    isProcessing: true,
    processingStatus: "processing",
  });

  void (async () => {
    try {
      const coreRecordingId = Number(recordingId);
      if (!Number.isInteger(coreRecordingId)) {
        throw new Error("Upload retry requires a Core recording id");
      }
      const latest = await coreApiClient.getRecording(coreRecordingId);
      await enqueueCoreRecordingProcessing(coreRecordingId);
      const result = await waitForCoreRecordingResult(latest.recording);
      await syncUploadResult(recordingId, result);
      useRecordingsStore.getState().triggerRefresh();
    } catch (error) {
      console.error("Failed to retry uploaded recording", error);
      await markUploadFailed(recordingId);
      useRecordingsStore.getState().triggerRefresh();
    }
  })();
};
