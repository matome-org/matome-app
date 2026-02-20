import React from "react";
import { ActivityIndicator, ScrollView, TouchableOpacity, View } from "react-native";
import { Layout, Text, useTheme } from "@ui-kitten/components";
import { Ionicons } from "@expo/vector-icons";

import { AppHeader, AppHeaderIconButton } from "@/components/AppHeader";
import { SpaceCard } from "@/processes/spacesData";
import { SpacesProps } from "./Spaces.types";
import { styles } from "./Spaces.styles";

const SPACE_COLORS = [
  "#6366F1", // indigo
  "#F59E0B", // amber
  "#10B981", // emerald
  "#EF4444", // red
  "#8B5CF6", // violet
  "#3B82F6", // blue
  "#EC4899", // pink
  "#14B8A6", // teal
];

const getSpaceColor = (index: number) => SPACE_COLORS[index % SPACE_COLORS.length];

const SpaceCardItem: React.FC<{
  space: SpaceCard;
  index: number;
  onPress: (id: string) => void;
  onLongPress: (id: string) => void;
}> = ({ space, index, onPress, onLongPress }) => {
  const theme = useTheme();
  const color = getSpaceColor(index);

  return (
    <TouchableOpacity
      style={[
        styles.spaceCard,
        {
          backgroundColor: theme["color-basic-100"],
          borderColor: theme["color-basic-300"],
        },
      ]}
      onPress={() => onPress(space.id)}
      onLongPress={() => onLongPress(space.id)}
    >
      <View style={[styles.spaceIconContainer, { backgroundColor: color + "20" }]}>
        <Ionicons name="folder-outline" size={24} color={color} />
      </View>
      <Text style={[styles.spaceName, { color: theme["color-basic-800"] }]} numberOfLines={2}>
        {space.name}
      </Text>
      <Text style={[styles.spaceCount, { color: theme["color-basic-600"] }]}>
        {space.count} {space.count === 1 ? "recording" : "recordings"}
      </Text>
    </TouchableOpacity>
  );
};

export const Spaces: React.FC<SpacesProps> = ({
  spaces,
  isLoading,
  onSpacePress,
  onSpaceLongPress,
  onCreatePress,
}) => {
  const theme = useTheme();

  if (isLoading) {
    return (
      <Layout style={[styles.container, { justifyContent: "center", alignItems: "center" }]}>
        <ActivityIndicator size="large" />
      </Layout>
    );
  }

  return (
    <Layout style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}>
      <AppHeader
        title="Spaces"
        rightActions={
          <AppHeaderIconButton icon="add" onPress={onCreatePress} size={22} />
        }
      />

      {spaces.length === 0 ? (
        <View style={styles.emptyState}>
          <Ionicons name="folder-open-outline" size={48} color={theme["color-basic-500"]} />
          <Text style={[styles.emptyText, { color: theme["color-basic-700"] }]}>
            No spaces yet
          </Text>
          <Text style={[styles.emptySubtext, { color: theme["color-basic-600"] }]}>
            Tap + to create a space and organize your recordings
          </Text>
        </View>
      ) : (
        <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.grid}>
            {spaces.map((space, index) => (
              <SpaceCardItem
                key={space.id}
                space={space}
                index={index}
                onPress={onSpacePress}
                onLongPress={onSpaceLongPress}
              />
            ))}
          </View>
        </ScrollView>
      )}
    </Layout>
  );
};
