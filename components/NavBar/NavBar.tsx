import { Icon, useTheme } from '@ui-kitten/components';
import React, { useState } from 'react';
import { ImageProps, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';

import RecordingModal from '../RecordingModal';
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

export const NavBar = ({ state, descriptors, navigation }: NavBarProps) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const [isRecordingModalVisible, setIsRecordingModalVisible] = useState(false);
  const triggerRefresh = useRecordingsStore((state) => state.triggerRefresh);

  // Filter out routes that should be hidden from tab bar (dynamic routes like [id])
  const visibleRoutes = state.routes.filter((route) => {
    return !route.name.startsWith('[');
  });

  const handleMicPress = () => {
    setIsRecordingModalVisible(true);
  };

  const handleCloseModal = () => {
    setIsRecordingModalVisible(false);
  };

  const handleRecordingComplete = (_recordingId: string) => {
    triggerRefresh();
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
      {visibleRoutes.map((route) => {
        const { options } = descriptors[route.key];
        const labelValue = options.tabBarLabel ?? options.title ?? route.name;
        const label = typeof labelValue === 'string' ? labelValue : route.name;

        const actualIndex = state.routes.findIndex((r) => r.key === route.key);
        const isFocused = state.index === actualIndex;

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

        const tabColor = isFocused
          ? theme['color-primary-500']
          : theme['color-basic-600'];

        // Inbox tab — always index 0 in our route order
        if (route.name === 'inbox') {
          return (
            <React.Fragment key={route.key}>
              <Pressable
                accessibilityRole="button"
                accessibilityState={isFocused ? { selected: true } : {}}
                accessibilityLabel={options.tabBarAccessibilityLabel}
                onPress={onPress}
                onLongPress={onLongPress}
                style={styles.tabItem}
              >
                <InboxIcon
                  style={[styles.tabIcon, { tintColor: tabColor }]}
                />
                <Text style={[styles.tabLabel, { color: tabColor }]}>
                  {label}
                </Text>
              </Pressable>

              {/* Mic button injected immediately after the Inbox tab */}
              <Pressable
                style={[
                  styles.micButton,
                  {
                    backgroundColor: theme['color-primary-500'],
                    borderColor: theme['color-basic-100'],
                  },
                ]}
                onPress={handleMicPress}
              >
                <MicIcon
                  style={[styles.micIcon, { tintColor: '#ffffff' }]}
                />
              </Pressable>
            </React.Fragment>
          );
        }

        // Calendar tab
        if (route.name === 'calendar') {
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
              <Ionicons
                name="calendar-outline"
                size={24}
                color={tabColor}
              />
              <Text style={[styles.tabLabel, { color: tabColor }]}>
                {t('calendar.title')}
              </Text>
            </Pressable>
          );
        }

        // Spaces / explore tab (and any other future tab)
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
            <SpacesIcon
              style={[styles.tabIcon, { tintColor: tabColor }]}
            />
            <Text style={[styles.tabLabel, { color: tabColor }]}>
              {label}
            </Text>
          </Pressable>
        );
      })}

      <RecordingModal
        visible={isRecordingModalVisible}
        onClose={handleCloseModal}
        onRecordingComplete={handleRecordingComplete}
      />
    </View>
  );
};
