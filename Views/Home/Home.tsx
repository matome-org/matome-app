import { Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useCallback, useRef } from "react";
import { ActivityIndicator, RefreshControl, ScrollView, TextInput, TouchableOpacity, View } from "react-native";
import { useTranslation } from "react-i18next";
import { Ionicons } from "@expo/vector-icons";

import { AppHeader, AppHeaderIconButton } from "@/components/AppHeader";
import { HomeSectionProps, HomeProps } from "./Home.types";
import { styles } from "./Home.styles";

import RecordingCard from "./RecordingCard";

const HomeSection: React.FC<HomeSectionProps> = ({
  title,
  recordings,
  onCardPress,
  onCardLongPress,
}) => {
  const theme = useTheme();

  return (
    <View>
      <Text style={[styles.sectionTitle, { color: theme["color-basic-600"] }]}>
        {title}
      </Text>
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
  isSearchOpen,
  searchQuery = "",
  onCardPress,
  onCardLongPress,
  onSearchPress,
  onSearchChange,
  onSearchClose,
  onSettingsPress,
  onRefresh,
}) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const inputRef = useRef<TextInput>(null);

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
        <ActivityIndicator size="large" />
      </Layout>
    );
  }

  const hasNoResults = isSearchOpen && searchQuery.trim().length > 0 && data.sections.length === 0;

  return (
    <Layout
      style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}
    >
      <AppHeader
        title={t("inbox.title")}
        rightActions={
          <>
            <AppHeaderIconButton
              icon={isSearchOpen ? "search" : "search-outline"}
              onPress={onSearchPress}
            />
            <AppHeaderIconButton icon="settings-outline" onPress={onSettingsPress} />
          </>
        }
      />

      {isSearchOpen && (
        <View
          style={[
            styles.searchBar,
            {
              backgroundColor: theme["color-basic-100"],
              borderColor: theme["color-basic-400"],
            },
          ]}
        >
          <Ionicons name="search-outline" size={18} color={theme["color-basic-600"]} />
          <TextInput
            ref={inputRef}
            autoFocus
            style={[styles.searchInput, { color: theme["color-basic-800"] }]}
            placeholder={t("inbox.searchPlaceholder")}
            placeholderTextColor={theme["color-basic-600"]}
            value={searchQuery}
            onChangeText={onSearchChange}
            returnKeyType="search"
            clearButtonMode="never"
          />
          <TouchableOpacity onPress={onSearchClose} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={theme["color-basic-600"]} />
          </TouchableOpacity>
        </View>
      )}

      {hasNoResults ? (
        <View style={styles.emptySearch}>
          <Ionicons name="search-outline" size={40} color={theme["color-basic-500"]} />
          <Text style={{ color: theme["color-basic-600"] }}>
            {t("inbox.noResults")}
          </Text>
        </View>
      ) : (
        <ScrollView
          style={styles.content}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={!!isRefreshing} onRefresh={onRefresh} />
          }
        >
          {data.sections.map(renderSection)}
        </ScrollView>
      )}
    </Layout>
  );
};
