import { User } from '@/processes/types/authTypes';
import { coreApiClient } from '@/services/coreApiClient';
import { getRefreshToken, removeRefreshToken, removeToken } from '@/utils/storage';
import { create } from 'zustand';

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: User | null;
  checkAuth: () => Promise<void>;
  signIn: () => void;
  signOut: () => Promise<void>;
  setAuthenticated: (value: boolean) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  isAuthenticated: false,
  isLoading: true,
  user: null,

  checkAuth: async () => {
    try {
      const { user } = await coreApiClient.me();
      set({ isAuthenticated: true, user, isLoading: false });
    } catch (error) {
      console.error('Error checking auth:', error);
      set({ isAuthenticated: false, user: null, isLoading: false });
    }
  },

  signIn: () => {
    set({ isAuthenticated: true });
  },

  signOut: async () => {
    const refreshToken = await getRefreshToken();
    if (refreshToken) {
      await coreApiClient.logout({ refresh_token: refreshToken }).catch(() => undefined);
    }
    await Promise.all([removeToken(), removeRefreshToken()]);
    set({ isAuthenticated: false, user: null });
  },

  setAuthenticated: (value: boolean) => {
    set({ isAuthenticated: value });
  },
}));
