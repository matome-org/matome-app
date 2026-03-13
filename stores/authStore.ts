import { supabase } from '@/config/supabase';
import { User } from '@/processes/types/authTypes';
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
      const { data: { session } } = await supabase.auth.getSession();
      set({ isAuthenticated: !!session, user: session?.user ?? null, isLoading: false });
    } catch (error) {
      console.error('Error checking auth:', error);
      set({ isAuthenticated: false, user: null, isLoading: false });
    }
  },

  signIn: () => {
    set({ isAuthenticated: true });
  },

  signOut: async () => {
    await supabase.auth.signOut();
    set({ isAuthenticated: false, user: null });
  },

  setAuthenticated: (value: boolean) => {
    set({ isAuthenticated: value });
  },
}));
