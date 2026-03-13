import React from "react";
import { StyleSheet, TouchableOpacity, View } from "react-native";
import { Text, useTheme } from "@ui-kitten/components";
import { Ionicons } from "@expo/vector-icons";
import { useSafeAreaInsets } from "react-native-safe-area-context";

export interface AppHeaderIconButtonProps {
  icon: string;
  onPress?: () => void;
  /** outlined: bordered background (list screens). ghost: transparent + primary color (detail screens). */
  variant?: "outlined" | "ghost";
  size?: number;
}

export const AppHeaderIconButton: React.FC<AppHeaderIconButtonProps> = ({
  icon,
  onPress,
  variant = "outlined",
  size = 20,
}) => {
  const theme = useTheme();

  return (
    <TouchableOpacity
      onPress={onPress}
      style={[
        styles.iconButton,
        variant === "outlined"
          ? {
              backgroundColor: theme["color-basic-100"],
              borderColor: theme["color-basic-500"],
              borderWidth: 1,
            }
          : { backgroundColor: "transparent" },
      ]}
    >
      <Ionicons
        name={icon as never}
        size={size}
        color={
          variant === "outlined"
            ? theme["color-basic-700"]
            : theme["color-primary-500"]
        }
      />
    </TouchableOpacity>
  );
};

export interface AppHeaderProps {
  title: string;
  /** When provided, shows a chevron-back button and uses a smaller title style. */
  onBack?: () => void;
  rightActions?: React.ReactNode;
  /** Adds a bottom border — used on detail screens. */
  borderBottom?: boolean;
}

export const AppHeader: React.FC<AppHeaderProps> = ({
  title,
  onBack,
  rightActions,
  borderBottom = false,
}) => {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const isDetail = !!onBack;

  return (
    <View
      style={[
        styles.header,
        {
          backgroundColor: theme["color-basic-200"],
          paddingTop: insets.top + 16,
        },
        borderBottom && {
          borderBottomWidth: 1,
          borderBottomColor: theme["color-basic-500"],
        },
      ]}
    >
      <View style={[styles.left, isDetail && styles.leftDetail]}>
        {isDetail && (
          <TouchableOpacity
            onPress={onBack}
            style={[styles.iconButton, { backgroundColor: "transparent" }]}
          >
            <Ionicons name="chevron-back" size={24} color={theme["color-primary-500"]} />
          </TouchableOpacity>
        )}
        <Text
          category={isDetail ? "s1" : "h4"}
          style={[
            isDetail ? styles.titleDetail : styles.titleLarge,
            { color: theme["color-basic-800"] },
          ]}
          numberOfLines={1}
        >
          {title}
        </Text>
      </View>

      {rightActions && <View style={styles.right}>{rightActions}</View>}
    </View>
  );
};

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: 20,
    paddingBottom: 16,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  left: {
    flex: 1,
  },
  leftDetail: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  titleLarge: {
    fontSize: 24,
    fontWeight: "700",
    maxWidth: "80%",
  },
  titleDetail: {
    fontSize: 17,
    fontWeight: "600",
    flex: 1,
  },
  right: {
    flexDirection: "row",
    gap: 8,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: "center",
    alignItems: "center",
  },
});
