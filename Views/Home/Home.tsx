import { Button, Layout, Text, useTheme } from "@ui-kitten/components";
import React, { useCallback } from "react";
import { ActivityIndicator, RefreshControl, ScrollView, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";

import { HomeSectionProps, HomeProps } from "./Home.types";
import { styles } from "./Home.styles";

import RecordingCard from "./RecordingCard";

const HomeSection: React.FC<HomeSectionProps> = ({
  title,
  recordings,
  onCardPress,
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
  onSearchPress,
  onSignOutPress,
  onRefresh,
}) => {
  const theme = useTheme();
  const insets = useSafeAreaInsets();

  const renderSection = useCallback(
    ({ title, recordings }: HomeSectionProps) => (
      <HomeSection
        title={title}
        key={title}
        recordings={recordings}
        onCardPress={onCardPress}
      />
    ),
    [onCardPress],
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
      {/* Header */}
      <View
        style={[
          styles.header,
          {
            backgroundColor: theme["color-basic-200"],
            paddingTop: insets.top + 16,
          },
        ]}
      >
        <Text
          category="h4"
          style={[styles.headerTitle, { color: theme["color-basic-800"] }]}
        >
          Inbox
        </Text>
        <View
          style={{ flexDirection: "row", gap: 8 }}
        >
          <Button
            appearance="ghost"
            accessoryLeft={() => (
              <Ionicons
                name="log-out-outline"
                size={20}
                color={theme["color-basic-700"]}
              />
            )}
            style={[
              styles.iconButton,
              {
                backgroundColor: theme["color-basic-100"],
                borderColor: theme["color-basic-500"],
                borderWidth: 1,
              },
            ]}
            onPress={onSignOutPress}
          />
          <Button
            appearance="ghost"
            accessoryLeft={() => (
              <Ionicons
                name="search-outline"
                size={16}
                color={theme["color-basic-700"]}
              />
            )}
            style={[
              styles.iconButton,
              {
                backgroundColor: theme["color-basic-100"],
                borderColor: theme["color-basic-500"],
                borderWidth: 1,
              },
            ]}
            onPress={onSearchPress}
          />
        </View>
      </View>

      {/* Content */}
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
