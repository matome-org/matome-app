import React from "react";
import { FlatList, Modal, Pressable, StyleSheet, TouchableOpacity, View } from "react-native";
import { Text, useTheme } from "@ui-kitten/components";
import { Ionicons } from "@expo/vector-icons";

import { SpaceCard } from "@/processes/spacesData";
import { MoveToSpaceSheetProps } from "./MoveToSpaceSheet.types";

const SPACE_COLORS = [
  "#6366F1",
  "#F59E0B",
  "#10B981",
  "#EF4444",
  "#8B5CF6",
  "#3B82F6",
  "#EC4899",
  "#14B8A6",
];

const getSpaceColor = (index: number) => SPACE_COLORS[index % SPACE_COLORS.length];

export const MoveToSpaceSheet: React.FC<MoveToSpaceSheetProps> = ({
  visible,
  spaces,
  onMove,
  onClose,
}) => {
  const theme = useTheme();

  const renderItem = ({ item, index }: { item: SpaceCard; index: number }) => {
    const color = getSpaceColor(index);
    return (
      <TouchableOpacity
        style={[styles.spaceRow, { borderBottomColor: theme["color-basic-300"] }]}
        onPress={() => onMove(item.id)}
      >
        <View style={[styles.iconWrap, { backgroundColor: color + "20" }]}>
          <Ionicons name="folder-outline" size={20} color={color} />
        </View>
        <View style={styles.rowText}>
          <Text style={[styles.spaceName, { color: theme["color-basic-800"] }]}>{item.name}</Text>
          <Text style={[styles.spaceCount, { color: theme["color-basic-600"] }]}>
            {item.count} {item.count === 1 ? "recording" : "recordings"}
          </Text>
        </View>
        <Ionicons name="chevron-forward" size={18} color={theme["color-basic-500"]} />
      </TouchableOpacity>
    );
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <Pressable style={styles.overlay} onPress={onClose}>
        <Pressable
          style={[styles.sheet, { backgroundColor: theme["color-basic-100"] }]}
          onPress={(e) => e.stopPropagation()}
        >
          <View style={[styles.handle, { backgroundColor: theme["color-basic-400"] }]} />
          <Text category="h6" style={[styles.title, { color: theme["color-basic-800"] }]}>
            Move to Space
          </Text>

          {spaces.length === 0 ? (
            <View style={styles.empty}>
              <Text style={[styles.emptyText, { color: theme["color-basic-600"] }]}>
                No spaces yet. Create one in the Spaces tab.
              </Text>
            </View>
          ) : (
            <FlatList
              data={spaces}
              keyExtractor={(item) => item.id}
              renderItem={renderItem}
              style={styles.list}
              scrollEnabled={spaces.length > 5}
            />
          )}
        </Pressable>
      </Pressable>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.4)",
    justifyContent: "flex-end",
  },
  sheet: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingTop: 12,
    paddingBottom: 40,
    maxHeight: "60%",
  },
  handle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    alignSelf: "center",
    marginBottom: 16,
  },
  title: {
    paddingHorizontal: 20,
    marginBottom: 8,
  },
  list: {
    paddingHorizontal: 20,
  },
  spaceRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 14,
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: 8,
    justifyContent: "center",
    alignItems: "center",
  },
  rowText: {
    flex: 1,
    gap: 2,
  },
  spaceName: {
    fontSize: 15,
    fontWeight: "600",
  },
  spaceCount: {
    fontSize: 12,
  },
  empty: {
    padding: 20,
    alignItems: "center",
  },
  emptyText: {
    fontSize: 14,
    textAlign: "center",
  },
});
