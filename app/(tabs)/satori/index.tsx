import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Layout, Text, useTheme } from '@ui-kitten/components';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';

import { AppHeader } from '@/components/AppHeader';

export default function SatoriScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { t } = useTranslation();

  return (
    <Layout
      style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}
    >
      <AppHeader title={t('satori.title')} />

      <View
        style={[
          styles.body,
          { paddingBottom: insets.bottom + 16 },
        ]}
      >
        <View
          style={[
            styles.iconWrapper,
            { backgroundColor: theme['color-primary-500'] + '20' },
          ]}
        >
          <Ionicons
            name="construct-outline"
            size={48}
            color={theme['color-primary-500']}
          />
        </View>

        <Text
          category="h5"
          style={[styles.heading, { color: theme['color-basic-800'] }]}
        >
          {t('satori.comingSoon')}
        </Text>

        <Text
          category="p1"
          style={[styles.hint, { color: theme['color-basic-600'] }]}
        >
          {t('satori.comingSoonHint')}
        </Text>
      </View>
    </Layout>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  body: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    gap: 16,
  },
  iconWrapper: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  heading: {
    fontWeight: '700',
    textAlign: 'center',
  },
  hint: {
    textAlign: 'center',
    lineHeight: 22,
  },
});
