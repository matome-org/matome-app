import { Stack } from 'expo-router';

export default function SpacesStackLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
      }}
    >
      <Stack.Screen
        name="explore"
        options={{
          title: 'Spaces',
        }}
      />
    </Stack>
  );
}
