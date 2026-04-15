import axios from "axios";
import {
  AudioModule,
  setAudioModeAsync,
  requestRecordingPermissionsAsync,
  RecordingPresets,
  createAudioPlayer,
} from "expo-audio";
import type { AudioStatus } from "expo-audio";
import * as FileSystem from "expo-file-system/legacy";
import { configs } from "@/config/config";
import { createRecording, updateRecording } from "./recordingService";
import { summarizeText } from "./summarizeService";
import type { BadgeType } from "@/processes/homeData";
import { Alert } from "react-native";

// Transcribe API client - created from config to avoid module load order issues
const transcribeConfig = configs.find(
  (c) => (c as { name?: string }).name === "transcribeApi",
);
const transcribeApi = transcribeConfig
  ? axios.create({ baseURL: transcribeConfig.baseURL })
  : null;

let recorder: InstanceType<typeof AudioModule.AudioRecorder> | null = null;
let recordingUri: string | null = null;
let lastMeteringValue: number | undefined = undefined;
let lastDurationMillis: number = 0;
let meteringInterval: ReturnType<typeof setInterval> | null = null;

// ---------------------------------------------------------------------------
// Segment tracking — persists across pause/resume cycles within a session.
// Segment files are written to documentDirectory so they survive app restarts.
// ---------------------------------------------------------------------------
let sessionSegments: string[] = [];

const logRecordingOperationError = (
  message: string,
  context: { operation: string; recordingId?: string },
  error: unknown,
) => {
  console.error(message, context, error);
};

/**
 * Request microphone permissions
 */
export const requestPermissions = async (): Promise<boolean> => {
  try {
    const { granted } = await requestRecordingPermissionsAsync();
    return granted;
  } catch (error) {
    console.error("Error requesting audio permissions:", error);
    return false;
  }
};

/**
 * Start audio recording
 */
export const startRecording = async (): Promise<void> => {
  try {
    // Request permissions
    const hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw new Error("Microphone permission not granted");
    }

    // Configure audio mode
    await setAudioModeAsync({
      allowsRecording: true,
      playsInSilentMode: true,
    });

    lastMeteringValue = undefined;
    lastDurationMillis = 0;

    // Create and prepare recorder
    recorder = new AudioModule.AudioRecorder({
      ...RecordingPresets.HIGH_QUALITY,
      isMeteringEnabled: true,
    });

    await recorder.prepareToRecordAsync();
    recorder.record();

    // Poll status every 80ms for metering and duration updates
    meteringInterval = setInterval(() => {
      if (recorder) {
        const status = recorder.getStatus();
        if (status.isRecording) {
          lastMeteringValue = status.metering;
          lastDurationMillis = status.durationMillis;
        }
      }
    }, 80);
  } catch (error) {
    console.error("Failed to start recording:", error);
    throw error;
  }
};

/**
 * Stop audio recording, persist the segment to documentDirectory, and return
 * its URI. The segment is also appended to the module-level sessionSegments
 * array so multi-segment sessions can be merged later.
 */
export const stopRecording = async (): Promise<string> => {
  if (!recorder) {
    throw new Error("No recording in progress");
  }

  if (meteringInterval) {
    clearInterval(meteringInterval);
    meteringInterval = null;
  }

  try {
    await recorder.stop();
    const uri = recorder.uri;

    if (!uri) {
      throw new Error("Recording URI is null");
    }

    recorder.release();
    recorder = null;
    lastMeteringValue = undefined;
    lastDurationMillis = 0;

    // Copy to documentDirectory so the segment survives app restarts and is
    // not subject to OS cache eviction. File name is timestamp + random suffix
    // to guarantee uniqueness across sessions.
    const segmentFileName = `segment_${Date.now()}_${Math.random()
      .toString(36)
      .substr(2, 6)}.m4a`;
    const documentsDir = FileSystem.documentDirectory;
    if (!documentsDir) {
      throw new Error("Document directory not available");
    }
    const segmentUri = `${documentsDir}${segmentFileName}`;
    await FileSystem.copyAsync({ from: uri, to: segmentUri });

    recordingUri = segmentUri;
    sessionSegments = [...sessionSegments, segmentUri];

    return segmentUri;
  } catch (error) {
    console.error("Failed to stop recording:", error);
    recorder = null;
    throw error;
  }
};

