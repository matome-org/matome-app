import { Stack } from 'expo-router';

export default function InboxStackLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
      }}
    >
      <Stack.Screen
        name="inbox"
        options={{
          title: 'Inbox',
        }}
      />
      <Stack.Screen
        name="[id]"
        options={{
          title: 'Details',
        }}
      />
    </Stack>
  );
}
