import React from "react";
import { Modal, View, Text, Pressable, ActivityIndicator } from "react-native";
import { formatDuration } from "@/services/audioRecordingService";
import { RecordingModalProps } from "./RecordingModal.types";
import { styles } from "./RecordingModal.styles";
import { useTheme } from "@ui-kitten/components";

export const RecordingModal: React.FC<RecordingModalProps> = ({
  visible,
  handleCancel,
  isProcessing,
  isRecording,
  handleStopRecording,
  handleStartRecording,
  recordingDuration,
  generateWaveform,
}) => {
  const theme = useTheme();
  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={handleCancel}
    >
      <Pressable style={styles.overlay} onPress={handleCancel}>
        <Pressable
          style={[styles.modal, { backgroundColor: theme["color-basic-100"] }]}
          onPress={(e) => e.stopPropagation()}
        >
          {isProcessing ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator
                size="large"
                color={theme["color-primary-500"]}
              />
              <Text
                style={[
                  styles.loadingText,
                  { color: theme["color-basic-600"] },
                ]}
              >
                Processing recording...
              </Text>
            </View>
          ) : (
            <>
              <Text style={[styles.title, { color: theme["color-basic-800"] }]}>
                {isRecording ? "Recording" : "Ready to Record"}
              </Text>
              <Text
                style={[styles.subtitle, { color: theme["color-basic-600"] }]}
              >
                {isRecording
                  ? "Tap stop when finished"
                  : "Tap the button to start recording"}
              </Text>

              {isRecording && (
                <Text
                  style={[styles.timer, { color: theme["color-basic-800"] }]}
                >
                  {formatDuration(recordingDuration)}
                </Text>
              )}

              <View style={styles.waveform}>{generateWaveform()}</View>

              <Pressable
                style={[
                  styles.recordingIndicator,
                  {
                    backgroundColor: isRecording
                      ? theme["color-danger-500"] + "20"
                      : theme["color-primary-500"] + "20",
                  },
                ]}
                onPress={
                  isRecording ? handleStopRecording : handleStartRecording
                }
              >
                <View
                  style={[
                    styles.recordingButton,
                    {
                      backgroundColor: isRecording
                        ? theme["color-danger-500"]
                        : theme["color-primary-500"],
                    },
                  ]}
                >
                  <View
                    style={[
                      styles.recordingButtonInner,
                      {
                        backgroundColor: isRecording
                          ? theme["color-danger-100"]
                          : theme["color-primary-100"],
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
