import { writable } from 'svelte/store';

export type InterfaceMode = 'mobile' | 'desktop';

function createInterfaceStore() {
  const stored = typeof localStorage !== 'undefined' ? localStorage.getItem('carwhizz_interface') as InterfaceMode : null;
  const { subscribe, set, update } = writable<InterfaceMode>(stored || 'mobile');

  return {
    subscribe,
    toggle: () => update(mode => {
      const next = mode === 'mobile' ? 'desktop' : 'mobile';
      localStorage.setItem('carwhizz_interface', next);
      return next;
    }),
    set: (mode: InterfaceMode) => {
      localStorage.setItem('carwhizz_interface', mode);
      set(mode);
    },
  };
}

export const interfaceStore = createInterfaceStore();
