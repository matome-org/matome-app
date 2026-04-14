import React, { useCallback, useEffect, useRef, useState } from "react";
import { Alert } from "react-native";
import { useRouter, useLocalSearchParams, useNavigation } from "expo-router";
import { createAudioPlayer, setAudioModeAsync } from "expo-audio";
import type { AudioPlayer, AudioStatus } from "expo-audio";
import * as FileSystem from "expo-file-system/legacy";
import Toast from "react-native-toast-message";
import { useTranslation } from "react-i18next";

import { RecordingCard } from "@/processes/homeData";
import {
  getRecordingById,
  RecordingRecord,
  recordToCard,
  updateRecording,
} from "@/services/recordingService";
import { summarizeText } from "@/services/summarizeService";
import { retryTranscription } from "@/services/audioRecordingService";
import { initDatabase } from "@/utils/database";

import { Details } from "./Details";
import { WaveformBar } from "./Details.types";

const BAR_COUNT = 32;

const formatTime = (millis: number): string => {
  const totalSeconds = Math.floor(millis / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
};

const formatFileSize = (bytes: number): string => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

const generateWaveformFromBytes = (base64: string): number[] => {
  const heights: number[] = [];
  for (let i = 0; i < BAR_COUNT; i++) {
    const charIndex = Math.floor((i / BAR_COUNT) * base64.length);
    const charCode = base64.charCodeAt(charIndex);
    // Map char code to height between 8 and 32
    const height = 8 + (charCode % 25);
    heights.push(height);
  }
  return heights;
};

export const DetailsContainer: React.FC = () => {
  const router = useRouter();
  const navigation = useNavigation();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { t } = useTranslation();

  const [recording, setRecording] = useState<RecordingCard | null>(null);
  const [record, setRecord] = useState<RecordingRecord | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSummarizing, setIsSummarizing] = useState(false);

  // Lifted edit state
  const [transcript, setTranscript] = useState("");
  const [isEditing, setIsEditing] = useState(false);
  // The text that was last persisted to DB — used to compute isDirty
  const savedTextRef = useRef("");

  const isDirty = transcript !== savedTextRef.current;

  // Audio state
  const playerRef = useRef<AudioPlayer | null>(null);
  const statusSubscriptionRef = useRef<{ remove: () => void } | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState("0:00");
  const [duration, setDuration] = useState("0:00");
  const [playbackProgress, setPlaybackProgress] = useState(0);

  // Waveform & file info
  const [waveformHeights, setWaveformHeights] = useState<number[]>(
    Array(BAR_COUNT).fill(16),
  );
  const [fileSize, setFileSize] = useState("");

  // Load recording from DB
  useEffect(() => {
    const loadRecording = async () => {
      try {
        setIsLoading(true);
        await initDatabase();

        const dbRecord = await getRecordingById(id || "");
        if (dbRecord) {
          setRecord(dbRecord);
          setRecording(recordToCard(dbRecord));

          const initialText = dbRecord.notes ?? dbRecord.summary ?? "";
          setTranscript(initialText);
          savedTextRef.current = initialText;
          // Start in edit mode when there's no content yet
          setIsEditing(!initialText);
        } else {
          router.back();
        }
      } catch (e) {
        Toast.show({ type: "error", text1: t("toast.recordingNotFound") });
        router.back();
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      loadRecording();
    }
  }, [id, router, t]);

  // Load audio file info (waveform + file size)
  useEffect(() => {
    if (!record?.audioFilePath) return;

    const loadFileInfo = async () => {
      try {
        const info = await FileSystem.getInfoAsync(record.audioFilePath);
        if (info.exists && info.size) {
          setFileSize(formatFileSize(info.size));
        }

        // Read a small chunk for waveform generation
        const chunk = await FileSystem.readAsStringAsync(record.audioFilePath, {
          encoding: FileSystem.EncodingType.Base64,
          length: 256,
          position: 0,
        });
        setWaveformHeights(generateWaveformFromBytes(chunk));
      } catch (e) {
        // Fallback — keep default waveform
      }
    };

    loadFileInfo();
  }, [record?.audioFilePath]);

  // Poll DB while transcription is running so the UI reacts when it finishes or fails
  useEffect(() => {
    if (!id || record?.isProcessing !== 1) return;

    const interval = setInterval(async () => {
      try {
        const updated = await getRecordingById(id);
        if (!updated) return;
        setRecord(updated);
        setRecording(recordToCard(updated));
      } catch {
        // ignore transient polling errors
      }
    }, 2000);

    return () => clearInterval(interval);
  }, [id, record?.isProcessing]);

  // Back-navigation guard (M-02): show alert when dirty and in edit mode
  useEffect(() => {
    const unsubscribe = navigation.addListener("beforeRemove", (e) => {
      if (!isDirty || !isEditing) {
        // No unsaved changes or not editing — allow back
        return;
      }

      // Prevent the default back action
      e.preventDefault();

      Alert.alert(
        "Unsaved changes",
        "You have unsaved changes. Do you want to discard them?",
        [
          {
            text: "Keep editing",
            style: "cancel",
            onPress: () => {
              // Do nothing — stay on screen
            },
          },
          {
            text: "Discard",
            style: "destructive",
            onPress: () => navigation.dispatch(e.data.action),
          },
        ],
      );
    });

    return unsubscribe;
  }, [navigation, isDirty, isEditing]);

  const handleRetry = useCallback(async () => {
    if (!record) return;
    // Optimistically show processing state while the DB call goes through
    setRecord((prev) => (prev ? { ...prev, isProcessing: 1 } : prev));
    setRecording((prev) => (prev ? { ...prev, isProcessing: true } : prev));
    try {
      await retryTranscription(id, record.audioFilePath);
    } catch {
      // retryTranscription handles its own errors and always resets isProcessing
    }
  }, [id, record]);

  const onPlaybackStatusUpdate = useCallback((status: AudioStatus) => {
    if (!status.isLoaded) return;

    setIsPlaying(status.playing);
    setCurrentTime(formatTime(status.currentTime * 1000));

    if (status.duration) {
      setDuration(formatTime(status.duration * 1000));
      setPlaybackProgress(status.currentTime / status.duration);
    }

    // Reset when playback finishes
    if (status.didJustFinish) {
      setIsPlaying(false);
      setPlaybackProgress(0);
      setCurrentTime("0:00");
    }
  }, []);

  // Load and configure audio player
  useEffect(() => {
    if (!record?.audioFilePath) return;

    let mounted = true;

    const loadPlayer = async () => {
      try {
        await setAudioModeAsync({ playsInSilentMode: true });

        const player = createAudioPlayer(
          { uri: record.audioFilePath },
          { updateInterval: 100 },
        );

        const subscription = player.addListener(
          "playbackStatusUpdate",
          onPlaybackStatusUpdate,
        );

        if (mounted) {
          playerRef.current = player;
          statusSubscriptionRef.current = subscription;
        } else {
          subscription.remove();
          player.remove();
        }
      } catch (e) {
        // Audio file may not exist or be corrupted
      }
    };

    loadPlayer();

    return () => {
      mounted = false;
      statusSubscriptionRef.current?.remove();
      statusSubscriptionRef.current = null;
      playerRef.current?.remove();
      playerRef.current = null;
    };
  }, [record?.audioFilePath, onPlaybackStatusUpdate]);

  const handlePlayPause = useCallback(async () => {
    const player = playerRef.current;
    if (!player || !player.isLoaded) return;

    try {
      if (player.playing) {
        player.pause();
      } else {
        // If finished, replay from start
        if (player.currentTime >= player.duration && player.duration > 0) {
          await player.seekTo(0);
        }
        player.play();
      }
    } catch (e) {
      Toast.show({ type: "error", text1: t("toast.audioFailed") });
    }
  }, [t]);

  const handleBack = useCallback(() => {
    router.back();
  }, [router]);

  const handleSave = useCallback(async () => {
    try {
      await updateRecording(id, { notes: transcript });
      // Update the saved reference so dirty resets to false
      savedTextRef.current = transcript;
      Toast.show({ type: "success", text1: t("toast.notesSaved") });
    } catch (e) {
      Toast.show({ type: "error", text1: t("toast.notesFailed") });
    }
  }, [id, transcript, t]);

  const handleSummarize = useCallback(
    async (text: string) => {
      if (!text.trim()) return;
      setIsSummarizing(true);
      try {
        const summary = await summarizeText(text);
        await updateRecording(id, { summary });
        setRecording((prev) => (prev ? { ...prev, summary } : prev));
        Toast.show({ type: "success", text1: t("toast.summaryGenerated") });
      } catch (e) {
        Toast.show({ type: "error", text1: t("toast.summaryFailed") });
      } finally {
        setIsSummarizing(false);
      }
    },
    [id, t],
  );

  const handleMoreOptions = useCallback(() => {
    // TODO: show options menu
  }, []);

  // Build waveform bars with active state based on playback progress
  const waveformBars: WaveformBar[] = waveformHeights.map((height, index) => ({
    height,
    active: index / BAR_COUNT < playbackProgress,
  }));

  if (!recording && !isLoading) {
    return null;
  }

  return (
    <Details
      recording={
        recording || {
          id: "",
          title: "",
          timestamp: "",
          duration: "",
          notes: "",
          badge: "Inbox",
          isProcessing: false,
        }
      }
      isLoading={isLoading}
      isDirty={isDirty}
      isEditing={isEditing}
      transcript={transcript}
      onTranscriptChange={setTranscript}
      onEditingChange={setIsEditing}
      isPlaying={isPlaying}
      currentTime={currentTime}
      duration={duration}
      fileSize={fileSize}
      waveformBars={waveformBars}
      onPlayPause={handlePlayPause}
      isSummarizing={isSummarizing}
      onSummarize={handleSummarize}
      onRetry={handleRetry}
      onBack={handleBack}
      onSave={handleSave}
      onMoreOptions={handleMoreOptions}
    />
  );
};
