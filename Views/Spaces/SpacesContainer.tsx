import React, { useCallback, useEffect, useState } from "react";
import { Alert, Modal, Pressable, StyleSheet, TextInput, View } from "react-native";
import { Text, useTheme } from "@ui-kitten/components";
import { useRouter } from "expo-router";

import { fetchSpacesData, SpaceCard } from "@/processes/spacesData";
import { createWorkspace, deleteWorkspace } from "@/services/workspaceService";
import { useRecordingsStore } from "@/stores/recordingsStore";

import { Spaces } from "./Spaces";

const SpacesContainer: React.FC = () => {
  const [spaces, setSpaces] = useState<SpaceCard[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [createModalVisible, setCreateModalVisible] = useState(false);
  const [newSpaceName, setNewSpaceName] = useState("");
  const router = useRouter();
  const refreshKey = useRecordingsStore((state) => state.refreshKey);
  const theme = useTheme();

  const loadSpaces = useCallback(async () => {
    try {
      const data = await fetchSpacesData();
      setSpaces(data);
    } catch (error) {
      console.error("Error loading spaces:", error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSpaces();
  }, [loadSpaces, refreshKey]);

  const handleSpacePress = useCallback(
    (id: string) => {
      router.push(`/explore/${id}`);
    },
    [router],
  );

  const handleSpaceLongPress = useCallback(
    (id: string) => {
      const space = spaces.find((s) => s.id === id);
      if (!space) return;

      Alert.alert(
        `Delete "${space.name}"?`,
        "Recordings in this space will return to your Inbox.",
        [
          { text: "Cancel", style: "cancel" },
          {
            text: "Delete",
            style: "destructive",
            onPress: async () => {
              try {
                await deleteWorkspace(id);
                await loadSpaces();
              } catch (error) {
                console.error("Error deleting workspace:", error);
              }
            },
          },
        ],
      );
    },
    [spaces, loadSpaces],
  );

  const handleCreatePress = useCallback(() => {
    setNewSpaceName("");
    setCreateModalVisible(true);
  }, []);

  const handleCreateConfirm = useCallback(async () => {
    if (!newSpaceName.trim()) return;
    try {
      await createWorkspace(newSpaceName.trim());
      setCreateModalVisible(false);
      setNewSpaceName("");
      await loadSpaces();
    } catch (error) {
      console.error("Error creating workspace:", error);
    }
  }, [newSpaceName, loadSpaces]);

  const handleCreateCancel = useCallback(() => {
    setCreateModalVisible(false);
    setNewSpaceName("");
  }, []);

  return (
    <>
      <Spaces
        spaces={spaces}
        isLoading={isLoading}
        onSpacePress={handleSpacePress}
        onSpaceLongPress={handleSpaceLongPress}
        onCreatePress={handleCreatePress}
      />

      <Modal
        visible={createModalVisible}
        transparent
        animationType="fade"
        onRequestClose={handleCreateCancel}
      >
        <Pressable style={modalStyles.overlay} onPress={handleCreateCancel}>
          <Pressable
            style={[modalStyles.sheet, { backgroundColor: theme["color-basic-100"] }]}
            onPress={(e) => e.stopPropagation()}
          >
            <Text category="h6" style={[modalStyles.title, { color: theme["color-basic-800"] }]}>
              New Space
            </Text>
            <TextInput
              style={[
                modalStyles.input,
                {
                  backgroundColor: theme["color-basic-200"],
                  borderColor: theme["color-basic-400"],
                  color: theme["color-basic-800"],
                },
              ]}
              placeholder="Space name"
              placeholderTextColor={theme["color-basic-500"]}
              value={newSpaceName}
              onChangeText={setNewSpaceName}
              autoFocus
              onSubmitEditing={handleCreateConfirm}
              returnKeyType="done"
            />
            <View style={modalStyles.buttons}>
              <Pressable
                style={[modalStyles.btn, { backgroundColor: theme["color-basic-300"] }]}
                onPress={handleCreateCancel}
              >
                <Text style={{ color: theme["color-basic-700"], fontWeight: "600" }}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[
                  modalStyles.btn,
                  { backgroundColor: theme["color-primary-500"], opacity: newSpaceName.trim() ? 1 : 0.5 },
                ]}
                onPress={handleCreateConfirm}
                disabled={!newSpaceName.trim()}
              >
                <Text style={{ color: "#fff", fontWeight: "600" }}>Create</Text>
              </Pressable>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
    </>
  );
};

const modalStyles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.4)",
    justifyContent: "center",
    alignItems: "center",
    padding: 24,
  },
  sheet: {
    width: "100%",
    borderRadius: 16,
    padding: 24,
    gap: 16,
  },
  title: {
    marginBottom: 4,
  },
  input: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
  },
  buttons: {
    flexDirection: "row",
    gap: 12,
  },
  btn: {
    flex: 1,
    borderRadius: 8,
    padding: 12,
    alignItems: "center",
  },
});

export default SpacesContainer;
