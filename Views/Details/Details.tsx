import { Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useRef, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useTranslation } from "react-i18next";
import Markdown from "react-native-markdown-display";

import { AppHeader, AppHeaderIconButton } from "@/components/AppHeader";
import { DetailsProps } from "./Details.types";
import { styles } from "./Details.styles";

const ACCENT = "#E1B346";
const ACCENT_DARK = "#B98A1F";

const SEGMENTS = ["Summary", "Notes", "Transcript"] as const;
type Segment = (typeof SEGMENTS)[number];

const formatDate = (timestamp: string) => {
  const now = new Date();
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${months[now.getMonth()]} ${now.getDate()}, ${now.getFullYear()} · ${timestamp}`;
};

export const Details: React.FC<DetailsProps> = ({
  recording,
  isLoading,
  isDirty,
  isEditing,
  transcript,
  onTranscriptChange,
  onEditingChange,
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
  const [activeSegment, setActiveSegment] = useState<Segment>("Notes");
  const [selection, setSelection] = useState({ start: 0, end: 0 });
  const inputRef = useRef<TextInput>(null);

  const isTranscribing = recording.isProcessing;
  const transcribeFailed =
    !recording.isProcessing &&
    !recording.notes &&
    !(recording.summary?.trim());

  const insertMarkdown = (prefix: string, suffix = "") => {
    const before = transcript.slice(0, selection.start);
    const selected = transcript.slice(selection.start, selection.end);
    const after = transcript.slice(selection.end);
    onTranscriptChange(before + prefix + selected + suffix + after);
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const getBadgeStyle = () => {
    if (recording.badge === "Work") {
      return {
        backgroundColor: ACCENT + "26",
        color: ACCENT_DARK,
      };
    }
    return {
      backgroundColor: theme["color-basic-300"],
      color: theme["color-basic-600"],
    };
  };

  const badgeStyle = getBadgeStyle();

  if (isLoading) {
    return (
      <Layout style={[styles.container, { justifyContent: "center", alignItems: "center" }]}>
        <ActivityIndicator size="large" color={ACCENT} />
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

      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 40 }}
      >
        {/* Meta row */}
        <View style={styles.metaRow}>
          <Text style={[styles.dateLabel, { color: theme["color-basic-600"] }]}>
            {formatDate(recording.timestamp)}
          </Text>
          <TouchableOpacity
            style={[
              styles.workspaceBadge,
              { backgroundColor: badgeStyle.backgroundColor },
            ]}
          >
            <Text style={[styles.workspaceBadgeText, { color: badgeStyle.color }]}>
              {recording.badge}
            </Text>
            <Ionicons name="chevron-down" size={13} color={badgeStyle.color} />
          </TouchableOpacity>
        </View>

        {/* Audio player */}
        <View
          style={[
            styles.audioPlayer,
            {
              backgroundColor: theme["color-basic-100"],
              borderColor: theme["color-basic-400"],
            },
          ]}
        >
          <View style={styles.audioControls}>
            <TouchableOpacity
              onPress={onPlayPause}
              style={[
                styles.playButtonLarge,
                { backgroundColor: ACCENT },
              ]}
            >
              <Ionicons
                name={isPlaying ? "pause" : "play"}
                size={24}
                color={theme["color-basic-800"]}
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
                        ? ACCENT
                        : theme["color-basic-400"],
                    },
                  ]}
                />
              ))}
            </View>
          </View>
          <View style={styles.timeDisplay}>
            <Text style={{ color: theme["color-basic-600"], fontSize: 13, fontVariant: ["tabular-nums"] }}>
              {currentTime}
            </Text>
            {fileSize ? (
              <Text style={[styles.fileSize, { color: theme["color-basic-500"] }]}>
                {fileSize}
              </Text>
            ) : null}
            <Text style={{ color: theme["color-basic-600"], fontSize: 13, fontVariant: ["tabular-nums"] }}>
              {duration}
            </Text>
          </View>
        </View>

        {/* Segmented control */}
        <View
          style={[
            styles.segmentedControl,
            { backgroundColor: theme["color-basic-300"] },
          ]}
        >
          {SEGMENTS.map((seg) => (
            <TouchableOpacity
              key={seg}
              style={[
                styles.segmentTab,
                activeSegment === seg && {
                  backgroundColor: theme["color-basic-100"],
                  shadowColor: "#000",
                  shadowOffset: { width: 0, height: 1 },
                  shadowOpacity: 0.08,
                  shadowRadius: 2,
                  elevation: 2,
                },
              ]}
              onPress={() => setActiveSegment(seg)}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.segmentTabText,
                  {
                    color:
                      activeSegment === seg
                        ? theme["color-basic-800"]
                        : theme["color-basic-600"],
                  },
                ]}
              >
                {seg}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* Summary section */}
        {activeSegment === "Summary" && (
          <View style={styles.section}>
            <View style={[styles.sectionLabel, { justifyContent: "space-between" }]}>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
                <Ionicons name="sparkles" size={13} color={ACCENT} />
                <Text style={[styles.sectionLabel, { color: theme["color-basic-600"], marginBottom: 0 }]}>
                  {t("details.summary")}
                </Text>
              </View>
              <TouchableOpacity
                onPress={() => onSummarize?.(transcript)}
                disabled={isSummarizing || isTranscribing || !transcript}
                style={{ padding: 4 }}
              >
                {isSummarizing ? (
                  <ActivityIndicator size="small" color={ACCENT} />
                ) : (
                  <Ionicons
                    name="refresh"
                    size={16}
                    color={transcript ? ACCENT : theme["color-basic-400"]}
                  />
                )}
              </TouchableOpacity>
            </View>
            <View
              style={[
                styles.summaryCard,
                {
                  backgroundColor: theme["color-basic-100"],
                  borderColor: theme["color-basic-400"],
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
        )}

        {/* Notes section */}
        {activeSegment === "Notes" && (
          <View style={styles.transcriptContainer}>
            <View style={[styles.sectionLabel, { justifyContent: "space-between" }]}>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
                <Ionicons name="document-text" size={13} color={theme["color-basic-600"]} />
                <Text style={[styles.sectionLabel, { color: theme["color-basic-600"], marginBottom: 0 }]}>
                  {t("details.notes")}
                </Text>
              </View>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
                {transcribeFailed && (
                  <TouchableOpacity
                    onPress={onRetry}
                    style={[styles.retryButton, { backgroundColor: ACCENT }]}
                  >
                    <Ionicons name="refresh" size={14} color={theme["color-basic-800"]} />
                    <Text style={[styles.retryButtonText, { color: theme["color-basic-800"] }]}>
                      {t("common.retry")}
                    </Text>
                  </TouchableOpacity>
                )}
                {!isTranscribing && !transcribeFailed && (
                  <TouchableOpacity
                    onPress={() => onEditingChange(!isEditing)}
                    style={[
                      styles.retryButton,
                      {
                        backgroundColor: isEditing
                          ? ACCENT
                          : theme["color-basic-300"],
                      },
                    ]}
                  >
                    <Ionicons
                      name={isEditing ? "eye" : "pencil"}
                      size={13}
                      color={isEditing ? theme["color-basic-800"] : theme["color-basic-700"]}
                    />
                    <Text
                      style={[
                        styles.retryButtonText,
                        {
                          color: isEditing
                            ? theme["color-basic-800"]
                            : theme["color-basic-700"],
                        },
                      ]}
                    >
                      {isEditing ? t("details.preview") : t("details.edit")}
                    </Text>
                  </TouchableOpacity>
                )}
              </View>
            </View>

            {isTranscribing ? (
              <View style={styles.processingRow}>
                <ActivityIndicator size="small" color={ACCENT} />
                <Text style={[styles.processingText, { color: theme["color-basic-600"] }]}>
                  {t("recording.transcribing")}
                </Text>
              </View>
            ) : transcribeFailed ? (
              <View style={styles.errorRow}>
                <Ionicons name="alert-circle-outline" size={20} color={theme["color-danger-500"]} />
                <Text style={[styles.errorText, { color: theme["color-danger-500"] }]}>
                  {t("recording.transcriptionFailed")}
                </Text>
              </View>
            ) : isEditing ? (
              <View>
                <View
                  style={[
                    styles.markdownToolbar,
                    {
                      backgroundColor: theme["color-basic-300"],
                      borderColor: theme["color-basic-400"],
                    },
                  ]}
                >
                  {[
                    { label: "B", action: () => insertMarkdown("**", "**"), bold: true },
                    { label: "I", action: () => insertMarkdown("*", "*"), italic: true },
                    { label: "H", action: () => insertMarkdown("\n# ") },
                    { label: "•", action: () => insertMarkdown("\n- ") },
                    { label: "[ ]", action: () => insertMarkdown("\n- [ ] ") },
                  ].map(({ label, action, bold, italic }) => (
                    <TouchableOpacity
                      key={label}
                      onPress={action}
                      style={[styles.toolbarButton, { borderColor: theme["color-basic-400"] }]}
                    >
                      <Text
                        style={{
                          color: theme["color-basic-800"],
                          fontSize: 13,
                          fontWeight: bold ? "700" : "400",
                          fontStyle: italic ? "italic" : "normal",
                        }}
                      >
                        {label}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
                <TextInput
                  ref={inputRef}
                  style={[
                    styles.transcriptEditor,
                    { color: theme["color-basic-800"], backgroundColor: "transparent" },
                  ]}
                  multiline
                  textAlignVertical="top"
                  value={transcript}
                  onChangeText={onTranscriptChange}
                  onSelectionChange={(e) => setSelection(e.nativeEvent.selection)}
                  placeholder={t("details.notesPlaceholder")}
                  placeholderTextColor={theme["color-basic-500"]}
                />
              </View>
            ) : (
              <Markdown
                style={{
                  body: { color: theme["color-basic-800"], fontSize: 16, lineHeight: 26 },
                  heading1: { fontSize: 22, fontWeight: "700", color: theme["color-basic-900"], marginBottom: 8, marginTop: 16 },
                  heading2: { fontSize: 18, fontWeight: "700", color: theme["color-basic-900"], marginBottom: 6, marginTop: 14 },
                  heading3: { fontSize: 16, fontWeight: "600", color: theme["color-basic-900"], marginBottom: 4, marginTop: 12 },
                  strong: { fontWeight: "700" },
                  em: { fontStyle: "italic" },
                  bullet_list: { marginTop: 4 },
                  ordered_list: { marginTop: 4 },
                  list_item: { marginBottom: 4 },
                  code_inline: { backgroundColor: theme["color-basic-300"], paddingHorizontal: 4, borderRadius: 4, fontFamily: "monospace", fontSize: 14 },
                  fence: { backgroundColor: theme["color-basic-300"], borderRadius: 8, padding: 12, marginVertical: 8 },
                  blockquote: { borderLeftWidth: 3, borderLeftColor: ACCENT, paddingLeft: 12, marginVertical: 8, opacity: 0.85 },
                  hr: { borderColor: theme["color-basic-400"], marginVertical: 12 },
                }}
              >
                {transcript || "*No notes yet. Tap Edit to add some.*"}
              </Markdown>
            )}
          </View>
        )}

        {/* Transcript section */}
        {activeSegment === "Transcript" && (
          <View style={styles.transcriptContainer}>
            <Text style={{ color: theme["color-basic-600"], fontSize: 14, lineHeight: 22 }}>
              {transcript || t("recording.transcribing")}
            </Text>
          </View>
        )}
      </ScrollView>

      {/* FAB */}
      <TouchableOpacity
        testID="fab-save"
        onPress={onSave}
        style={[styles.fab, { backgroundColor: ACCENT }]}
      >
        <Ionicons name="checkmark" size={24} color={theme["color-basic-800"]} />
        {isDirty && <View testID="fab-dirty-dot" style={styles.fabDirtyDot} />}
      </TouchableOpacity>
    </Layout>
  );
};
