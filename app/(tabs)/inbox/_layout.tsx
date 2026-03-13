import { Stack } from 'expo-router';
import { useEffectiveTheme } from '@/stores/themeStore';

const BACKGROUND_COLORS = { light: '#fdfdfd', dark: '#333333' };

export default function InboxStackLayout() {
  const effectiveTheme = useEffectiveTheme();
  const backgroundColor = BACKGROUND_COLORS[effectiveTheme];

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor },
      }}
    >
      <Stack.Screen name="index" options={{ title: 'Inbox' }} />
      <Stack.Screen name="[id]" options={{ title: 'Details' }} />
      <Stack.Screen name="settings" options={{ title: 'Settings' }} />
    </Stack>
  );
}
