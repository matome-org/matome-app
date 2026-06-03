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
import { Alert, Platform } from "react-native";

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

// True while the live recorder is a single continuous session that has been
// paused/resumed at least once (pauseRecording sets it). When such a recorder is
// finalized, stopRecording() knows the finalized file is the COMPLETE session
// audio and supersedes any pause-snapshot in sessionSegments — so the session
// resolves to exactly one full-audio file (no segment loss, no duplicate temp
// snapshot left to re-transcribe). Reset whenever a fresh recorder is created.
let recorderIsContinuousSession = false;

// ---------------------------------------------------------------------------
// Segment tracking — persists across pause/resume cycles within a session.
// Segment files are written to documentDirectory so they survive app restarts.
// ---------------------------------------------------------------------------
let sessionSegments: string[] = [];

// ---------------------------------------------------------------------------
// Transcription temp-file tracking.
//
// `prepareAudioForTranscription` copies audio to documentDirectory/recording_<ts>.mp3.
// On the multi-segment path it is called once PER segment, producing N temp
// copies. These are intermediates: they are only needed long enough to upload
// to the transcription API. The canonical SAVED recording (the audioFilePath
// persisted to the recordings table) must NOT be tracked here, so it is never
// swept by the cleanup routines below.
//
// Every output path is recorded in `transcriptionTempFiles`. On cancel/discard
// of an UNSAVED session we delete all tracked temp files, leaving nothing behind
// (privacy). On SAVE, the flow snapshots this list into a LOCAL const at save
// start and cleans up via that snapshot (NOT this global) once the background
// pipeline finishes — see cleanupTranscriptionTempFiles. This global is reset
// (cleared) only at the top of startRecording(); the save-flow cleanup
// deliberately does NOT mutate it, so a back-to-back Session-2 owns a fresh
// global while Session-1's in-flight cleanup works off its own local snapshot.
// ---------------------------------------------------------------------------
let transcriptionTempFiles: string[] = [];

// The canonical saved recording path for the current session, once a save has
// started. While non-null it marks "this session was saved" so that a discard
// triggered after Finish (recording.tsx calls discardSegments() right after
// saveRecordingFromSegments returns, while background transcription is still
// running) does NOT delete the saved file or the in-flight temp copies the
// background pipeline is still uploading. Reset to null only at the top of
// startRecording(); the save-flow cleanup captures the saved path locally
// (sessionSavedPath) and does NOT clear this global, so a concurrent Session-2
// can own/reset it without Session-1's cleanup interfering.
let savedAudioFilePath: string | null = null;

/**
 * Best-effort delete of a single file URI. Never throws.
 *
 * Sandbox guard: only paths inside the app's documentDirectory (and free of
 * `..` traversal) are eligible for deletion. Some delete sites replay paths read
 * back from the DB (segments_json), so this primitive must never be coerced into
 * removing a file outside the app sandbox. Out-of-sandbox paths are skipped with
 * a warning instead of being deleted.
 */
const isWithinAppSandbox = (uri: string): boolean => {
  const documentsDir = FileSystem.documentDirectory;
  if (!documentsDir) {
    return false;
  }
  return uri.startsWith(documentsDir) && !uri.includes("..");
};

const safeDeleteFile = async (uri: string): Promise<void> => {
  if (!isWithinAppSandbox(uri)) {
    console.warn("Refusing to delete file outside app sandbox", uri);
    return;
  }
  try {
    const info = await FileSystem.getInfoAsync(uri);
    if (info.exists) {
      await FileSystem.deleteAsync(uri, { idempotent: true });
    }
  } catch (error) {
    console.error("Failed to delete temp audio file", uri, error);
  }
};

/**
 * Delete a list of transcription temp files, optionally preserving one canonical
 * path (the saved recording's audioFilePath). All other files in `tempFiles` are
 * removed from disk. The saved file (if any) survives on disk but is no longer
 * tracked anywhere by this service — it is owned by the recordings table forward.
 *
 * IMPORTANT (cross-session safety): this operates ONLY on the `tempFiles` list it
 * is given — it does NOT read or mutate the module-global `transcriptionTempFiles`
 * / `savedAudioFilePath`. The save flows snapshot their per-session temp list into
 * a LOCAL const at save start and pass THAT snapshot here. This is what closes the
 * async-callback race: when Session-1's background pipeline finishes WHILE
 * Session-2 is mid-recording, S1's cleanup deletes only the files in S1's own
 * snapshot and never touches the live module array (now owned by S2). Without this
 * the global wipe would erase S2's tracker → S2 temps leak or S2 discard no-ops.
 */
