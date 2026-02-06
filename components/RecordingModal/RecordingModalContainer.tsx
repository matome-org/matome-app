import React, { useCallback, useEffect, useRef, useState } from "react";
import { RecordingModal } from "./RecordingModal";
import { RecordingModalContaierProps } from "./RecordingModal.types";
import { useTheme } from "@ui-kitten/components";
import { useRouter } from "expo-router";
import {
  cancelRecording,
  getRecordingDuration,
  getRecordingMetering,
  saveRecording,
  startRecording,
} from "@/services/audioRecordingService";
import { styles } from "./RecordingModal.styles";
import { View } from "react-native";

const RecordingModalContainer: React.FC<RecordingModalContaierProps> = ({
  visible,
  onClose,
  onRecordingComplete,
}) => {
  const theme = useTheme();
  const router = useRouter();
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [recordingDuration, setRecordingDuration] = useState(0);
  const [meteringBars, setMeteringBars] = useState<number[]>(() =>
    Array(20).fill(0),
  );
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const meteringBufferRef = useRef<number[]>(Array(20).fill(0));

  // Update duration and metering while recording
  useEffect(() => {
    if (isRecording) {
      intervalRef.current = setInterval(async () => {
        const [duration, metering] = await Promise.all([
          getRecordingDuration(),
          getRecordingMetering(),
        ]);
        setRecordingDuration(duration);

        // Metering is dBFS from -160 (min) to 0 (max). Map to bar height (e.g. 5–45)
        if (metering !== undefined) {
          const minDb = -60;
          const maxDb = 0;
          const normalized = Math.max(
            0,
            Math.min(1, (metering - minDb) / (maxDb - minDb)),
          );
          const height = normalized * 40 + 5;
          const buffer = [...meteringBufferRef.current.slice(1), height];
          meteringBufferRef.current = buffer;
          setMeteringBars(buffer);
        }
      }, 100); // Update every 100ms
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
      // Reset waveform when not recording
      const empty = Array(20).fill(0);
      meteringBufferRef.current = empty;
      setMeteringBars(empty);
    }

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [isRecording]);

  // Reset state when modal closes
  useEffect(() => {
    if (!visible) {
      setIsRecording(false);
      setIsProcessing(false);
      setRecordingDuration(0);
      meteringBufferRef.current = Array(20).fill(0);
      setMeteringBars(Array(20).fill(0));
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    }
  }, [visible]);

  const handleStartRecording = useCallback(async () => {
    try {
      await startRecording();
      setIsRecording(true);
      setRecordingDuration(0);
    } catch (error) {
      console.error("Failed to start recording:", error);
      // Show error to user
      alert("Failed to start recording. Please check microphone permissions.");
    }
  }, []);

  const handleStopRecording = useCallback(async () => {
    try {
      setIsRecording(false);
      setIsProcessing(true);

      const recordingId = await saveRecording("Inbox");

      setIsProcessing(false);
      onClose();

      if (onRecordingComplete) {
        onRecordingComplete(recordingId);
      }

      // Navigate to inbox
      router.push(`/inbox/${recordingId}`);
    } catch (error) {
      console.error("Failed to stop recording:", error);
      setIsProcessing(false);
      setIsRecording(false);
      alert("Failed to save recording. Please try again.");
    }
  }, [onClose, onRecordingComplete, router]);

  const handleCancel = useCallback(async () => {
    if (isRecording) {
      try {
        await cancelRecording();
      } catch (error) {
        console.error("Error canceling recording:", error);
      }
    }
    setIsRecording(false);
    setIsProcessing(false);
    setRecordingDuration(0);
    onClose();
  }, [isRecording, onClose]);

  const generateWaveform = useCallback(() => {
    return meteringBars.map((height, i) => (
      <View
        key={i}
        style={[
          styles.waveBar,
          {
            height: height > 0 ? height : 5,
            backgroundColor: isRecording
              ? theme["color-primary-500"]
              : theme["color-basic-400"],
          },
        ]}
      />
    ));
  }, [isRecording, theme, meteringBars]);

  return (
    <RecordingModal
      visible={visible}
      handleCancel={handleCancel}
      isProcessing={isProcessing}
      isRecording={isRecording}
      handleStartRecording={handleStartRecording}
      handleStopRecording={handleStopRecording}
      generateWaveform={generateWaveform}
      recordingDuration={recordingDuration}
    />
  );
};

export default RecordingModalContainer;
