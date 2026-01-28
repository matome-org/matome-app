import { getToken, removeToken, saveToken } from '@/utils/storage';
import { create } from 'zustand';

interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  checkAuth: () => Promise<void>;
  signIn: (token: string) => Promise<void>;
  signOut: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  isAuthenticated: false,
  isLoading: true,

  checkAuth: async () => {
    try {
      const token = await getToken();
      set({ isAuthenticated: !!token, isLoading: false });
    } catch (error) {
      console.error('Error checking auth:', error);
      set({ isAuthenticated: false, isLoading: false });
    }
  },

  signIn: async (token: string) => {
    await saveToken(token);
    set({ isAuthenticated: true });
  },

  signOut: async () => {
    await removeToken();
    set({ isAuthenticated: false });
  },
}));
