import { Icon, useTheme } from '@ui-kitten/components';
import React, { useState } from 'react';
import { ImageProps, Pressable, Text, View } from 'react-native';

import { RecordingModal } from '../RecordingModal';
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
  const [isRecordingModalVisible, setIsRecordingModalVisible] = useState(false);

  // Filter out routes that should be hidden from tab bar (dynamic routes like [id])
  const visibleRoutes = state.routes.filter((route) => {
    // Filter out dynamic routes (those starting with [) or routes explicitly hidden
    return !route.name.startsWith('[');
  });

  const handleMicPress = () => {
    setIsRecordingModalVisible(true);
  };

  const handleCloseModal = () => {
    setIsRecordingModalVisible(false);
  };

  const handleRecordingComplete = (recordingId: string) => {
    // Recording is saved, modal will close and navigate
    console.log('Recording completed:', recordingId);
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
      {visibleRoutes.map((route, index) => {
        const { options } = descriptors[route.key];
        const labelValue = options.tabBarLabel ?? options.title ?? route.name;
        // Ensure label is a string (not a function)
        const label = typeof labelValue === 'string' ? labelValue : route.name;
        // Find the actual index in the original state.routes array for focus check
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

        // Render microphone button in the center (between index 0 and 1)
        if (index === 1) {
          return (
            <React.Fragment key={route.key}>
              {/* Microphone Button */}
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
                  style={[
                    styles.micIcon,
                    {
                      tintColor: '#ffffff',
                    },
                  ]}
                />
              </Pressable>
              {/* Spaces Tab */}
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
                  style={[
                    styles.tabIcon,
                    {
                      tintColor: isFocused
                        ? theme['color-primary-500']
                        : theme['color-basic-600'],
                    },
                  ]}
                />
                <Text
                  style={[
                    styles.tabLabel,
                    {
                      color: isFocused
                        ? theme['color-primary-500']
                        : theme['color-basic-600'],
                    },
                  ]}
                >
                  {label}
                </Text>
              </Pressable>
            </React.Fragment>
          );
        }

        // Render Inbox tab (index 0)
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
            <InboxIcon
              style={[
                styles.tabIcon,
                {
                  tintColor: isFocused
                    ? theme['color-primary-500']
                    : theme['color-basic-600'],
                },
              ]}
            />
            <Text
              style={[
                styles.tabLabel,
                {
                  color: isFocused
                    ? theme['color-primary-500']
                    : theme['color-basic-600'],
                },
              ]}
            >
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
