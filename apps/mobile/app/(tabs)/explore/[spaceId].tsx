import React, { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, ScrollView, StyleSheet, View } from "react-native";
import { Layout, Text, useTheme } from "@ui-kitten/components";
import { useLocalSearchParams, useRouter } from "expo-router";

import { getRecordingsInWorkspace, getWorkspaces } from "@/services/workspaceService";
import { recordToCard } from "@/services/recordingService";
import { AppHeader } from "@/components/AppHeader";
import RecordingCard from "@/Views/Home/RecordingCard";
import type { RecordingCard as RecordingCardType } from "@/processes/homeData";

export default function SpaceDetailScreen() {
  const { spaceId } = useLocalSearchParams<{ spaceId: string }>();
  const [spaceName, setSpaceName] = useState("");
  const [recordings, setRecordings] = useState<RecordingCardType[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();
  const theme = useTheme();

  const loadData = useCallback(async () => {
    if (!spaceId) return;
    try {
      setIsLoading(true);
      const [workspaces, records] = await Promise.all([
        getWorkspaces(),
        getRecordingsInWorkspace(spaceId),
      ]);
      const workspace = workspaces.find((w) => w.id === spaceId);
      if (workspace) setSpaceName(workspace.name);
      setRecordings(records.map(recordToCard));
    } catch (error) {
      console.error("Error loading space detail:", error);
    } finally {
      setIsLoading(false);
    }
  }, [spaceId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleCardPress = useCallback(
    (id: string) => {
      router.push(`/explore/recording/${id}`);
    },
    [router],
  );

  if (isLoading) {
    return (
      <Layout style={[styles.container, { justifyContent: "center", alignItems: "center" }]}>
        <ActivityIndicator size="large" />
      </Layout>
    );
  }

  return (
    <Layout style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}>
      <AppHeader title={spaceName} onBack={() => router.back()} borderBottom />

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {recordings.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={[styles.emptyText, { color: theme["color-basic-600"] }]}>
              No recordings in this space yet.
            </Text>
            <Text style={[styles.emptySubtext, { color: theme["color-basic-500"] }]}>
              Long-press a recording in Inbox to move it here.
            </Text>
          </View>
        ) : (
          <View style={styles.cardList}>
            {recordings.map((recording) => (
              <RecordingCard key={recording.id} {...recording} onPress={handleCardPress} />
            ))}
          </View>
        )}
      </ScrollView>
    </Layout>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 16,
  },
  cardList: {
    gap: 12,
    paddingBottom: 100,
  },
  emptyState: {
    paddingTop: 60,
    alignItems: "center",
    gap: 8,
  },
  emptyText: {
    fontSize: 16,
    fontWeight: "600",
  },
  emptySubtext: {
    fontSize: 14,
    textAlign: "center",
  },
});
