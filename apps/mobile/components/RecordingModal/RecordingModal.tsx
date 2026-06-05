import React from "react";
import { Modal, View, Text, Pressable, ActivityIndicator } from "react-native";
import { useTranslation } from "react-i18next";
import { Ionicons } from "@expo/vector-icons";
import { formatDuration } from "@/services/audioRecordingService";
import { RecordingModalProps } from "./RecordingModal.types";
import { styles } from "./RecordingModal.styles";

const NIGHT = "#0B0C0E";
const ACCENT = "#E1B346";
const DANGER = "#E63946";

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
  const { t } = useTranslation();

  return (
    <Modal
      visible={visible}
      transparent={false}
      animationType="slide"
      onRequestClose={handleCancel}
    >
      <View style={[styles.fullScreen, { backgroundColor: NIGHT }]}>
        {isProcessing ? (
          <View style={styles.processingContainer}>
            <ActivityIndicator size="large" color={ACCENT} />
            <Text style={[styles.processingText, { color: "rgba(255,255,255,0.7)" }]}>
              {t("recording.processing")}
            </Text>
          </View>
        ) : (
          <>
            {/* Top bar */}
            <View style={styles.topBar}>
              <Pressable style={styles.closeBtn} onPress={handleCancel}>
                <Ionicons name="close" size={22} color="rgba(255,255,255,0.7)" />
              </Pressable>
              <View style={styles.destinationPill}>
                <View style={[styles.destinationDot, { backgroundColor: ACCENT }]} />
                <Text style={styles.destinationText}>Inbox ▾</Text>
              </View>
              <View style={{ width: 40 }} />
            </View>

            {/* Hero content */}
            <View style={styles.hero}>
              {/* Status indicator */}
              <View style={styles.statusRow}>
                {isRecording ? (
                  <>
                    <View style={[styles.recDot, { backgroundColor: DANGER }]} />
                    <Text style={[styles.statusText, { color: DANGER }]}>
                      RECORDING
                    </Text>
                  </>
                ) : (
                  <Text style={[styles.statusText, { color: "rgba(255,255,255,0.5)" }]}>
                    READY
                  </Text>
                )}
              </View>

              {/* Timer */}
              <Text style={styles.timer}>
                {formatDuration(recordingDuration)}
              </Text>

              {/* Waveform */}
              <View style={styles.waveform}>
                {generateWaveform()}
              </View>

              {/* State label */}
              <Text style={[styles.hint, { color: "rgba(255,255,255,0.5)" }]}>
                {isRecording ? t("recording.stopHint") : t("recording.startHint")}
              </Text>
            </View>

            {/* Controls */}
            <View style={styles.controls}>
              {/* Cancel */}
              <View style={styles.controlItem}>
                <Pressable
                  style={[styles.sideBtn, { backgroundColor: "rgba(255,255,255,0.08)" }]}
                  onPress={handleCancel}
                >
                  <Ionicons name="close" size={22} color="rgba(255,255,255,0.7)" />
                </Pressable>
                <Text style={styles.controlLabel}>Cancel</Text>
              </View>

              {/* Main record / stop button */}
              <Pressable
                style={[
                  styles.mainBtn,
                  {
                    backgroundColor: isRecording ? DANGER : ACCENT,
                    shadowColor: isRecording ? DANGER : ACCENT,
                  },
                ]}
                onPress={isRecording ? handleStopRecording : handleStartRecording}
              >
                {isRecording ? (
                  <View style={styles.stopSquare} />
                ) : (
                  <Ionicons name="mic" size={32} color="#1a1a1a" />
                )}
              </Pressable>

              {/* Pause (only while recording) */}
              <View style={styles.controlItem}>
                {isRecording ? (
                  <>
                    <Pressable
                      style={[styles.sideBtn, { backgroundColor: "rgba(255,255,255,0.08)" }]}
                      onPress={handleStopRecording}
                    >
                      <Ionicons name="pause" size={22} color="rgba(255,255,255,0.7)" />
                    </Pressable>
                    <Text style={styles.controlLabel}>Pause</Text>
                  </>
                ) : (
                  <View style={{ width: 52 }} />
                )}
              </View>
            </View>
          </>
        )}
      </View>
    </Modal>
  );
};
