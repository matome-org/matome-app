import axios from "axios";
import { Audio } from "expo-av";
import * as FileSystem from "expo-file-system";
import { configs } from "@/config/config";
import { createRecording, updateRecording } from "./recordingService";
import type { BadgeType } from "@/processes/homeData";

// Transcribe API client - created from config to avoid module load order issues
const transcribeConfig = configs.find(
  (c) => (c as { name?: string }).name === "transcribeApi",
);
const transcribeApi = transcribeConfig
  ? axios.create({ baseURL: transcribeConfig.baseURL })
  : null;

let recording: Audio.Recording | null = null;
let recordingUri: string | null = null;

/**
 * Request microphone permissions
 */
export const requestPermissions = async (): Promise<boolean> => {
  try {
    const { status } = await Audio.requestPermissionsAsync();
    return status === "granted";
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
    await Audio.setAudioModeAsync({
      allowsRecordingIOS: true,
      playsInSilentModeIOS: true,
    });

    // Create and start recording
    const { recording: newRecording } = await Audio.Recording.createAsync(
      Audio.RecordingOptionsPresets.HIGH_QUALITY,
    );

    recording = newRecording;
  } catch (error) {
    console.error("Failed to start recording:", error);
    throw error;
  }
};

/**
 * Stop audio recording and return the file URI
 */
export const stopRecording = async (): Promise<string> => {
  if (!recording) {
    throw new Error("No recording in progress");
  }

  try {
    await recording.stopAndUnloadAsync();
    const uri = recording.getURI();

    if (!uri) {
      throw new Error("Recording URI is null");
    }

    recording = null;
    recordingUri = uri;

    return uri;
  } catch (error) {
    console.error("Failed to stop recording:", error);
    recording = null;
    throw error;
  }
};

/**
 * Get the duration of the recording in seconds
 */
export const getRecordingDuration = async (): Promise<number> => {
  if (!recording) {
    return 0;
  }

  try {
    const status = await recording.getStatusAsync();
    return status.durationMillis ? status.durationMillis / 1000 : 0;
  } catch (error) {
    console.error("Error getting recording duration:", error);
    return 0;
  }
};

/**
 * Get current recording metering (dBFS, -160 to 0). Returns undefined if not recording or metering unavailable.
 */
export const getRecordingMetering = async (): Promise<number | undefined> => {
  if (!recording) {
    return undefined;
  }

  try {
    const status = await recording.getStatusAsync();
    return status.metering;
  } catch (error) {
    console.error(error);
    return undefined;
  }
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
        text?: string;
        transcript?: string;
      }>("/api/v1/transcribe", formData, {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      });

      const data = response.data;
      transcript = data?.text || data?.transcript || "";
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
  try {
    // Stop recording
    const uri = await stopRecording();

    // Get duration
    // Note: We need to get duration before stopping, so we'll calculate from file
    // For now, we'll set a placeholder and update later if needed
    const duration = "0s"; // Will be updated if we can get it from the file

    // Prepare audio file
    const audioFilePath = await prepareAudioForTranscription(uri);

    // Create recording record with processing status
    const id = generateRecordingId();
    const now = new Date();

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

    // Transcribe in background
    transcribeAudio(audioFilePath)
      .then(async (transcript) => {
        const title = generateTitle(transcript);
        await updateRecording(id, {
          summary: transcript,
          title,
        });
      })
      .catch(async (error) => {
        console.error("Failed to transcribe audio:", error);
        // Keep recording but mark as failed (or keep isProcessing true)
        // Optionally update with error message
        await updateRecording(id, {});
      });

    return id;
  } catch (error) {
    console.error("Error saving recording:", error);
    throw error;
  }
};

/**
 * Cancel current recording
 */
export const cancelRecording = async (): Promise<void> => {
  if (recording) {
    try {
      await recording.stopAndUnloadAsync();
      if (recordingUri) {
        // Delete the temporary file
        const fileInfo = await FileSystem.getInfoAsync(recordingUri);
        if (fileInfo.exists) {
          await FileSystem.deleteAsync(recordingUri, { idempotent: true });
        }
      }
    } catch (error) {
      console.error("Error canceling recording:", error);
    } finally {
      recording = null;
      recordingUri = null;
    }
  }
};