const cleanupTranscriptionTempFiles = async (
  tempFiles: string[],
  preservePath?: string,
): Promise<void> => {
  const toDelete = tempFiles.filter((uri) => uri !== preservePath);
  await Promise.allSettled(toDelete.map((uri) => safeDeleteFile(uri)));
};

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
    // Reset ALL per-session module-globals up front so a fresh session can never
    // inherit stale state from a prior one. Without this, a back-to-back record
    // (S1 Finish → back → S2 record while S1's background transcription is still
    // in-flight) bleeds S1's flags into S2: S2's discard could no-op (S1's saved
    // path still marked, so temps survive — privacy leak) or S2's temps could be
    // tracked under S1's session and leaked. We deliberately do NOT delete any
    // files here — S1's in-flight save owns its temps and cleans them up via its
    // own pipeline; we only drop S2's pointers to that state so the two sessions
    // are isolated. (A separate restoreSegments() may re-seed sessionSegments
    // immediately after this for the draft-recovery resume flow.)
    sessionSegments = [];
    transcriptionTempFiles = [];
    savedAudioFilePath = null;
    recordingUri = null;
    recorderIsContinuousSession = false;

    // Clear any leftover metering poll from a prior session before we reassign
    // below, so a double-start can never leak an orphaned interval timer.
    if (meteringInterval) {
      clearInterval(meteringInterval);
      meteringInterval = null;
    }

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

    // Create and prepare recorder.
    // The native AudioRecorder expects a flat options object — platform-specific
    // sub-objects (ios/android/web) must be spread to the top level.
    const preset = RecordingPresets.HIGH_QUALITY;
    const platformSpecific =
      Platform.OS === "ios"
        ? preset.ios
        : Platform.OS === "android"
          ? preset.android
          : preset.web;
    recorder = new AudioModule.AudioRecorder({
      extension: preset.extension,
      sampleRate: preset.sampleRate,
      numberOfChannels: preset.numberOfChannels,
      bitRate: preset.bitRate,
      isMeteringEnabled: true,
      ...platformSpecific,
    });

    // Fresh recorder — not (yet) a paused/resumed continuous session.
    recorderIsContinuousSession = false;

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

    // If this recorder was a paused/resumed continuous session, the file we just
    // finalized contains the COMPLETE session audio (every pause/resume span).
    // It supersedes any pause-snapshot accumulated in sessionSegments, which are
    // now stale partial copies. Capture them for deletion so the session
    // resolves to exactly one full-audio file and stale snapshots are not
    // re-transcribed or left on disk.
    const wasContinuous = recorderIsContinuousSession;
    const supersededSnapshots = wasContinuous ? [...sessionSegments] : [];
    recorderIsContinuousSession = false;

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
    if (wasContinuous) {
      // Single complete file is the sole segment for this session.
      sessionSegments = [segmentUri];
      void Promise.allSettled(
        supersededSnapshots.map((snap) => safeDeleteFile(snap)),
      );
    } else {
      // Legacy / recovered-draft path: genuinely separate segment, keep all.
      sessionSegments = [...sessionSegments, segmentUri];
    }

    return segmentUri;
  } catch (error) {
    console.error("Failed to stop recording:", error);
    recorder = null;
    throw error;
  }
};

/**
 * Pause the active recording WITHOUT splitting it into a separate segment.
 *
 * expo-audio's native AudioRecorder supports a true pause()/record() cycle on a
 * SINGLE recording: pause() suspends capture while keeping the same underlying
 * file open, and a subsequent record() resumes appending to that SAME file.
 * resumeRecording() below calls record() to continue. Because the session stays
 * in one file, Finish (stopRecording) produces audio containing ALL spoken
 * content — this is the fix for the multi-segment audio-loss defect: there is no
 * longer more than one segment to "merge", so nothing is discarded.
 *
 * Crash-recovery note: while paused the recorder's file is not yet finalized, so
 * we snapshot the recorder's current uri to a durable segment_*.m4a copy in
 * documentDirectory. That snapshot lets a paused-then-killed session still be
 * recovered from a draft (as a single recoverable segment). On resume the live
 * recorder keeps growing the same file; at Finish stopRecording() supersedes the
 * snapshot with the complete file. The stale snapshot is swept by
 * discardSegments() after Finish (it lives in documentDirectory under the
 * segment_ prefix), so no audio is leaked or double-counted.
 *
 * Returns the durable snapshot URI (for draft persistence). Stops the metering
 * poll while paused.
 */
