import { Tabs } from 'expo-router';

import { NavBar } from '@/components/NavBar';

export default function TabLayout() {
  return (
    <Tabs
      tabBar={(props) => <NavBar {...props} />}
      screenOptions={{
        headerShown: false,
      }}
      initialRouteName="inbox"
    >
      <Tabs.Screen
        name="inbox"
        options={{
          title: 'Inbox',
        }}
      />
      <Tabs.Screen
        name="calendar"
        options={{
          title: 'Calendar',
        }}
      />
      <Tabs.Screen
        name="explore"
        options={{
          title: 'Spaces',
        }}
      />
      <Tabs.Screen
        name="satori"
        options={{
          title: 'Satori',
        }}
      />
    </Tabs>
  );
}
