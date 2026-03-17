import { writable, get } from 'svelte/store';

export interface AppWindow {
  id: string;
  title: string;
  minimized: boolean;
  maximized: boolean;
  x: number;
  y: number;
  width: number;
  height: number;
  zIndex: number;
}

let nextZ = 10;

function createWindowStore() {
  const { subscribe, update, set } = writable<AppWindow[]>([]);

  return {
    subscribe,

    open(id: string, title: string) {
      update(wins => {
        const existing = wins.find(w => w.id === id);
        if (existing) {
          // If already open, bring to front and un-minimize
          return wins.map(w =>
            w.id === id ? { ...w, minimized: false, zIndex: ++nextZ } : w
          );
        }
        // Offset new windows so they don't stack exactly
        const offset = (wins.length % 6) * 30;
        const newWin: AppWindow = {
          id,
          title,
          minimized: false,
          maximized: false,
          x: 40 + offset,
          y: 40 + offset,
          width: 700,
          height: 450,
          zIndex: ++nextZ,
        };
        return [...wins, newWin];
      });
    },

    close(id: string) {
      update(wins => wins.filter(w => w.id !== id));
    },

    minimize(id: string) {
      update(wins =>
        wins.map(w => (w.id === id ? { ...w, minimized: true } : w))
      );
    },

    maximize(id: string) {
      update(wins =>
        wins.map(w =>
          w.id === id ? { ...w, maximized: !w.maximized, zIndex: ++nextZ } : w
        )
      );
    },

    focus(id: string) {
      update(wins =>
        wins.map(w => (w.id === id ? { ...w, zIndex: ++nextZ } : w))
      );
    },

    move(id: string, x: number, y: number) {
      update(wins =>
        wins.map(w => (w.id === id ? { ...w, x, y } : w))
      );
    },

    resize(id: string, width: number, height: number) {
      update(wins =>
        wins.map(w => (w.id === id ? { ...w, width, height } : w))
      );
    },
  };
}

export const windowStore = createWindowStore();
