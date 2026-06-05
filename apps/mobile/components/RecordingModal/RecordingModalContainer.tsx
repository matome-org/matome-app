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
  const lastHeightRef = useRef<number>(5);

  // Update duration and metering while recording
  useEffect(() => {
    if (isRecording) {
      intervalRef.current = setInterval(() => {
        const duration = getRecordingDuration();
        const metering = getRecordingMetering();
        setRecordingDuration(duration);

        if (metering !== undefined) {
          // 1. Define the range. -60 is a good "floor" for speech.
          const minDb = -60;
          const maxDb = 0;

          // 2. Normalize 0 to 1
          let normalized = (metering - minDb) / (maxDb - minDb);
          normalized = Math.max(0, Math.min(1, normalized));

          // 3. Calculate target height
          const targetHeight = normalized * 40 + 5;

          // 4. DECAY LOGIC:
          let finalHeight;
          if (targetHeight > lastHeightRef.current) {
            // If the sound is louder than the previous bar, jump up quickly
            finalHeight = targetHeight;
          } else {
            // If the sound is quieter (like your -160 logs), 
            // slowly glide down (70% of previous + 30% of target)
            finalHeight = (lastHeightRef.current * 0.7) + (targetHeight * 0.3);
          }

          // Avoid tiny floating point numbers and keep a minimum
          finalHeight = Math.max(5, finalHeight);
          lastHeightRef.current = finalHeight;

          const buffer = [...meteringBufferRef.current.slice(1), finalHeight];
          meteringBufferRef.current = buffer;
          setMeteringBars(buffer);
        }
      }, 80); // Slightly faster interval makes it look smoother
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
