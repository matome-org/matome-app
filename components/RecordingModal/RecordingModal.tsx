import React, { useState, useEffect, useRef } from 'react';
import { Modal, View, Text, Pressable, ActivityIndicator } from 'react-native';
import { useTheme } from '@ui-kitten/components';
import { useRouter } from 'expo-router';
import {
  startRecording,
  stopRecording,
  saveRecording,
  cancelRecording,
  getRecordingDuration,
  formatDuration,
} from '@/services/audioRecordingService';
import { RecordingModalProps } from './RecordingModal.types';
import { styles } from './RecordingModal.styles';

export const RecordingModal: React.FC<RecordingModalProps> = ({
  visible,
  onClose,
  onRecordingComplete,
}) => {
  const theme = useTheme();
  const router = useRouter();
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [recordingDuration, setRecordingDuration] = useState(0);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  // Update duration while recording
  useEffect(() => {
    if (isRecording) {
      intervalRef.current = setInterval(async () => {
        const duration = await getRecordingDuration();
        setRecordingDuration(duration);
      }, 100); // Update every 100ms
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
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
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    }
  }, [visible]);

  const handleStartRecording = async () => {
    try {
      await startRecording();
      setIsRecording(true);
      setRecordingDuration(0);
    } catch (error) {
      console.error('Failed to start recording:', error);
      // Show error to user
      alert('Failed to start recording. Please check microphone permissions.');
    }
  };

  const handleStopRecording = async () => {
    try {
      setIsRecording(false);
      setIsProcessing(true);

      const recordingId = await saveRecording('Inbox');

      setIsProcessing(false);
      onClose();

      if (onRecordingComplete) {
        onRecordingComplete(recordingId);
      }

      // Navigate to inbox
      router.push('/(tabs)/inbox');
    } catch (error) {
      console.error('Failed to stop recording:', error);
      setIsProcessing(false);
      setIsRecording(false);
      alert('Failed to save recording. Please try again.');
    }
  };

  const handleCancel = async () => {
    if (isRecording) {
      try {
        await cancelRecording();
      } catch (error) {
        console.error('Error canceling recording:', error);
      }
    }
    setIsRecording(false);
    setIsProcessing(false);
    setRecordingDuration(0);
    onClose();
  };

  const generateWaveform = (count: number) => {
    const bars = [];
    for (let i = 0; i < 20; i++) {
      const height = isRecording
        ? Math.random() * 40 + 10
        : Math.random() * 10 + 5;
      bars.push(
        <View
          key={i}
          style={[
            styles.waveBar,
            {
              height,
              backgroundColor: isRecording
                ? theme['color-primary-500']
                : theme['color-basic-400'],
            },
          ]}
        />
      );
    }
    return bars;
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={handleCancel}
    >
      <Pressable style={styles.overlay} onPress={handleCancel}>
        <Pressable
          style={[
            styles.modal,
            { backgroundColor: theme['color-basic-100'] },
          ]}
          onPress={(e) => e.stopPropagation()}
        >
          {isProcessing ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator
                size="large"
                color={theme['color-primary-500']}
              />
              <Text
                style={[
                  styles.loadingText,
                  { color: theme['color-basic-600'] },
                ]}
              >
                Processing recording...
              </Text>
            </View>
          ) : (
            <>
              <Text
                style={[
                  styles.title,
                  { color: theme['color-basic-800'] },
                ]}
              >
                {isRecording ? 'Recording' : 'Ready to Record'}
              </Text>
              <Text
                style={[
                  styles.subtitle,
                  { color: theme['color-basic-600'] },
                ]}
              >
                {isRecording
                  ? 'Tap stop when finished'
                  : 'Tap the button to start recording'}
              </Text>

              {isRecording && (
                <Text
                  style={[
                    styles.timer,
                    { color: theme['color-basic-800'] },
                  ]}
                >
                  {formatDuration(recordingDuration)}
                </Text>
              )}

              <View style={styles.waveform}>
                {generateWaveform(20)}
              </View>

              <Pressable
                style={[
                  styles.recordingIndicator,
                  {
                    backgroundColor: isRecording
                      ? theme['color-danger-500'] + '20'
                      : theme['color-primary-500'] + '20',
                  },
                ]}
                onPress={isRecording ? handleStopRecording : handleStartRecording}
              >
                <View
                  style={[
                    styles.recordingButton,
                    {
                      backgroundColor: isRecording
                        ? theme['color-danger-500']
                        : theme['color-primary-500'],
                    },
                  ]}
                >
                  <View
                    style={[
                      styles.recordingButtonInner,
                      {
                        backgroundColor: isRecording
                          ? theme['color-danger-100']
                          : theme['color-primary-100'],
                      },
                    ]}
                  />
                </View>
              </Pressable>

              <View style={styles.buttonContainer}>
                <Pressable
                  style={[styles.button, styles.cancelButton]}
                  onPress={handleCancel}
                >
                  <Text style={styles.cancelButtonText}>Cancel</Text>
                </Pressable>
                {isRecording && (
                  <Pressable
                    style={[styles.button, styles.stopButton]}
                    onPress={handleStopRecording}
                  >
                    <Text style={styles.stopButtonText}>Stop</Text>
                  </Pressable>
                )}
              </View>
            </>
          )}
        </Pressable>
      </Pressable>
    </Modal>
  );
};
