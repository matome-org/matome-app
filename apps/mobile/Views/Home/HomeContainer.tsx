import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Alert } from "react-native";
import * as DocumentPicker from "expo-document-picker";
import * as ImagePicker from "expo-image-picker";
import { useRouter } from "expo-router";

import { fetchHomeData, HomeData } from "@/processes/homeData";
import { fetchSpacesData, SpaceCard } from "@/processes/spacesData";
import { useRecordingsStore } from "@/stores/recordingsStore";
import { useLanguageStore } from "@/stores/languageStore";
import { updateRecording } from "@/services/recordingService";
import { retryUploadedRecording, uploadPickedRecording } from "@/services/uploadRecordingService";
import { MoveToSpaceSheet } from "@/components/MoveToSpaceSheet";

import { Home } from "./Home";

const HomeContainer: React.FC = () => {
  const [data, setData] = useState<HomeData>({ sections: [] });
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedRecordingId, setSelectedRecordingId] = useState<string | null>(null);
  const [spaces, setSpaces] = useState<SpaceCard[]>([]);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const router = useRouter();
  const refreshKey = useRecordingsStore((state) => state.refreshKey);
  const triggerRefresh = useRecordingsStore((state) => state.triggerRefresh);
  const language = useLanguageStore((state) => state.language);

  const loadData = useCallback(async (silent = false) => {
    try {
      if (!silent) setIsLoading(true);
      const homeData = await fetchHomeData();
      setData(homeData);
    } catch (error) {
      console.error("Error loading home data:", error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, []);

  // Initial load + auto-refresh when a recording is saved
  useEffect(() => {
    loadData(refreshKey > 0);
  }, [refreshKey, loadData]);

  // Re-fetch when language changes so section titles (Today/Yesterday) update
  useEffect(() => {
    loadData(true);
  }, [language, loadData]);

  const handleRefresh = useCallback(() => {
    setIsRefreshing(true);
    loadData(true);
  }, [loadData]);

  const handleCardPress = (id: string) => {
    router.push(`/inbox/${id}`);
  };

  const handleCardLongPress = useCallback(async (id: string) => {
    try {
      const spaceData = await fetchSpacesData();
      setSpaces(spaceData);
      setSelectedRecordingId(id);
    } catch (error) {
      console.error("Error fetching spaces for move sheet:", error);
    }
  }, []);

  const handleMoveToSpace = useCallback(async (spaceId: string) => {
    if (!selectedRecordingId) return;
    try {
      await updateRecording(selectedRecordingId, { workspaceId: spaceId });
      setSelectedRecordingId(null);
      triggerRefresh();
    } catch (error) {
      console.error("Error moving recording to space:", error);
    }
  }, [selectedRecordingId, triggerRefresh]);

  const handleMoveSheetClose = useCallback(() => {
    setSelectedRecordingId(null);
  }, []);

  const filteredData = useMemo(() => {
    if (!searchQuery.trim()) return data;
    const q = searchQuery.toLowerCase();
    const sections = data.sections
      .map((section) => ({
        ...section,
        recordings: section.recordings.filter(
          (r) =>
            r.title.toLowerCase().includes(q) ||
            r.summary?.toLowerCase().includes(q) ||
            r.notes?.toLowerCase().includes(q),
        ),
      }))
      .filter((section) => section.recordings.length > 0);
    return { sections };
  }, [data, searchQuery]);

  const handleSearchPress = useCallback(() => {
    setIsSearchOpen(true);
  }, []);

  const handleSearchChange = useCallback((query: string) => {
    setSearchQuery(query);
  }, []);

  const handleSearchClose = useCallback(() => {
    setIsSearchOpen(false);
    setSearchQuery("");
  }, []);

  const handleSettingsPress = useCallback(() => {
    router.push('/inbox/settings');
  }, [router]);

  const importPickedFile = useCallback(async ({
    uri,
    title,
    mediaType,
  }: {
    uri: string;
    title: string;
    mediaType: "audio" | "meeting" | "image";
  }) => {
    try {
      await uploadPickedRecording({ uri, title, mediaType });
      triggerRefresh();
    } catch (error) {
      console.error("Error importing recording:", error);
      Alert.alert("Import failed", "Could not start the upload. Please try again.");
    }
  }, [triggerRefresh]);

  const handlePhotoImport = useCallback(async () => {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      Alert.alert("Photos permission required", "Allow photo access to import images.");
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      allowsMultipleSelection: false,
      quality: 1,
    });
    if (result.canceled || !result.assets[0]) return;

    const asset = result.assets[0];
    await importPickedFile({
      uri: asset.uri,
      title: asset.fileName ?? "Imported Image",
      mediaType: "image",
    });
  }, [importPickedFile]);

  const handleAudioImport = useCallback(async () => {
    const result = await DocumentPicker.getDocumentAsync({
      type: "audio/*",
      copyToCacheDirectory: true,
      multiple: false,
    });
    if (result.canceled || !result.assets[0]) return;

    const asset = result.assets[0];
    await importPickedFile({
      uri: asset.uri,
      title: asset.name || "Imported Audio",
      mediaType: "audio",
    });
  }, [importPickedFile]);

  const handleFileImport = useCallback(async () => {
    const result = await DocumentPicker.getDocumentAsync({
      copyToCacheDirectory: true,
      multiple: false,
    });
    if (result.canceled || !result.assets[0]) return;

    const asset = result.assets[0];
    const isImage = asset.mimeType?.startsWith("image/");
    const isAudio = asset.mimeType?.startsWith("audio/");
    await importPickedFile({
      uri: asset.uri,
      title: asset.name || "Imported File",
      mediaType: isImage ? "image" : isAudio ? "audio" : "meeting",
    });
  }, [importPickedFile]);

  const handleImportPress = useCallback(() => {
    Alert.alert("Import", "Choose what to upload", [
      { text: "Photo", onPress: handlePhotoImport },
      { text: "Audio", onPress: handleAudioImport },
      { text: "File", onPress: handleFileImport },
      { text: "Cancel", style: "cancel" },
    ]);
  }, [handleAudioImport, handleFileImport, handlePhotoImport]);

  const handleRetryRecording = useCallback(async (id: string) => {
    try {
      await retryUploadedRecording(id);
      triggerRefresh();
    } catch (error) {
      console.error("Error retrying imported recording:", error);
    }
  }, [triggerRefresh]);

  if (!data && !isLoading) {
    return null;
  }

  return (
    <>
      <Home
        data={filteredData}
        isLoading={isLoading}
        isRefreshing={isRefreshing}
        isSearchOpen={isSearchOpen}
        searchQuery={searchQuery}
        onCardPress={handleCardPress}
        onCardLongPress={handleCardLongPress}
        onSearchPress={handleSearchPress}
        onSearchChange={handleSearchChange}
        onSearchClose={handleSearchClose}
        onSettingsPress={handleSettingsPress}
        onImportPress={handleImportPress}
        onRetryRecording={handleRetryRecording}
        onRefresh={handleRefresh}
      />
      <MoveToSpaceSheet
        visible={selectedRecordingId !== null}
        spaces={spaces}
        onMove={handleMoveToSpace}
        onClose={handleMoveSheetClose}
      />
    </>
  );
};

export default HomeContainer;
