import { Icon, useTheme } from '@ui-kitten/components';
import React from 'react';
import { ImageProps, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';
import { useRouter } from 'expo-router';

import { useRecordingsStore } from '@/stores/recordingsStore';
import { NavBarProps } from './NavBar.types';
import { styles } from './NavBar.styles';

const InboxIcon = (props: Partial<ImageProps>) => (
  <Icon {...props} name="inbox-outline" />
);

const SpacesIcon = (props: Partial<ImageProps>) => (
  <Icon {...props} name="folder-outline" />
);

const MicIcon = (props: Partial<ImageProps>) => (
  <Icon {...props} name="mic-outline" />
);

const SatoriIcon = (props: Partial<ImageProps>) => (
  <Icon {...props} name="bulb-outline" />
);

// ---------------------------------------------------------------------------
// Tab config — drives the 5-slot layout: Inbox | Calendar | [Mic] | Spaces | Satori
// The mic FAB is the center slot and is NOT a real route.
// ---------------------------------------------------------------------------
interface TabConfig {
  routeName: string;
  labelKey: string;
  renderIcon: (color: string) => React.ReactNode;
}

const TAB_CONFIGS: TabConfig[] = [
  {
    routeName: 'inbox',
    labelKey: 'inbox.title',
    renderIcon: (color) => (
      <InboxIcon style={[styles.tabIcon, { tintColor: color }]} />
    ),
  },
  {
    routeName: 'calendar',
    labelKey: 'calendar.title',
    renderIcon: (color) => (
      <Ionicons name="calendar-outline" size={24} color={color} />
    ),
  },
  {
    routeName: 'explore',
    labelKey: 'spaces.title',
    renderIcon: (color) => (
      <SpacesIcon style={[styles.tabIcon, { tintColor: color }]} />
    ),
  },
  {
    routeName: 'satori',
    labelKey: 'satori.title',
    renderIcon: (color) => (
      <SatoriIcon style={[styles.tabIcon, { tintColor: color }]} />
    ),
  },
];

export const NavBar = ({ state, descriptors, navigation }: NavBarProps) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const router = useRouter();
  const triggerRefresh = useRecordingsStore((s) => s.triggerRefresh);

  const handleMicPress = () => {
    router.push('/recording');
  };

  // Build the 5-slot layout: [tab, tab, MicFAB, tab, tab]
  // Slots 0-1 come from the first two TAB_CONFIGS, slot 2 is the mic FAB,
  // slots 3-4 come from the remaining TAB_CONFIGS.
  const leftTabs = TAB_CONFIGS.slice(0, 2);
  const rightTabs = TAB_CONFIGS.slice(2);

  const renderTabItem = (config: TabConfig) => {
    const route = state.routes.find((r) => r.name === config.routeName);
    if (!route) return null;

    const { options } = descriptors[route.key];
    const actualIndex = state.routes.findIndex((r) => r.key === route.key);
    const isFocused = state.index === actualIndex;

    const tabColor = isFocused
      ? theme['color-primary-500']
      : theme['color-basic-600'];

    const onPress = () => {
      const event = navigation.emit({
        type: 'tabPress',
        target: route.key,
        canPreventDefault: true,
      });

      if (!isFocused && !event.defaultPrevented) {
        navigation.navigate(route.name);
      }
    };

    const onLongPress = () => {
      navigation.emit({
        type: 'tabLongPress',
        target: route.key,
      });
    };

    return (
      <Pressable
        key={route.key}
        accessibilityRole="button"
        accessibilityState={isFocused ? { selected: true } : {}}
        accessibilityLabel={options.tabBarAccessibilityLabel}
        onPress={onPress}
        onLongPress={onLongPress}
        style={styles.tabItem}
      >
        {config.renderIcon(tabColor)}
        <Text style={[styles.tabLabel, { color: tabColor }]}>
          {t(config.labelKey as any)}
        </Text>
      </Pressable>
    );
  };

  return (
    <View
      style={[
        styles.tabBar,
        {
          backgroundColor: theme['color-basic-100'],
          borderTopColor: theme['color-basic-500'],
        },
      ]}
    >
      {/* Left tabs: Inbox + Calendar */}
      {leftTabs.map(renderTabItem)}

      {/* Center Mic FAB — not a real tab */}
      <Pressable
        style={[
          styles.micButton,
          {
            backgroundColor: theme['color-primary-500'],
            borderColor: theme['color-basic-100'],
          },
        ]}
        onPress={handleMicPress}
        accessibilityRole="button"
        accessibilityLabel="Record"
      >
        <MicIcon style={[styles.micIcon, { tintColor: '#ffffff' }]} />
      </Pressable>

      {/* Right tabs: Spaces + Satori */}
      {rightTabs.map(renderTabItem)}
    </View>
  );
};
