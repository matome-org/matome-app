import { Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useCallback } from "react";
import { ActivityIndicator, RefreshControl, ScrollView, View } from "react-native";

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
  onCardPress,
  onCardLongPress,
  onSearchPress,
  onSettingsPress,
  onRefresh,
}) => {
  const theme = useTheme();

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

  return (
    <Layout
      style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}
    >
      <AppHeader
        title="Inbox"
        rightActions={
          <>
            <AppHeaderIconButton icon="search-outline" onPress={onSearchPress} />
            <AppHeaderIconButton icon="settings-outline" onPress={onSettingsPress} />
          </>
        }
      />

      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={!!isRefreshing} onRefresh={onRefresh} />
        }
      >
        {data.sections.map(renderSection)}
      </ScrollView>
    </Layout>
  );
};