export const pauseRecording = async (): Promise<string> => {
  if (!recorder) {
    throw new Error("No recording in progress");
  }

  if (meteringInterval) {
    clearInterval(meteringInterval);
    meteringInterval = null;
  }

  // Capture the duration accumulated so far before pausing so the timer holds.
  const status = recorder.getStatus();
  if (status.durationMillis) {
    lastDurationMillis = status.durationMillis;
  }

  // Native pause — keeps the single underlying file open for resume().
  recorder.pause();
  recorderIsContinuousSession = true;

  const liveUri = recorder.uri;
  if (!liveUri) {
    throw new Error("Recording URI is null");
  }

  // Durable snapshot for crash recovery. The live recorder continues to own and
  // grow `liveUri` on resume; this copy is only a recoverable fallback for a
  // kill-while-paused. It is overwritten in role by the finalized file at Finish
  // and cleaned up by discardSegments().
  const segmentFileName = `segment_${Date.now()}_${Math.random()
    .toString(36)
    .substr(2, 6)}.m4a`;
  const documentsDir = FileSystem.documentDirectory;
  if (!documentsDir) {
    throw new Error("Document directory not available");
  }
  const snapshotUri = `${documentsDir}${segmentFileName}`;
  try {
    await FileSystem.copyAsync({ from: liveUri, to: snapshotUri });
  } catch (error) {
    // Snapshot is best-effort recovery only; pause itself already succeeded.
    console.error("Failed to snapshot paused recording for recovery", error);
    return liveUri;
  }

  // Track the snapshot as the (single) recoverable segment for this session.
  // Replace rather than append: the single live file is the source of truth, so
  // we only ever keep the latest snapshot.
  const previousSnapshots = [...sessionSegments];
  sessionSegments = [snapshotUri];
  recordingUri = snapshotUri;
  // Best-effort delete of any prior snapshot from an earlier pause this session.
  void Promise.allSettled(previousSnapshots.map((uri) => safeDeleteFile(uri)));

  return snapshotUri;
};

/**
 * Resume a recording that was paused via pauseRecording(). Continues appending
 * to the SAME underlying file (no new segment). Restarts the metering poll.
 */
export const resumeRecording = async (): Promise<void> => {
  if (!recorder) {
    throw new Error("No paused recording to resume");
  }

  recorder.record();

  // Clear any existing metering poll before reassigning so a resume can never
  // leak an orphaned interval timer (e.g. resume called without a prior pause
  // having cleared it).
  if (meteringInterval) {
    clearInterval(meteringInterval);
    meteringInterval = null;
  }

  meteringInterval = setInterval(() => {
    if (recorder) {
      const status = recorder.getStatus();
      if (status.isRecording) {
        lastMeteringValue = status.metering;
        lastDurationMillis = status.durationMillis;
      }
    }
  }, 80);
};

/**
 * Whether a live native recorder currently exists (recording OR paused).
 * Lets the recording screen decide at Finish whether to finalize the live
 * recorder via stopRecording() (in-app session) or fall back to the already
 * persisted segment files (a draft recovered after an app restart, where no
 * live recorder exists).
 */
