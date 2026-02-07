import React, { useCallback, useEffect, useRef, useState } from "react";
import { useRouter, useLocalSearchParams } from "expo-router";
import { Audio, AVPlaybackStatus } from "expo-av";
import * as FileSystem from "expo-file-system";
import Toast from "react-native-toast-message";

import { RecordingCard } from "@/processes/homeData";
import {
  getRecordingById,
  RecordingRecord,
  recordToCard,
  updateRecording,
} from "@/services/recordingService";
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
  const { id } = useLocalSearchParams<{ id: string }>();

  const [recording, setRecording] = useState<RecordingCard | null>(null);
  const [record, setRecord] = useState<RecordingRecord | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Audio state
  const soundRef = useRef<Audio.Sound | null>(null);
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
        } else {
          router.back();
        }
      } catch (e) {
        Toast.show({ type: "error", text1: "Recording not found" });
        router.back();
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      loadRecording();
    }
  }, [id, router]);

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

  const onPlaybackStatusUpdate = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;

    setIsPlaying(status.isPlaying);
    setCurrentTime(formatTime(status.positionMillis));

    if (status.durationMillis) {
      setDuration(formatTime(status.durationMillis));
      setPlaybackProgress(status.positionMillis / status.durationMillis);
    }

    // Reset when playback finishes
    if (status.didJustFinish) {
      setIsPlaying(false);
      setPlaybackProgress(0);
      setCurrentTime("0:00");
    }
  }, []);

  // Load and configure audio sound
  useEffect(() => {
    if (!record?.audioFilePath) return;

    let mounted = true;

    const loadSound = async () => {
      try {
        await Audio.setAudioModeAsync({ playsInSilentModeIOS: true });

        const { sound } = await Audio.Sound.createAsync(
          { uri: record.audioFilePath },
          { shouldPlay: false },
          onPlaybackStatusUpdate,
        );

        if (mounted) {
          soundRef.current = sound;
        } else {
          await sound.unloadAsync();
        }
      } catch (e) {
        // Audio file may not exist or be corrupted
      }
    };

    loadSound();

    return () => {
      mounted = false;
      soundRef.current?.unloadAsync();
      soundRef.current = null;
    };
  }, [record?.audioFilePath, onPlaybackStatusUpdate]);

  const handlePlayPause = useCallback(async () => {
    if (!soundRef.current) return;

    try {
      const status = await soundRef.current.getStatusAsync();
      if (!status.isLoaded) return;

      if (status.isPlaying) {
        await soundRef.current.pauseAsync();
      } else {
        // If finished, replay from start
        if (
          status.didJustFinish ||
          status.positionMillis === status.durationMillis
        ) {
          await soundRef.current.setPositionAsync(0);
        }
        await soundRef.current.playAsync();
      }
    } catch (e) {
      Toast.show({ type: "error", text1: "Failed to play audio" });
    }
  }, []);

  const handleBack = useCallback(() => {
    router.back();
  }, [router]);

  const handleSave = useCallback(
    async (notes: string) => {
      try {
        await updateRecording(id, { notes });
        Toast.show({ type: "success", text1: "Notes saved" });
      } catch (e) {
        Toast.show({ type: "error", text1: "Failed to save notes" });
      }
    },
    [id],
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
      isPlaying={isPlaying}
      currentTime={currentTime}
      duration={duration}
      fileSize={fileSize}
      waveformBars={waveformBars}
      onPlayPause={handlePlayPause}
      onBack={handleBack}
      onSave={handleSave}
      onMoreOptions={handleMoreOptions}
    />
  );
};
