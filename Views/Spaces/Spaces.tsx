import React from "react";
import { ActivityIndicator, ScrollView, TouchableOpacity, View } from "react-native";
import { Layout, Text, useTheme } from "@ui-kitten/components";
import { Ionicons } from "@expo/vector-icons";
import { useTranslation } from "react-i18next";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { SpaceCard } from "@/processes/spacesData";
import { SpacesProps } from "./Spaces.types";
import { styles } from "./Spaces.styles";

const ACCENT = "#E1B346";
const ACCENT_DARK = "#B98A1F";
const ACCENT_SOFT = "#F6E8C0";

const SPACE_COLORS = [
  "#E1B346",
  "#6FB180",
  "#6A8AD9",
  "#D98A55",
  "#C97A9C",
  "#A089CC",
  "#14B8A6",
  "#EF4444",
];

const getSpaceColor = (index: number) => SPACE_COLORS[index % SPACE_COLORS.length];

const SMART_SPACES = [
  { icon: "checkmark-circle-outline", label: "Unresolved todos", count: "" },
  { icon: "time-outline", label: "This week", count: "" },
  { icon: "at-outline", label: "Starred", count: "" },
];

const SpaceListItem: React.FC<{
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
        styles.spaceListItem,
        {
          backgroundColor: theme["color-basic-100"],
          borderColor: theme["color-basic-400"],
        },
      ]}
      onPress={() => onPress(space.id)}
      onLongPress={() => onLongPress(space.id)}
      activeOpacity={0.8}
    >
      <View style={[styles.spaceIcon, { backgroundColor: color + "22" }]}>
        <Ionicons name="folder-outline" size={22} color={color} />
      </View>
      <View style={styles.spaceInfo}>
        <View style={styles.spaceNameRow}>
          <Text
            style={[styles.spaceName, { color: theme["color-basic-800"] }]}
            numberOfLines={1}
          >
            {space.name}
          </Text>
          <Text style={[styles.spaceCount, { color: theme["color-basic-600"] }]}>
            {space.count}
          </Text>
        </View>
        <Text style={[styles.spaceDetail, { color: theme["color-basic-600"] }]}>
          {space.count === 1 ? "1 recording" : `${space.count} recordings`}
        </Text>
      </View>
      <Ionicons name="chevron-forward" size={16} color={theme["color-basic-500"]} />
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
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();

  if (isLoading) {
    return (
      <Layout style={[styles.container, { justifyContent: "center", alignItems: "center" }]}>
        <ActivityIndicator size="large" color={ACCENT} />
      </Layout>
    );
  }

  return (
    <Layout style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[
          styles.scrollContent,
          { paddingTop: insets.top + 8 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={[styles.title, { color: theme["color-basic-800"] }]}>
              {t("spaces.title")}
            </Text>
            {spaces.length > 0 && (
              <Text style={[styles.subtitle, { color: theme["color-basic-600"] }]}>
                {spaces.length} spaces
              </Text>
            )}
          </View>
          <TouchableOpacity
            style={[
              styles.addBtn,
              {
                backgroundColor: theme["color-basic-800"],
              },
            ]}
            onPress={onCreatePress}
            activeOpacity={0.8}
          >
            <Ionicons name="add" size={20} color="#fff" />
          </TouchableOpacity>
        </View>

        {spaces.length === 0 ? (
          <View style={styles.emptyState}>
            <Ionicons name="folder-open-outline" size={48} color={theme["color-basic-500"]} />
            <Text style={[styles.emptyText, { color: theme["color-basic-700"] }]}>
              {t("spaces.empty")}
            </Text>
            <Text style={[styles.emptySubtext, { color: theme["color-basic-600"] }]}>
              {t("spaces.emptyHint")}
            </Text>
          </View>
        ) : (
          <>
            {/* Smart spaces rail */}
            <View style={styles.sectionHeader}>
              <Text style={[styles.sectionLabel, { color: theme["color-basic-600"] }]}>
                SMART SPACES
              </Text>
            </View>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.smartRail}
            >
              {SMART_SPACES.map((s) => (
                <TouchableOpacity
                  key={s.label}
                  style={[
                    styles.smartCard,
                    {
                      backgroundColor: theme["color-basic-100"],
                      borderColor: theme["color-basic-400"],
                    },
                  ]}
                  activeOpacity={0.8}
                >
                  <View
                    style={[
                      styles.smartIcon,
                      { backgroundColor: ACCENT_SOFT },
                    ]}
                  >
                    <Ionicons name={s.icon as never} size={16} color={ACCENT_DARK} />
                  </View>
                  <Text
                    style={[styles.smartLabel, { color: theme["color-basic-800"] }]}
                    numberOfLines={2}
                  >
                    {s.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>

            {/* Your spaces */}
            <View style={styles.sectionHeader}>
              <Text style={[styles.sectionLabel, { color: theme["color-basic-600"] }]}>
                YOUR SPACES
              </Text>
            </View>
            <View style={styles.listContainer}>
              {spaces.map((space, index) => (
                <SpaceListItem
                  key={space.id}
                  space={space}
                  index={index}
                  onPress={onSpacePress}
                  onLongPress={onSpaceLongPress}
                />
              ))}
            </View>
          </>
        )}
      </ScrollView>
    </Layout>
  );
};
