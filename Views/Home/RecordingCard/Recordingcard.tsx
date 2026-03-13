import { Text, useTheme } from "@ui-kitten/components";
import { useTranslation } from "react-i18next";
import { RecordingCardProps } from "./RecordCard.types";

import { styles } from "../Home.styles";
import { ActivityIndicator, TouchableOpacity, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

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

  const handlePress = () => {
    onPress?.(id);
  };

  const getBadgeStyle = () => {
    if (badge === "Work") {
      return {
        backgroundColor: theme["color-primary-500"],
        color: theme["color-primary-900"],
      };
    }
    return {
      backgroundColor: theme["color-basic-300"],
      color: theme["color-basic-700"],
    };
  };

  const badgeStyle = getBadgeStyle();

  return (
    <TouchableOpacity
      style={[
        styles.recordCard,
        {
          backgroundColor: theme["color-basic-100"],
          borderColor: theme["color-basic-500"],
        },
      ]}
      onPress={handlePress}
      onLongPress={handleLongPress ?? (() => onLongPress?.(id))}
    >
      <View style={styles.cardIconArea}>
        <View
          style={[
            styles.playButton,
            {
              backgroundColor: isActive
                ? theme["color-primary-500"]
                : theme["color-basic-300"],
            },
          ]}
        >
          {isProcessing ? (
            <ActivityIndicator size="small" color={theme["color-basic-600"]} />
          ) : (
            <Ionicons
              name="play-outline"
              size={20}
              color={
                isActive ? theme["color-primary-900"] : theme["color-basic-700"]
              }
            />
          )}
        </View>
      </View>
      <View style={styles.cardContent}>
        <View style={styles.cardHeader}>
          <Text
            category="s1"
            style={[styles.cardTitle, { color: theme["color-basic-800"] }]}
            numberOfLines={1}
          >
            {title}
          </Text>
          <Text style={[styles.metaText, { color: theme["color-basic-600"] }]}>
            {timestamp}
          </Text>
        </View>
        {isProcessing ? (
          <Text
            style={[styles.processingText, { color: theme["color-basic-600"] }]}
          >
            {t("recording.transcribing")}
          </Text>
        ) : (
          summary && (
            <Text
              category="p2"
              style={[styles.cardSummary, { color: theme["color-basic-600"] }]}
              numberOfLines={2}
            >
              {summary}
            </Text>
          )
        )}
        <View style={styles.cardFooter}>
          <View
            style={[
              styles.badge,
              {
                backgroundColor: badgeStyle.backgroundColor,
              },
              badge === "Work" && styles.badgeWork,
              badge === "Personal" && styles.badgePersonal,
              badge === "Inbox" && styles.badgeInbox,
            ]}
          >
            <Text
              style={[styles.badgeText, { color: badgeStyle.color }]}
              category="c1"
            >
              {badge}
            </Text>
          </View>
          <Text style={[styles.metaText, { color: theme["color-basic-600"] }]}>
            {duration}
          </Text>
        </View>
      </View>
    </TouchableOpacity>
  );
};

export default RecordingCard;