/**
 * Get the duration of the recording in seconds (from last status poll).
 */
export const getRecordingDuration = (): number => {
  return lastDurationMillis / 1000;
};

/**
 * Get current recording metering (dBFS, -160 to 0) from last status poll.
 */
export const getRecordingMetering = (): number | undefined => {
  return lastMeteringValue;
};

/**
 * Format duration in seconds to a human-readable string (e.g., "2m 14s")
 */
export const formatDuration = (seconds: number): string => {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);

  if (mins > 0) {
    return `${mins}m ${secs}s`;
  }
  return `${secs}s`;
};

/**
 * Read audio duration from file in seconds.
 */
const getAudioDurationSeconds = async (uri: string): Promise<number> => {
  return new Promise((resolve) => {
    const player = createAudioPlayer({ uri }, { updateInterval: 100 });

    const subscription = player.addListener(
      "playbackStatusUpdate",
      (status: AudioStatus) => {
        if (status.isLoaded && status.duration > 0) {
          subscription.remove();
          player.remove();
          resolve(status.duration);
        }
      },
    );

    // Timeout after 5 seconds
    setTimeout(() => {
      subscription.remove();
      try {
        player.remove();
      } catch {
        // ignore
      }
      resolve(0);
    }, 5000);
  });
};

/**
 * Convert audio file to MP3 format
 * Note: Expo doesn't have native MP3 conversion. We'll send the file as-is
 * and rely on the API to handle format conversion, or use the recorded format.
 * For now, we'll copy the file with .mp3 extension if needed.
 */
export const prepareAudioForTranscription = async (
  uri: string,
): Promise<string> => {
  // Get file info
  const fileInfo = await FileSystem.getInfoAsync(uri);
  if (!fileInfo.exists) {
    throw new Error("Audio file does not exist");
  }

  // For now, we'll use the file as-is. The API might accept various formats.
  // If conversion is absolutely required, we'd need a native module.
  // For Expo, we can try sending the file and see if the API accepts it.
  // If not, we may need to use a different approach or configure the recording format.

  // Copy to a more permanent location with .mp3 extension
  const fileName = `recording_${Date.now()}.mp3`;
  const documentsDir = FileSystem.documentDirectory;
  if (!documentsDir) {
    throw new Error("Document directory not available");
  }

  const newUri = `${documentsDir}${fileName}`;
  await FileSystem.copyAsync({
    from: uri,
    to: newUri,
  });

  return newUri;
};

/**
 * Send audio file to transcription API
 */
export const transcribeAudio = async (fileUri: string): Promise<string> => {
  try {
    // Read file as base64 or use FormData
    // For React Native, we need to use FormData with file URI
    const formData = new FormData();

    // Get file name from URI
    const fileName = fileUri.split("/").pop() || "audio.mp3";

    // Create file object for FormData
    // @ts-ignore - FormData in React Native accepts file objects differently
    formData.append("file", {
      uri: fileUri,
      type: "audio/mpeg", // or 'audio/mp3', 'audio/m4a' depending on format
      name: fileName,
    } as any);

    let transcript;

    if (!transcribeApi) {
      transcript = "transcript teste";
      //throw new Error('Transcribe API is not configured. Check config/config.ts.');
    } else {
      const response = await transcribeApi.post<{
        text?: unknown;
        transcript?: unknown;
      }>("/api/v1/transcribe", formData, {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      });

      const data = response.data;
      const text = typeof data?.text === "string" ? data.text : "";
      const transcriptValue =
        typeof data?.transcript === "string" ? data.transcript : "";
      transcript = text || transcriptValue || "";
    }

    if (!transcript) {
      throw new Error("No transcript returned from API");
    }

    return transcript;
  } catch (error) {
    console.error("Transcription error:", error);
    throw error;
  }
};

