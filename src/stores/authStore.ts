import { writable } from 'svelte/store';
import type { AuthState, User } from '../types/auth';

const initialState: AuthState = {
  user: null,
  loading: true,
  error: null,
  isAuthenticated: false,
};

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>(initialState);

  return {
    subscribe,
    setUser: (user: User | null) =>
      update((state) => ({
        ...state,
        user,
        isAuthenticated: !!user,
        loading: false,
      })),
    setLoading: (loading: boolean) =>
      update((state) => ({ ...state, loading })),
    setError: (error: string | null) =>
      update((state) => ({ ...state, error })),
    logout: () =>
      set({
        user: null,
        loading: false,
        error: null,
        isAuthenticated: false,
      }),
    reset: () => set(initialState),
  };
}

export const authStore = createAuthStore();
