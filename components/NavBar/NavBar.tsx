import { Icon, useTheme } from '@ui-kitten/components';
import React from 'react';
import { ImageProps, Pressable, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';
import { router } from 'expo-router';

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

  const visibleRoutes = state.routes.filter((route) => {
    return !route.name.startsWith('[');
  });

  const handleMicPress = () => {
    router.push('/recording');
  };

  const renderTab = (route: (typeof visibleRoutes)[0]) => {
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

    if (route.name === 'inbox') {
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
          <InboxIcon style={[styles.tabIcon, { tintColor: tabColor }]} />
          <Text style={[styles.tabLabel, { color: tabColor }]}>{label}</Text>
        </Pressable>
      );
    }

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
          <Ionicons name="calendar-outline" size={24} color={tabColor} />
          <Text style={[styles.tabLabel, { color: tabColor }]}>
            {t('calendar.title')}
          </Text>
        </Pressable>
      );
    }

    if (route.name === 'explore') {
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
          <SpacesIcon style={[styles.tabIcon, { tintColor: tabColor }]} />
          <Text style={[styles.tabLabel, { color: tabColor }]}>{label}</Text>
        </Pressable>
      );
    }

    if (route.name === 'satori') {
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
          <Ionicons name="sparkles-outline" size={24} color={tabColor} />
          <Text style={[styles.tabLabel, { color: tabColor }]}>Satori</Text>
        </Pressable>
      );
    }

    // Fallback for any unknown tab
    return (
      <Pressable
        key={route.key}
        accessibilityRole="button"
        accessibilityState={isFocused ? { selected: true } : {}}
        onPress={onPress}
        onLongPress={onLongPress}
        style={styles.tabItem}
      >
        <SpacesIcon style={[styles.tabIcon, { tintColor: tabColor }]} />
        <Text style={[styles.tabLabel, { color: tabColor }]}>{label}</Text>
      </Pressable>
    );
  };

  // Split routes: left of mic (inbox, calendar) and right of mic (explore, satori)
  const leftRoutes = visibleRoutes.filter((r) =>
    ['inbox', 'calendar'].includes(r.name)
  );
  const rightRoutes = visibleRoutes.filter((r) =>
    ['explore', 'satori'].includes(r.name)
  );

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
      {leftRoutes.map(renderTab)}

      {/* Center mic button */}
      <View style={styles.micWrapper}>
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
          <MicIcon style={[styles.micIcon, { tintColor: '#ffffff' }]} />
        </Pressable>
      </View>

      {rightRoutes.map(renderTab)}
    </View>
  );
};
