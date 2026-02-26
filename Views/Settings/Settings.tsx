import React from "react";
import { ScrollView, StyleSheet, TouchableOpacity, View } from "react-native";
import { Layout, Text, useTheme } from "@ui-kitten/components";
import { Ionicons } from "@expo/vector-icons";
import { useTranslation } from "react-i18next";

import { AppHeader } from "@/components/AppHeader";
import { ThemeMode } from "@/stores/themeStore";
import { Language } from "@/stores/languageStore";
import { SettingsProps } from "./Settings.types";

export const Settings: React.FC<SettingsProps> = ({
  themeMode,
  onThemeChange,
  language,
  onLanguageChange,
  onBack,
  onSignOut,
}) => {
  const theme = useTheme();
  const { t } = useTranslation();

  const THEME_OPTIONS: { mode: ThemeMode; label: string; icon: string }[] = [
    { mode: "light", label: t("settings.themeLight"), icon: "sunny-outline" },
    { mode: "dark", label: t("settings.themeDark"), icon: "moon-outline" },
    { mode: "system", label: t("settings.themeSystem"), icon: "phone-portrait-outline" },
  ];

  const LANGUAGE_OPTIONS: { lang: Language; label: string }[] = [
    { lang: "en", label: t("settings.langEn") },
    { lang: "ja", label: t("settings.langJa") },
  ];

  return (
    <Layout style={[styles.container, { backgroundColor: theme["color-basic-200"] }]}>
      <AppHeader title={t("settings.title")} onBack={onBack} borderBottom />

      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {/* Appearance */}
        <Text style={[styles.sectionLabel, { color: theme["color-basic-600"] }]}>
          {t("settings.appearance")}
        </Text>
        <View style={[styles.card, { backgroundColor: theme["color-basic-100"], borderColor: theme["color-basic-300"] }]}>
          {/* Theme */}
          <Text style={[styles.rowLabel, { color: theme["color-basic-800"] }]}>
            {t("settings.theme")}
          </Text>
          <View style={styles.optionRow}>
            {THEME_OPTIONS.map((option) => {
              const active = themeMode === option.mode;
              return (
                <TouchableOpacity
                  key={option.mode}
                  style={[
                    styles.optionPill,
                    {
                      backgroundColor: active
                        ? theme["color-primary-500"]
                        : theme["color-basic-300"],
                      borderColor: active
                        ? theme["color-primary-500"]
                        : theme["color-basic-400"],
                    },
                  ]}
                  onPress={() => onThemeChange(option.mode)}
                >
                  <Ionicons
                    name={option.icon as never}
                    size={18}
                    color={active ? theme["color-primary-900"] : theme["color-basic-600"]}
                  />
                  <Text
                    style={[
                      styles.optionLabel,
                      {
                        color: active
                          ? theme["color-primary-900"]
                          : theme["color-basic-600"],
                        fontWeight: active ? "700" : "400",
                      },
                    ]}
                  >
                    {option.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>

          {/* Language */}
          <Text style={[styles.rowLabel, { color: theme["color-basic-800"] }]}>
            {t("settings.language")}
          </Text>
          <View style={styles.optionRow}>
            {LANGUAGE_OPTIONS.map((option) => {
              const active = language === option.lang;
              return (
                <TouchableOpacity
                  key={option.lang}
                  style={[
                    styles.optionPill,
                    {
                      backgroundColor: active
                        ? theme["color-primary-500"]
                        : theme["color-basic-300"],
                      borderColor: active
                        ? theme["color-primary-500"]
                        : theme["color-basic-400"],
                    },
                  ]}
                  onPress={() => onLanguageChange(option.lang)}
                >
                  <Text
                    style={[
                      styles.optionLabel,
                      {
                        color: active
                          ? theme["color-primary-900"]
                          : theme["color-basic-600"],
                        fontWeight: active ? "700" : "400",
                      },
                    ]}
                  >
                    {option.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        {/* Account */}
        <Text style={[styles.sectionLabel, { color: theme["color-basic-600"] }]}>
          {t("settings.account")}
        </Text>
        <View style={[styles.card, { backgroundColor: theme["color-basic-100"], borderColor: theme["color-basic-300"] }]}>
          <TouchableOpacity style={styles.row} onPress={onSignOut}>
            <Ionicons name="log-out-outline" size={20} color={theme["color-danger-500"]} />
            <Text style={[styles.rowLabel, { color: theme["color-danger-500"] }]}>
              {t("settings.signOut")}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </Layout>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 24,
  },
  sectionLabel: {
    fontSize: 12,
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: 0.8,
    marginBottom: 8,
    marginLeft: 4,
  },
  card: {
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginBottom: 24,
    gap: 14,
  },
  rowLabel: {
    fontSize: 15,
    fontWeight: "500",
  },
  optionRow: {
    flexDirection: "row",
    gap: 8,
  },
  optionPill: {
    flex: 1,
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    borderRadius: 10,
    borderWidth: 1,
    paddingVertical: 12,
  },
  optionLabel: {
    fontSize: 12,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
});
