import { Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useTranslation } from "react-i18next";

import { AppHeader, AppHeaderIconButton } from "@/components/AppHeader";
import { DetailsProps } from "./Details.types";
import { styles } from "./Details.styles";

const formatDate = (timestamp: string) => {
  const now = new Date();
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  const month = months[now.getMonth()];
  const day = now.getDate();
  const year = now.getFullYear();
  return `${month} ${day}, ${year} • ${timestamp}`;
};

export const Details: React.FC<DetailsProps> = ({
  recording,
  isLoading,
  isPlaying,
  currentTime,
  duration,
  fileSize,
  waveformBars,
  onPlayPause,
  isSummarizing,
  onSummarize,
  onRetry,
  onBack,
  onSave,
  onMoreOptions,
}) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const isTranscribing = recording.isProcessing;
  const transcribeFailed =
    !recording.isProcessing &&
    !recording.notes &&
    !(recording.summary?.trim());
  const getEditableText = useMemo(() => recording.notes ?? recording.summary ?? "", [recording.notes, recording.summary]);
  const [transcript, setTranscript] = useState(getEditableText);

  useEffect(() => {
    setTranscript(getEditableText);
  }, [getEditableText, recording.notes, recording.summary]);

  const getBadgeStyle = () => {
    if (recording.badge === "Work") {
      return {
        backgroundColor: theme["color-primary-500"] + "26",
        color: theme["color-primary-500"],
      };
    }
    return {
      backgroundColor: theme["color-basic-300"] + "26",
      color: theme["color-basic-600"],
    };
  };

  const badgeStyle = getBadgeStyle();

  const handleSave = () => {
    onSave(transcript);
  };

  if (isLoading) {
    return (
      <Layout
        style={[
          styles.container,
          { justifyContent: "center", alignItems: "center" },
        ]}
      >
        <ActivityIndicator size="large" />
      </Layout>
    );
  }

  return (
    <Layout
      style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}
    >
      <AppHeader
        title={recording.title}
        onBack={onBack}
        borderBottom
        rightActions={
          <AppHeaderIconButton
            icon="ellipsis-horizontal"
            variant="ghost"
            onPress={onMoreOptions}
            size={24}
          />
        }
      />

      {/* Content */}
      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 40 }}
      >
        {/* Meta & Workspace */}
        <View style={styles.metaRow}>
          <Text style={[styles.dateLabel, { color: theme["color-basic-600"] }]}>
            {formatDate(recording.timestamp)}
          </Text>
          <View
            style={[
              styles.workspaceBadge,
              { backgroundColor: badgeStyle.backgroundColor },
            ]}
          >
            <Text
              style={[styles.workspaceBadgeText, { color: badgeStyle.color }]}
            >
              {recording.badge}
            </Text>
            <Ionicons name="chevron-down" size={14} color={badgeStyle.color} />
          </View>
        </View>

        {/* Audio Player */}
        <View
          style={[
            styles.audioPlayer,
            {
              backgroundColor: theme["color-basic-100"],
              borderColor: theme["color-basic-500"],
            },
          ]}
        >
          <View style={styles.audioControls}>
            <TouchableOpacity
              onPress={onPlayPause}
              style={[
                styles.playButtonLarge,
                { backgroundColor: theme["color-primary-500"] },
              ]}
            >
              <Ionicons
                name={isPlaying ? "pause" : "play"}
                size={24}
                color={theme["color-primary-900"]}
              />
            </TouchableOpacity>
            <View style={styles.waveformContainer}>
              {waveformBars.map((bar, index) => (
                <View
                  key={index}
                  style={[
                    styles.waveformBar,
                    {
                      height: bar.height,
                      backgroundColor: bar.active
                        ? theme["color-primary-500"]
                        : theme["color-basic-400"],
                    },
                  ]}
                />
              ))}
            </View>
          </View>
          <View style={styles.timeDisplay}>
            <Text
              style={{
                color: theme["color-basic-600"],
                fontSize: 13,
                fontVariant: ["tabular-nums"],
              }}
            >
              {currentTime}
            </Text>
            {fileSize ? (
              <Text
                style={[styles.fileSize, { color: theme["color-basic-500"] }]}
              >
                {fileSize}
              </Text>
            ) : null}
            <Text
              style={{
                color: theme["color-basic-600"],
                fontSize: 13,
                fontVariant: ["tabular-nums"],
              }}
            >
              {duration}
            </Text>
          </View>
        </View>

        {/* Summary */}
        <View style={styles.section}>
          <View
            style={{
              flexDirection: "row",
              justifyContent: "space-between",
              alignItems: "center",
              marginBottom: 8,
            }}
          >
            <View style={[styles.sectionLabel, { marginBottom: 0 }]}>
              <Ionicons
                name="sparkles"
                size={14}
                color={theme["color-primary-500"]}
              />
              <Text
                style={[
                  styles.sectionLabel,
                  { color: theme["color-basic-600"], marginBottom: 0 },
                ]}
              >
                {t("details.summary")}
              </Text>
            </View>
            <TouchableOpacity
              onPress={() => onSummarize?.(transcript)}
              disabled={isSummarizing || isTranscribing || !transcript}
              style={{ padding: 4 }}
            >
              {isSummarizing ? (
                <ActivityIndicator
                  size="small"
                  color={theme["color-primary-500"]}
                />
              ) : (
                <Ionicons
                  name="refresh"
                  size={16}
                  color={
                    transcript
                      ? theme["color-primary-500"]
                      : theme["color-basic-400"]
                  }
                />
              )}
            </TouchableOpacity>
          </View>
          <View
            style={[
              styles.summaryCard,
              {
                backgroundColor: theme["color-basic-100"],
                borderColor: theme["color-basic-500"],
              },
            ]}
          >
            <Text
              style={{
                color: recording.summary
                  ? theme["color-basic-800"]
                  : theme["color-basic-500"],
                fontSize: 15,
                lineHeight: 24,
              }}
            >
              {recording.summary || t("details.noSummary")}
            </Text>
          </View>
        </View>

        {/* Notes */}
        <View style={styles.transcriptContainer}>
          <View style={[styles.sectionLabel, { justifyContent: "space-between" }]}>
            <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
              <Ionicons
                name="document-text"
                size={14}
                color={theme["color-basic-600"]}
              />
              <Text
                style={[styles.sectionLabel, { color: theme["color-basic-600"], marginBottom: 0 }]}
              >
                {t("details.notes")}
              </Text>
            </View>
            {transcribeFailed && (
              <TouchableOpacity
                onPress={onRetry}
                style={[
                  styles.retryButton,
                  { backgroundColor: theme["color-primary-500"] },
                ]}
              >
                <Ionicons name="refresh" size={14} color={theme["color-primary-900"]} />
                <Text
                  style={[styles.retryButtonText, { color: theme["color-primary-900"] }]}
                >
                  {t("common.retry")}
                </Text>
              </TouchableOpacity>
            )}
          </View>

          {isTranscribing ? (
            <View style={styles.processingRow}>
              <ActivityIndicator size="small" color={theme["color-primary-500"]} />
              <Text
                style={[styles.processingText, { color: theme["color-basic-600"] }]}
              >
                {t("recording.transcribing")}
              </Text>
            </View>
          ) : transcribeFailed ? (
            <View style={styles.errorRow}>
              <Ionicons
                name="alert-circle-outline"
                size={20}
                color={theme["color-danger-500"]}
              />
              <Text
                style={[styles.errorText, { color: theme["color-danger-500"] }]}
              >
                {t("recording.transcriptionFailed")}
              </Text>
            </View>
          ) : (
            <TextInput
              style={[
                styles.transcriptEditor,
                {
                  color: theme["color-basic-800"],
                  backgroundColor: "transparent",
                },
              ]}
              multiline
              textAlignVertical="top"
              value={transcript}
              onChangeText={setTranscript}
              placeholder={t("details.notesPlaceholder")}
              placeholderTextColor={theme["color-basic-500"]}
            />
          )}
        </View>
      </ScrollView>

      {/* Floating Action Button */}
      <TouchableOpacity
        onPress={handleSave}
        style={[
          styles.fab,
          { backgroundColor: theme["color-primary-500"] },
        ]}
      >
        <Ionicons
          name="checkmark"
          size={24}
          color={theme["color-primary-900"]}
        />
      </TouchableOpacity>
    </Layout>
  );
};
