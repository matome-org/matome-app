import { Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useCallback, useRef, useState } from "react";
import {
  ActivityIndicator,
  RefreshControl,
  ScrollView,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import { useTranslation } from "react-i18next";
import { Ionicons } from "@expo/vector-icons";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { HomeSectionProps, HomeProps } from "./Home.types";
import { styles } from "./Home.styles";
import RecordingCard from "./RecordingCard";

const FILTER_CHIPS = ["All", "Today", "Work", "Ideas", "Unresolved"] as const;

const HomeSection: React.FC<HomeSectionProps> = ({
  title,
  recordings,
  onCardPress,
  onCardLongPress,
}) => {
  const theme = useTheme();

  return (
    <View>
      <View style={styles.sectionHeader}>
        <Text style={[styles.sectionTitle, { color: theme["color-basic-600"] }]}>
          {title.toUpperCase()}
        </Text>
        <Text style={[styles.sectionCount, { color: theme["color-basic-500"] }]}>
          {recordings.length}
        </Text>
      </View>
      <View style={styles.cardList}>
        {recordings.map((recording) => (
          <RecordingCard
            key={recording.id}
            {...recording}
            onPress={onCardPress}
            onLongPress={onCardLongPress}
          />
        ))}
      </View>
    </View>
  );
};

export const Home: React.FC<HomeProps> = ({
  data,
  isLoading,
  isRefreshing,
  searchQuery = "",
  onCardPress,
  onCardLongPress,
  onSearchChange,
  onSearchClose,
  onSettingsPress,
  onRefresh,
}) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  const inputRef = useRef<TextInput>(null);
  const [activeChip, setActiveChip] = useState<string>("All");

  const renderSection = useCallback(
    ({ title, recordings }: HomeSectionProps) => (
      <HomeSection
        title={title}
        key={title}
        recordings={recordings}
        onCardPress={onCardPress}
        onCardLongPress={onCardLongPress}
      />
    ),
    [onCardPress, onCardLongPress],
  );

  if (isLoading) {
    return (
      <Layout
        style={[
          styles.container,
          { justifyContent: "center", alignItems: "center" },
        ]}
      >
        <ActivityIndicator size="large" color={theme["color-primary-500"]} />
      </Layout>
    );
  }

  const totalRecordings = data.sections.reduce(
    (sum, s) => sum + s.recordings.length,
    0,
  );

  const hasNoResults =
    searchQuery.trim().length > 0 && data.sections.length === 0;

  return (
    <Layout
      style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}
    >
      {/* Top header */}
      <View
        style={[
          styles.topBar,
          {
            paddingTop: insets.top + 8,
            backgroundColor: theme["color-basic-200"],
            borderBottomColor: theme["color-basic-400"],
          },
        ]}
      >
        <View style={styles.topBarRow}>
          <View>
            <Text style={[styles.wordmark, { color: theme["color-basic-800"] }]}>
              マトメ
            </Text>
            <Text style={[styles.topBarTitle, { color: theme["color-basic-800"] }]}>
              {t("inbox.title")}
            </Text>
            {totalRecordings > 0 && (
              <Text style={[styles.topBarSubtitle, { color: theme["color-basic-600"] }]}>
                {totalRecordings} {t("inbox.recordings")}
              </Text>
            )}
          </View>
          <View style={styles.topBarActions}>
            <TouchableOpacity
              style={[
                styles.iconBtn,
                {
                  backgroundColor: theme["color-basic-100"],
                  borderColor: theme["color-basic-400"],
                },
              ]}
              onPress={onSettingsPress}
            >
              <Ionicons
                name="settings-outline"
                size={18}
                color={theme["color-basic-700"]}
              />
            </TouchableOpacity>
          </View>
        </View>

        {/* Always-visible search bar */}
        <View
          style={[
            styles.searchBar,
            {
              backgroundColor: theme["color-basic-100"],
              borderColor: theme["color-basic-400"],
            },
          ]}
        >
          <Ionicons
            name="search-outline"
            size={16}
            color={theme["color-basic-600"]}
          />
          <TextInput
            ref={inputRef}
            style={[styles.searchInput, { color: theme["color-basic-800"] }]}
            placeholder={t("inbox.searchPlaceholder")}
            placeholderTextColor={theme["color-basic-600"]}
            value={searchQuery}
            onChangeText={onSearchChange}
            returnKeyType="search"
            clearButtonMode="never"
          />
          {searchQuery.length > 0 && (
            <TouchableOpacity onPress={onSearchClose} hitSlop={8}>
              <Ionicons
                name="close-circle"
                size={16}
                color={theme["color-basic-600"]}
              />
            </TouchableOpacity>
          )}
          <View
            style={[
              styles.kbdHint,
              { backgroundColor: "rgba(14,15,16,0.06)" },
            ]}
          >
            <Text style={[styles.kbdHintText, { color: theme["color-basic-600"] }]}>
              ⌘ K
            </Text>
          </View>
        </View>

        {/* Filter chips */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.chipsScroll}
          contentContainerStyle={styles.chipsContent}
        >
          {FILTER_CHIPS.map((chip) => (
            <TouchableOpacity
              key={chip}
              style={[
                styles.chip,
                activeChip === chip
                  ? { backgroundColor: theme["color-basic-800"] }
                  : {
                      backgroundColor: "rgba(14,15,16,0.04)",
                      borderColor: "transparent",
                    },
              ]}
              onPress={() => setActiveChip(chip)}
              activeOpacity={0.75}
            >
              <Text
                style={[
                  styles.chipText,
                  {
                    color:
                      activeChip === chip ? "#fff" : theme["color-basic-700"],
                  },
                ]}
              >
                {chip}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {hasNoResults ? (
        <View style={styles.emptySearch}>
          <Ionicons
            name="search-outline"
            size={40}
            color={theme["color-basic-500"]}
          />
          <Text style={{ color: theme["color-basic-600"] }}>
            {t("inbox.noResults")}
          </Text>
        </View>
      ) : (
        <ScrollView
          style={styles.content}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl
              refreshing={!!isRefreshing}
              onRefresh={onRefresh}
              tintColor={theme["color-primary-500"]}
            />
          }
        >
          {data.sections.map(renderSection)}
          <View style={{ height: 24 }} />
        </ScrollView>
      )}
    </Layout>
  );
};
