import { Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";

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
  onBack,
  onSave,
  onMoreOptions,
}) => {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
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
      {/* Header */}
      <View
        style={[
          styles.header,
          {
            backgroundColor: theme["color-basic-200"],
            borderBottomColor: theme["color-basic-500"],
            paddingTop: insets.top + 16,
          },
        ]}
      >
        <View style={styles.headerLeft}>
          <TouchableOpacity
            onPress={onBack}
            style={[styles.iconButton, { backgroundColor: "transparent" }]}
          >
            <Ionicons
              name="chevron-back"
              size={24}
              color={theme["color-primary-500"]}
            />
          </TouchableOpacity>
          <Text
            category="s1"
            style={[styles.headerTitle, { color: theme["color-basic-800"] }]}
            numberOfLines={1}
          >
            {recording.title}
          </Text>
        </View>
        <TouchableOpacity
          onPress={onMoreOptions}
          style={[styles.iconButton, { backgroundColor: "transparent" }]}
        >
          <Ionicons
            name="ellipsis-horizontal"
            size={24}
            color={theme["color-primary-500"]}
          />
        </TouchableOpacity>
      </View>

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
        {recording.summary && (
          <View style={styles.section}>
            <View style={styles.sectionLabel}>
              <Ionicons
                name="sparkles"
                size={14}
                color={theme["color-primary-500"]}
              />
              <Text
                style={[
                  styles.sectionLabel,
                  { color: theme["color-basic-600"] },
                ]}
              >
                Summary
              </Text>
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
                  color: theme["color-basic-800"],
                  fontSize: 15,
                  lineHeight: 24,
                }}
              >
                {recording.summary}
              </Text>
            </View>
          </View>
        )}

        {/* Notes */}
        <View style={styles.transcriptContainer}>
          <View style={styles.sectionLabel}>
            <Ionicons
              name="document-text"
              size={14}
              color={theme["color-basic-600"]}
            />
            <Text
              style={[styles.sectionLabel, { color: theme["color-basic-600"] }]}
            >
              Notes
            </Text>
          </View>
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
            placeholder="Start typing your notes..."
            placeholderTextColor={theme["color-basic-500"]}
          />
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
