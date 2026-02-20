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

import { supabase } from '@/config/supabase';
import { darkTheme, lightTheme } from '@/config/themes';
import { useAuthStore } from '@/stores/authStore';
import { useEffectiveTheme } from '@/stores/themeStore';

const BACKGROUND_COLORS = { light: '#fdfdfd', dark: '#333333' };

export const unstable_settings = {
  initialRouteName: 'index',
};

SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient();

const RootLayoutNav = () => {
  const { isAuthenticated, isLoading, checkAuth, setAuthenticated } = useAuthStore();
  const router = useRouter();
  const segments = useSegments();
  const effectiveTheme = useEffectiveTheme();
  const backgroundColor = BACKGROUND_COLORS[effectiveTheme];

  useEffect(() => {
    checkAuth();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthenticated(!!session);
    });

    return () => subscription.unsubscribe();
  }, [checkAuth, setAuthenticated]);

  useEffect(() => {
    if (isLoading) return;

    SplashScreen.hideAsync();

    const inTabsGroup = segments[0] === '(tabs)';

    if (isAuthenticated && !inTabsGroup) {
      router.replace('/(tabs)/explore/explore');
    } else if (!isAuthenticated && inTabsGroup) {
      router.replace('/');
    }
  }, [isAuthenticated, isLoading, segments, router]);

  if (isLoading) {
    return (
      <View style={{ alignItems: 'center', justifyContent: 'center', flex: 1 }}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <Stack
      initialRouteName="index"
      screenOptions={{ headerShown: false, contentStyle: { backgroundColor } }}
    >
      <Stack.Screen name="index" />
      <Stack.Screen name="login" />
      <Stack.Screen name="signup" />
      <Stack.Screen name="(tabs)" />
    </Stack>
  );
};

const RootLayout = () => {
  const effectiveTheme = useEffectiveTheme();
  const theme = effectiveTheme === 'dark' ? darkTheme : lightTheme;

  return (
    <>
      <IconRegistry icons={EvaIconsPack} />
      <ApplicationProvider mapping={eva.mapping} theme={theme}>
        <QueryClientProvider client={queryClient}>
          <RootLayoutNav />
          <StatusBar style={effectiveTheme === 'dark' ? 'light' : 'dark'} />
          <ToastContainer bottomOffset={130} position="bottom" />
        </QueryClientProvider>
      </ApplicationProvider>
    </>
  );
};

export default RootLayout;
