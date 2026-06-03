import React from "react";
import { Text, useTheme } from "@ui-kitten/components";
import { useTranslation } from "react-i18next";
import { RecordingCardProps } from "./RecordCard.types";
import { ActivityIndicator, TouchableOpacity, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { StyleSheet } from "react-native";

const BADGE_COLORS: Record<string, string> = {
  Work: "#E1B346",
  Personal: "#6FB180",
  Inbox: "#6A8AD9",
};

const getBadgeColor = (badge: string) =>
  BADGE_COLORS[badge] ?? "#A6ADB8";

const RecordingCard: React.FC<RecordingCardProps> = ({
  id,
  title,
  summary,
  timestamp,
  duration,
  badge,
  isProcessing,
  isActive,
  onPress,
  onLongPress,
  handleLongPress,
}) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const color = getBadgeColor(badge);

  const handlePress = () => {
    onPress?.(id);
  };

  return (
    <TouchableOpacity
      testID="recording-card"
      style={[
        cardStyles.card,
        {
          backgroundColor: theme["color-basic-100"],
          borderColor: theme["color-basic-400"],
        },
      ]}
      onPress={handlePress}
      onLongPress={handleLongPress ?? (() => onLongPress?.(id))}
      activeOpacity={0.8}
    >
      {/* Left avatar */}
      <View
        style={[
          cardStyles.avatar,
          { backgroundColor: color + "22" },
        ]}
      >
        {isProcessing ? (
          <View
            style={[cardStyles.processingDot, { backgroundColor: color }]}
          />
        ) : (
          <Ionicons name="play" size={16} color={color} />
        )}
      </View>

      {/* Content */}
      <View style={cardStyles.content}>
        {/* Title row */}
        <View style={cardStyles.titleRow}>
          <Text
            style={[cardStyles.title, { color: theme["color-basic-800"] }]}
            numberOfLines={1}
          >
            {title}
          </Text>
          <Text style={[cardStyles.time, { color: theme["color-basic-600"] }]}>
            {timestamp}
          </Text>
        </View>

        {/* Summary / processing */}
        {isProcessing ? (
          <View style={cardStyles.processingRow}>
            <ActivityIndicator
              size="small"
              color={color}
              style={{ transform: [{ scale: 0.7 }] }}
            />
            <Text style={[cardStyles.processingText, { color: color }]}>
              {t("recording.transcribing")}
            </Text>
          </View>
        ) : (
          summary != null && summary.length > 0 && (
            <Text
              style={[cardStyles.summary, { color: theme["color-basic-600"] }]}
              numberOfLines={2}
            >
              {summary}
            </Text>
          )
        )}

        {/* Footer: badge + duration */}
        <View style={cardStyles.footer}>
          <View style={cardStyles.badgePill}>
            <View
              style={[cardStyles.badgeDot, { backgroundColor: color }]}
            />
            <Text style={[cardStyles.badgeText, { color: theme["color-basic-700"] }]}>
              {badge}
            </Text>
          </View>
          <Text style={[cardStyles.duration, { color: theme["color-basic-500"] }]}>
            {duration}
          </Text>
          {isActive && (
            <View
              style={[
                cardStyles.activePip,
                { backgroundColor: theme["color-primary-500"] },
              ]}
            />
          )}
        </View>
      </View>
    </TouchableOpacity>
  );
};

const cardStyles = StyleSheet.create({
  card: {
    borderRadius: 16,
    padding: 14,
    flexDirection: "row",
    gap: 12,
    borderWidth: 1,
    shadowColor: "#0e0f10",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  processingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  content: {
    flex: 1,
    minWidth: 0,
    gap: 4,
  },
  titleRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "baseline",
    gap: 8,
  },
  title: {
    fontSize: 15,
    fontWeight: "700",
    flex: 1,
  },
  time: {
    fontSize: 11,
    flexShrink: 0,
  },
  summary: {
    fontSize: 13,
    lineHeight: 18,
  },
  processingRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  processingText: {
    fontSize: 12,
    fontStyle: "italic",
  },
  footer: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    marginTop: 4,
  },
  badgePill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 999,
    backgroundColor: "rgba(14,15,16,0.05)",
  },
  badgeDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: "600",
  },
  duration: {
    fontSize: 11,
  },
  activePip: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginLeft: 4,
  },
});

export default RecordingCard;
