import { Icon, useTheme } from '@ui-kitten/components';
import { Tabs } from 'expo-router';
import React from 'react';
import { ImageProps } from 'react-native';

const InboxIcon = (props: Partial<ImageProps>) => (
  <Icon {...props} name="inbox-outline" />
);

const SpacesIcon = (props: Partial<ImageProps>) => (
  <Icon {...props} name="folder-outline" />
);

export default function TabLayout() {
  const theme = useTheme();

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: theme['color-basic-100'],
          borderTopColor: theme['color-basic-500'],
          borderTopWidth: 1,
          height: 84,
          paddingBottom: 20,
        },
        tabBarActiveTintColor: theme['color-primary-500'],
        tabBarInactiveTintColor: theme['color-basic-600'],
        tabBarLabelStyle: {
          fontSize: 10,
          fontWeight: '500',
          marginTop: 4,
        },
        tabBarIconStyle: {
          marginTop: 0,
        },
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'Inbox',
          tabBarIcon: ({ color, size, focused }) => (
            <InboxIcon
              style={{
                width: size,
                height: size,
                tintColor: focused
                  ? theme['color-primary-500']
                  : theme['color-basic-600'],
              }}
            />
          ),
        }}
      />
      <Tabs.Screen
        name="explore"
        options={{
          title: 'Spaces',
          tabBarIcon: ({ color, size, focused }) => (
            <SpacesIcon
              style={{
                width: size,
                height: size,
                tintColor: focused
                  ? theme['color-primary-500']
                  : theme['color-basic-600'],
              }}
            />
          ),
        }}
      />
      <Tabs.Screen
        name="[id]"
        options={{
          href: null, // Hide from tab bar
        }}
      />
    </Tabs>
  );
}