/**
 * Generate a unique ID for recordings
 */
export const generateRecordingId = (): string => {
  return `rec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
};

/**
 * Generate a title from transcript or use default
 */
export const generateTitle = (transcript: string | null): string => {
  if (!transcript) {
    return `New Recording ${new Date().toLocaleDateString()}`;
  }

  // Use first 50 characters of transcript as title
  const firstLine = transcript.split("\n")[0].trim();
  if (firstLine.length > 50) {
    return firstLine.substring(0, 47) + "...";
  }
  return firstLine || `New Recording ${new Date().toLocaleDateString()}`;
};

/**
 * Format timestamp for display (e.g., "10:42 AM")
 */
export const formatTimestamp = (date: Date): string => {
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
};

/**
 * Complete recording flow: stop recording, save file, transcribe, and save to database
 */
export const saveRecording = async (
  badge: BadgeType = "Inbox",
): Promise<string> => {
  let recordingId: string | undefined;

  try {
    // Stop recording
    const uri = await stopRecording();

    // Get and format duration from the saved file (fallback to 0s on failure)
    const durationSeconds = await getAudioDurationSeconds(uri);
    const duration = formatDuration(durationSeconds);

    // Prepare audio file
    const audioFilePath = await prepareAudioForTranscription(uri);

    // Create recording record with processing status
    const id = generateRecordingId();
    recordingId = id;
    const now = new Date();

    try {
      await createRecording({
        id,
        title: "New Recording",
        timestamp: formatTimestamp(now),
        duration,
        badge,
        isProcessing: true,
        audioFilePath,
        createdAt: now.getTime(), // Store as milliseconds
      });
    } catch (error) {
      logRecordingOperationError(
        "Failed to persist recording on create",
        { operation: "createRecording", recordingId: id },
        error,
      );
      throw error;
    }

    // Transcribe and summarize in background, then finalize processing status.
    void (async () => {
      try {
        const transcript = await transcribeAudio(audioFilePath);
        const title = generateTitle(transcript);

        // Summarize the transcript; fall back gracefully if it fails
        let summary: string | undefined;
        try {
          summary = await summarizeText(transcript);
        } catch (error) {
          logRecordingOperationError(
            "Failed to summarize transcript",
            { operation: "summarizeText", recordingId: id },
            error,
          );
          // summary remains undefined — user can regenerate from the Details view
        }

        try {
          await updateRecording(id, {
            summary,
            notes: transcript,
            title,
          });
        } catch (error) {
          logRecordingOperationError(
            "Failed to persist transcription result",
            { operation: "updateRecording.transcription", recordingId: id },
            error,
          );
          throw error;
        }
      } catch (error) {
        logRecordingOperationError(
          "Failed to transcribe recording",
          { operation: "transcribeAudio", recordingId: id },
          error,
        );
        Alert.alert("Failed to transcribe audio");
      } finally {
        try {
          await updateRecording(id, { isProcessing: false });
        } catch (error) {
          logRecordingOperationError(
            "Failed to finalize processing status",
            { operation: "updateRecording.finalizeProcessing", recordingId: id },
            error,
          );
        }
      }
    })();

    return id;
  } catch (error) {
    logRecordingOperationError(
      "Failed to save recording",
      { operation: "saveRecording", recordingId },
      error,
    );
    Alert.alert("Failed to Save Audio");
    throw error;
  }
};

/**
 * Save a recording from an already-stopped set of session segments.
 * Used by the recording screen after multi-segment pause/resume sessions.
 *
 * Steps:
 *   1. Merge all segments into one file (see mergeSegments for strategy notes).
 *   2. Get total duration from the merged (or last) file.
 *   3. Prepare the audio file for transcription.
 *   4. Persist a DB record and start the background transcription pipeline.
 *
 * For multi-segment sessions the transcription pipeline receives the last
 * segment's audio file. Future work: replace mergeSegments with a native
 * M4A mux so the full audio is preserved.
 */
export const saveRecordingFromSegments = async (
  badge: BadgeType = "Inbox",
): Promise<string> => {
  let recordingId: string | undefined;

  try {
    // Merge (or select the single/last) segment
    const uri = await mergeSegments();

    // Duration from the final file
    const durationSeconds = await getAudioDurationSeconds(uri);
    const duration = formatDuration(durationSeconds);

    const audioFilePath = await prepareAudioForTranscription(uri);

    const id = generateRecordingId();
    recordingId = id;
    const now = new Date();

    try {
      await createRecording({
        id,
        title: "New Recording",
        timestamp: formatTimestamp(now),
        duration,
        badge,
        isProcessing: true,
        audioFilePath,
        createdAt: now.getTime(),
      });
    } catch (error) {
      logRecordingOperationError(
        "Failed to persist recording on create",
        { operation: "createRecording", recordingId: id },
        error,
      );
      throw error;
    }

    // Background: transcribe each segment, join transcripts, summarize.
    const segmentsSnapshot = [...sessionSegments];
    void (async () => {
      try {
        // Transcribe each segment independently and join the results.
        // This ensures we capture the full spoken content across all segments
        // even though the saved audio file currently contains only the last.
        const transcriptParts: string[] = [];
        for (const segUri of segmentsSnapshot) {
          try {
            const segPath = await prepareAudioForTranscription(segUri);
            const part = await transcribeAudio(segPath);
            if (part) transcriptParts.push(part);
          } catch (segError) {
            logRecordingOperationError(
              "Failed to transcribe segment",
              { operation: "transcribeSegment", recordingId: id },
              segError,
            );
          }
        }

        const transcript = transcriptParts.join(" ").trim();
        const title = generateTitle(transcript || null);

        let summary: string | undefined;
        if (transcript) {
          try {
            summary = await summarizeText(transcript);
          } catch (error) {
            logRecordingOperationError(
              "Failed to summarize transcript",
              { operation: "summarizeText", recordingId: id },
              error,
            );
          }
        }

        try {
          await updateRecording(id, {
            summary,
            notes: transcript,
            title,
          });
        } catch (error) {
          logRecordingOperationError(
            "Failed to persist transcription result",
            { operation: "updateRecording.transcription", recordingId: id },
            error,
          );
          throw error;
        }
      } catch (error) {
        logRecordingOperationError(
          "Failed to transcribe recording from segments",
          { operation: "transcribeAudio", recordingId: id },
          error,
        );
        Alert.alert("Failed to transcribe audio");
      } finally {
        try {
          await updateRecording(id, { isProcessing: false });
        } catch (error) {
          logRecordingOperationError(
            "Failed to finalize processing status",
            { operation: "updateRecording.finalizeProcessing", recordingId: id },
            error,
          );
        }
      }
    })();

    return id;
  } catch (error) {
    logRecordingOperationError(
      "Failed to save recording from segments",
      { operation: "saveRecordingFromSegments", recordingId },
      error,
    );
    Alert.alert("Failed to Save Audio");
    throw error;
  }
};

/**
 * Retry transcription + summarization for an existing recording.
 * Sets isProcessing: true in DB, runs the pipeline in the background,
 * then sets isProcessing: false regardless of outcome.
 */
export const retryTranscription = async (
  recordingId: string,
  audioFilePath: string,
): Promise<void> => {
  await updateRecording(recordingId, { isProcessing: true });

  void (async () => {
    try {
      const transcript = await transcribeAudio(audioFilePath);
      const title = generateTitle(transcript);

      let summary: string | undefined;
      try {
        summary = await summarizeText(transcript);
      } catch (error) {
        logRecordingOperationError(
          "Failed to summarize transcript on retry",
          { operation: "summarizeText", recordingId },
          error,
        );
      }

      await updateRecording(recordingId, { summary, notes: transcript, title });
    } catch (error) {
      logRecordingOperationError(
        "Failed to transcribe on retry",
        { operation: "retryTranscription", recordingId },
        error,
      );
    } finally {
      await updateRecording(recordingId, { isProcessing: false }).catch((e) => {
        logRecordingOperationError(
          "Failed to reset processing status after retry",
          { operation: "retryTranscription.finalize", recordingId },
          e,
        );
      });
    }
  })();
};

/**
 * Return all segment file URIs accumulated in the current session.
 * Does not clear state — call discardSegments() to delete files and reset.
 */
export const getSegments = (): string[] => {
  return [...sessionSegments];
};

/**
 * Merge all session segments into a single file ready for the transcription
 * pipeline. Returns the URI of the merged (or only) file.
 *
 * Merge strategy:
 *   • 0 segments: throws — nothing to merge.
 *   • 1 segment: returns it directly, no copy needed.
 *   • 2+ segments (M4A/AAC): True binary concatenation of M4A containers is
 *     not possible without a native module because each M4A file has a
 *     self-contained moov atom describing its own samples. Naively appending
 *     bytes produces a file whose moov still points at only the first
 *     segment's samples, resulting in silent or corrupt audio.
 *
 *     Correct approaches (requires a native module not currently in the
 *     dependency tree):
 *       • AVMutableComposition (iOS) / MediaMux (Android) via a custom
 *         Expo module or react-native-ffmpeg.
 *       • Convert all segments to raw PCM (WAV) before recording, then
 *         concatenate the PCM data after stripping each subsequent file's
 *         44-byte WAV header.
 *
 *     Current pragmatic fallback: copy the LAST segment as the "merged"
 *     file so the save pipeline receives a valid audio file. The transcription
 *     API is called once per segment and the transcripts are joined in
 *     saveRecordingFromSegments() below. Audio playback in the detail view
 *     will reflect only the last segment until proper merging is implemented.
 *
 *     TODO: Replace this with a proper merge once a native audio module is
 *     added to the project.
 */
export const mergeSegments = async (): Promise<string> => {
  if (sessionSegments.length === 0) {
    throw new Error("mergeSegments: no segments to merge");
  }

  if (sessionSegments.length === 1) {
    return sessionSegments[0];
  }

  // Fallback: return the last segment as the canonical audio file.
  // See the comment above for why full M4A merging requires a native module.
  return sessionSegments[sessionSegments.length - 1];
};

/**
 * Delete all segment files from disk and clear module-level segment state.
 * Safe to call even if no segments exist.
 */
export const discardSegments = async (): Promise<void> => {
  const toDelete = [...sessionSegments];
  sessionSegments = [];
  recordingUri = null;

  await Promise.allSettled(
    toDelete.map(async (uri) => {
      try {
        const info = await FileSystem.getInfoAsync(uri);
        if (info.exists) {
          await FileSystem.deleteAsync(uri, { idempotent: true });
        }
      } catch (error) {
        console.error("discardSegments: failed to delete segment file", uri, error);
      }
    }),
  );
};

/**
 * Cancel current recording — stops any active recorder, discards all
 * accumulated segment files, and resets module state.
 */
export const cancelRecording = async (): Promise<void> => {
  if (meteringInterval) {
    clearInterval(meteringInterval);
    meteringInterval = null;
  }

  if (recorder) {
    try {
      await recorder.stop();
    } catch (error) {
      console.error("Error stopping recorder during cancel:", error);
    } finally {
      recorder.release();
      recorder = null;
      lastMeteringValue = undefined;
      lastDurationMillis = 0;
    }
  }

  // Discard all accumulated segments (including any that were already stopped)
  await discardSegments();
};
