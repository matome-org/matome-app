import '@/config/i18n';
import * as eva from '@eva-design/eva';
import { ApplicationProvider, IconRegistry } from '@ui-kitten/components';
import { EvaIconsPack } from '@ui-kitten/eva-icons';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Stack, useRouter, useSegments } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { ActivityIndicator, View } from 'react-native';
import 'react-native-reanimated';
import ToastContainer from 'react-native-toast-message';

import { decideRedirect } from '@/app/navigationGuard';
import { darkTheme, lightTheme } from '@/config/themes';
import { runUpdateFlow } from '@/services/updateService';
import { loadDraft } from '@/services/draftRecordingService';
import { useAuthStore } from '@/stores/authStore';
import { useEffectiveTheme } from '@/stores/themeStore';

const BACKGROUND_COLORS = { light: '#fdfdfd', dark: '#333333' };

export const unstable_settings = { initialRouteName: 'index' };

SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient();

// Handles auth redirects — lives inside navigation context
const NavigationGuard = () => {
  const { isAuthenticated, isLoading, checkAuth } = useAuthStore();
  const router = useRouter();
  const segments = useSegments();

  useEffect(() => {
    checkAuth();
    runUpdateFlow();
  }, [checkAuth]);

  useEffect(() => {
    if (isLoading) return;

    SplashScreen.hideAsync();

    const target = decideRedirect({ isAuthenticated, isLoading, segments });
    if (target) {
      router.replace(target);
    }
  }, [isAuthenticated, isLoading, segments, router]);

  // After auth is resolved and the user is in the tabs group, check for an
  // in-progress recording draft and route to the recording screen so they can
  // resume or discard it.
  useEffect(() => {
    if (isLoading || !isAuthenticated) return;

    const checkForDraft = async () => {
      try {
        const draft = await loadDraft();
        if (draft && draft.segments.length > 0) {
          router.push('/recording?hasDraft=1');
        }
      } catch (error) {
        console.error('NavigationGuard: Failed to check for recording draft', error);
      }
    };

    checkForDraft();
  // We intentionally run this only once after auth resolves, not on every
  // re-render. The draft check is a one-shot startup concern.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated, isLoading]);

  if (isLoading) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return null;
};

// Handles theme + background — lives inside navigation context
const ThemedStack = () => {
  const effectiveTheme = useEffectiveTheme();
  const backgroundColor = BACKGROUND_COLORS[effectiveTheme];

  return (
    <Stack
      initialRouteName="index"
      screenOptions={{ headerShown: false, contentStyle: { backgroundColor } }}
    >
      <Stack.Screen name="index" />
      <Stack.Screen name="login" />
      <Stack.Screen name="signup" />
      <Stack.Screen name="(tabs)" />
      <Stack.Screen
        name="recording"
        options={{
          presentation: 'fullScreenModal',
          animation: 'slide_from_bottom',
        }}
      />
    </Stack>
  );
};

// Root layout — NO custom hooks here at all
const RootLayout = () => {
  const effectiveTheme = useEffectiveTheme(); // ⚠️ still needed for ApplicationProvider
  const theme = effectiveTheme === 'dark' ? darkTheme : lightTheme;

  return (
    <>
      <IconRegistry icons={EvaIconsPack} />
      <ApplicationProvider mapping={eva.mapping} theme={theme}>
        <QueryClientProvider client={queryClient}>
          <ThemedStack />
          <NavigationGuard />
          <StatusBar style={effectiveTheme === 'dark' ? 'light' : 'dark'} />
          <ToastContainer bottomOffset={130} position="bottom" />
        </QueryClientProvider>
      </ApplicationProvider>
    </>
  );
};

export default RootLayout;
