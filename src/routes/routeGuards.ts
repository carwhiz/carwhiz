import { authStore } from '../stores/authStore';
import { get } from 'svelte/store';
import type { InterfaceMode } from './routes';
import { requiresAuth } from './routes';

/**
 * Check if user is authenticated
 */
export function isAuthenticated(): boolean {
  const auth = get(authStore);
  return !!auth.user;
}

/**
 * Guard function - check if route can be accessed
 */
export function canAccessRoute(routePath: InterfaceMode): boolean {
  const isAuthRequired = requiresAuth(routePath);
  const isUserAuthenticated = isAuthenticated();

  // If route doesn't require auth, always allow
  if (!isAuthRequired) {
    return true;
  }

  // If route requires auth but user not logged in, deny
  if (isAuthRequired && !isUserAuthenticated) {
    return false;
  }

  return true;
}

/**
 * Get the redirect path based on authentication status
 */
export function getRedirectPath(): InterfaceMode {
  if (isAuthenticated()) {
    // Redirect authenticated users to desktop
    return 'desktop';
  } else {
    // Redirect unauthenticated users to login
    return 'login';
  }
}

/**
 * Check if route is public (no auth required)
 */
export function isPublicRoute(routePath: InterfaceMode): boolean {
  return !requiresAuth(routePath);
}

/**
 * Check if route is protected (auth required)
 */
export function isProtectedRoute(routePath: InterfaceMode): boolean {
  return requiresAuth(routePath);
}