export const isRecorderActive = (): boolean => {
  return recorder !== null;
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

  // Track every temp copy so it can be cleaned up on save (intermediates) or
  // discard (privacy). The canonical saved recording is excluded from cleanup
  // by the save flows via cleanupTranscriptionTempFiles(preservePath).
  transcriptionTempFiles = [...transcriptionTempFiles, newUri];

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

    // Prepare audio file. This is the canonical SAVED recording — mark it so
    // any concurrent discard/cancel of this session leaves it (and the in-flight
    // temp copies) untouched until the background pipeline finishes.
    const audioFilePath = await prepareAudioForTranscription(uri);
    savedAudioFilePath = audioFilePath;

    // Snapshot THIS session's temp-file tracker into a local the moment the save
    // flow begins. The background callback below cleans up via this LOCAL snapshot
    // (not the module global), so if a back-to-back Session-2 starts and resets
    // the module-global transcriptionTempFiles while this pipeline is still
    // running, our cleanup still targets exactly S1's own files and never wipes
    // S2's live tracker. (No further prepareAudioForTranscription calls happen on
    // this path after this point, so the snapshot is complete.)
    const sessionTempFiles = [...transcriptionTempFiles];
    const sessionSavedPath = audioFilePath;

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
        // Transcription done — remove every temp transcription copy EXCEPT the
        // canonical saved audioFilePath (kept for playback in the detail view).
        // Operate on the LOCAL snapshot, never the module global, so a concurrent
        // Session-2 that reset the global is unaffected.
        await cleanupTranscriptionTempFiles(sessionTempFiles, sessionSavedPath);
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
 * Save a recording from the finalized session segment(s).
 * Used by the recording screen after a pause/resume session is finished.
 *
 * Steps:
 *   1. Resolve the session audio file via mergeSegments (see its notes).
 *   2. Get total duration from that file.
 *   3. Prepare the audio file for transcription.
 *   4. Persist a DB record and start the background transcription pipeline.
 *
 * Single-file model (current): pause/resume keep the whole session in ONE file
 * (native AudioRecorder pause()/record()), so mergeSegments returns the COMPLETE
 * audio and getAudioDurationSeconds reads the full duration — no audio is lost.
 * The per-segment transcription loop below still iterates sessionSegments, which
 * is the lone full-session file in this model (and defensively handles the rare
 * recovered-draft case that carries more than one file).
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

    // Canonical SAVED recording for this multi-segment session. Mark it so the
    // discardSegments() call recording.tsx fires immediately after this returns
    // (while the background per-segment transcription below is still running)
    // does not delete it or the in-flight per-segment temp copies.
    const audioFilePath = await prepareAudioForTranscription(uri);
    savedAudioFilePath = audioFilePath;

    // Snapshot THIS session's temp tracker + saved path into locals at save start.
    // The per-segment loop below produces MORE temps inside the async callback; it
    // appends them to its OWN local list (sessionTempFiles) rather than relying on
    // the module global, so cleanup targets exactly this session's files. If a
    // back-to-back Session-2 resets the module-global tracker mid-flight, this
    // pipeline is unaffected and never wipes S2's live tracker.
    const sessionTempFiles = [...transcriptionTempFiles];
    const sessionSavedPath = audioFilePath;

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
        // Transcribe each session file independently and join the results.
        // In the single-file model this is normally one full-session file; the
        // loop also covers the rare recovered-draft case of multiple files so
        // the full spoken content is captured regardless.
        const transcriptParts: string[] = [];
        for (const segUri of segmentsSnapshot) {
          try {
            const segPath = await prepareAudioForTranscription(segUri);
            // Record this per-segment temp into the LOCAL snapshot so the cleanup
            // in `finally` sweeps it without ever reading the module global (which
            // a concurrent Session-2 may have reset).
            sessionTempFiles.push(segPath);
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
        // Transcription done — delete every per-segment temp transcription copy
        // produced above, preserving only the canonical saved audioFilePath.
        // Operate on the LOCAL snapshot (start temps + the per-segment temps the
        // loop pushed), never the module global, so a concurrent Session-2 that
        // reset the global is unaffected. Finish therefore leaves exactly one
        // audio file on disk for this session (segment .m4a files are removed
        // separately by discardSegments).
        await cleanupTranscriptionTempFiles(sessionTempFiles, sessionSavedPath);
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
 * Seed sessionSegments from a recovered draft's persisted span URIs.
 *
 * Restart-recovery flow: after an app restart there is no live recorder and the
 * module-level sessionSegments array is empty (fresh JS process). recording.tsx
 * loads the draft's span URIs from the DB and, to resume recording, calls
 * startRecording() (which resets sessionSegments) and then this function to
 * re-seed the prior spans. A subsequent stopRecording() APPENDS the newly
 * recorded span, so the session resolves to [A, B] (older spans first, new span
 * last) — see the ordering note below.
 *
 * Idempotent: replaces sessionSegments wholesale with a fresh copy of `uris`, so
 * calling it twice with the same input yields the same state (no accumulation).
 *
 * Ordering contract (verified):
 *   startRecording()      → sessionSegments = []      (fix: reset)
 *   restoreSegments([A])  → sessionSegments = [A]
 *   stopRecording()       → sessionSegments = [A, B]  (append, NOT continuous)
 * stopRecording only REPLACES (collapses to one file) when the just-finalized
 * recorder was a paused/resumed CONTINUOUS session. A recovery-resume span that
 * is recorded straight through (record → finish, no pause) is NOT continuous, so
 * its stopRecording takes the append branch and preserves the restored spans.
 *
 * AUDIO LIMITATION (cross-restart, multi-span):
 * When a recovered draft carries 2+ spans, saveRecordingFromSegments transcribes
 * EVERY span independently and joins them, so the resulting TRANSCRIPT is
 * COMPLETE — no spoken content is lost. The playable AUDIO file, however, is the
 * LAST span only: independent M4A/AAC containers each have their own self-
 * contained moov atom and cannot be concatenated without a native mux module
 * (AVMutableComposition / MediaMuxer), which is out of scope and intentionally
 * NOT added here (no native/ffmpeg dependency). Full-audio mux is deferred. The
 * app is pre-launch and the transcript is the primary value, so a complete
 * transcript with last-span playback is the accepted behavior for this edge case.
 * discardSegments() still deletes ALL restored span files, so nothing leaks.
 */
export const restoreSegments = (uris: string[]): void => {
  sessionSegments = [...uris];
};

/**
 * Merge all session segments into a single file ready for the transcription
 * pipeline. Returns the URI of the merged (or only) file.
 *
 * Single-file architecture (current): pause/resume use the native
 * AudioRecorder pause()/record() cycle (see pauseRecording / resumeRecording),
 * which keeps the ENTIRE session in ONE underlying file. Finish therefore
 * produces a single sessionSegments entry whose audio contains every pause/
 * resume span — no concatenation is needed and no audio is lost.
 *
 * Merge strategy:
 *   • 0 segments: throws — nothing to merge.
 *   • 1 segment: returns it directly (the normal path). This is the complete,
 *     full-session audio file.
 *   • 2+ segments: a DEFENSIVE fallback. The single-file pause/resume design
 *     never produces multiple segments for an in-app session; this branch only
 *     triggers for a legacy/recovered draft that happened to persist more than
 *     one segment file. True binary concatenation of independent M4A/AAC
 *     containers is impossible without a native mux module (each file has its
 *     own self-contained moov atom), so we return the LAST segment as the audio
 *     file. Transcription still covers every segment because
 *     saveRecordingFromSegments() transcribes each segment file independently
 *     and joins the results. This path is not expected to occur for sessions
 *     recorded by the current build.
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
 * Also deletes any orphaned transcription temp copies (recording_*.mp3) for the
 * session so recorded audio never survives a Discard (privacy) and disk usage
 * stays bounded.
 *
 * The canonical SAVED recording (savedAudioFilePath) is preserved: this is what
 * lets recording.tsx call discardSegments() right after Finish — while the
 * background transcription pipeline is still uploading the in-flight temp copies
 * — without destroying the saved file. On a pure Discard (no save occurred)
 * savedAudioFilePath is null, so every tracked temp copy is removed.
 *
 * Safe to call even if no segments exist.
 */
export const discardSegments = async (): Promise<void> => {
  const segmentsToDelete = [...sessionSegments];
  sessionSegments = [];
  recordingUri = null;

  // Temp transcription copies to remove. When a save is in progress
  // (savedAudioFilePath set), leave ALL tracked temp files alone — the save
  // flow's own cleanup will remove the intermediates and preserve the saved
  // file once its background pipeline finishes. When no save occurred, sweep
  // every tracked temp copy.
  let tempToDelete: string[] = [];
  if (savedAudioFilePath === null) {
    tempToDelete = [...transcriptionTempFiles];
    transcriptionTempFiles = [];
  }

  await Promise.allSettled([
    ...segmentsToDelete.map((uri) => safeDeleteFile(uri)),
    ...tempToDelete.map((uri) => safeDeleteFile(uri)),
  ]);
};

/**
 * Release the live recorder + metering interval WITHOUT touching any persisted
 * segment files or the saved draft. Use this on screen unmount to free the
 * native mic session and stop the 80ms polling timer while leaving the
 * accumulated session segments (and any auto-saved draft) intact for recovery.
 *
 * Unlike cancelRecording(), this does NOT call discardSegments(), so paused
 * sessions with a saved draft survive.
 *
 * Idempotent and safe to call when nothing is active.
 */
export const releaseRecorder = async (): Promise<void> => {
  if (meteringInterval) {
    clearInterval(meteringInterval);
    meteringInterval = null;
  }

  if (recorder) {
    try {
      await recorder.stop();
    } catch (error) {
      console.error("Error stopping recorder during release:", error);
    } finally {
      recorder.release();
      recorder = null;
      recorderIsContinuousSession = false;
      lastMeteringValue = undefined;
      lastDurationMillis = 0;
    }
  }
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
      recorderIsContinuousSession = false;
      lastMeteringValue = undefined;
      lastDurationMillis = 0;
    }
  }

  // Discard all accumulated segments (including any that were already stopped)
  await discardSegments();
};
