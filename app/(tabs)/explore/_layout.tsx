import { Stack } from 'expo-router';
import { useEffectiveTheme } from '@/stores/themeStore';

const BACKGROUND_COLORS = { light: '#fdfdfd', dark: '#333333' };

export default function SpacesStackLayout() {
  const effectiveTheme = useEffectiveTheme();
  const backgroundColor = BACKGROUND_COLORS[effectiveTheme];

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor },
      }}
    >
      <Stack.Screen name="explore" options={{ title: 'Spaces' }} />
      <Stack.Screen name="[spaceId]" />
      <Stack.Screen name="recording/[id]" />
    </Stack>
  );
}
