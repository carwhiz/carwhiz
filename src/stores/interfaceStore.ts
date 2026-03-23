import { writable } from 'svelte/store';

export type InterfaceMode = 'login' | 'signup' | 'mobile' | 'desktop' | 'privacy' | 'my-jobs' | 'attendance';

interface InterfaceState {
  currentInterface: InterfaceMode;
}

function createInterfaceStore() {
  const stored = typeof localStorage !== 'undefined' ? localStorage.getItem('carwhizz_interface') as InterfaceMode : null;
  const initialInterface: InterfaceMode = stored || 'login';
  
  const { subscribe, set, update } = writable<InterfaceState>({
    currentInterface: initialInterface
  });

  return {
    subscribe,
    
    setInterface: (mode: InterfaceMode) => {
      localStorage.setItem('carwhizz_interface', mode);
      update(state => ({
        ...state,
        currentInterface: mode
      }));
    },

    toggle: () => update(state => {
      const next = state.currentInterface === 'mobile' ? 'desktop' : 'mobile';
      localStorage.setItem('carwhizz_interface', next);
      return {
        ...state,
        currentInterface: next as InterfaceMode
      };
    }),

    goHome: () => {
      update(state => ({
        ...state,
        currentInterface: state.currentInterface === 'mobile' ? 'mobile' : 'desktop'
      }));
    },

    logout: () => {
      localStorage.removeItem('carwhizz_interface');
      set({
        currentInterface: 'login'
      });
    }
  };
}

export const interfaceStore = createInterfaceStore();
