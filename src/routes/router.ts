import page from 'page';
import { interfaceStore } from '../stores/interfaceStore';
import type { InterfaceMode } from './routes';
import { getModeFromUrl, getUrlFromMode } from './routes';
import { canAccessRoute } from './routeGuards';

let isRouterInitialized = false;
let isHandlingRoute = false;

/**
 * Initialize the router
 */
export function initRouter(): void {
  if (isRouterInitialized) return;

  // Subscribe to interface changes and update URL (but not during route handling to avoid conflicts)
  interfaceStore.subscribe((state) => {
    if (isHandlingRoute) return; // Skip during route handling
    const url = getUrlFromMode(state.currentInterface);
    if (typeof window !== 'undefined' && window.location.pathname !== url) {
      // Update URL without triggering handler again
      window.history.pushState({}, '', url);
    }
  });

  // Define route handlers
  const createRouteHandler = (mode: InterfaceMode, requiresAuth: boolean = false) => (ctx: any) => {
    isHandlingRoute = true;
    try {
      if (canAccessRoute(mode)) {
        interfaceStore.setInterface(mode);
      } else {
        page.redirect('/');
      }
    } catch (err) {
      console.error('Router error:', err);
      interfaceStore.setInterface('login');
    } finally {
      isHandlingRoute = false;
    }
  };

  page('/', createRouteHandler('login'));
  page('/signup', createRouteHandler('signup'));
  page('/mobile', createRouteHandler('mobile', true));
  page('/desktop', createRouteHandler('desktop', true));
  page('/privacy-policy', createRouteHandler('privacy'));
  page('/my-jobs', createRouteHandler('my-jobs', true));
  page('/attendance', createRouteHandler('attendance', true));

  // Fallback - redirect to login with error handling
  page('*', (ctx: any) => {
    try {
      page.redirect('/');
    } catch (err) {
      console.error('Router fallback error:', err);
    }
  });

  // Start the router
  page.start();
  isRouterInitialized = true;
}

/**
 * Navigate to a URL
 */
export function navigateToUrl(url: string): void {
  page.show(url);
}

/**
 * Navigate by interface mode
 */
export function navigateToMode(mode: InterfaceMode): void {
  const url = getUrlFromMode(mode);
  navigateToUrl(url);
}

/**
 * Get current URL
 */
export function getCurrentUrl(): string {
  return typeof window !== 'undefined' ? window.location.pathname : '/';
}

/**
 * Get current mode from URL
 */
export function getCurrentMode(): InterfaceMode | undefined {
  return getModeFromUrl(getCurrentUrl());
}
