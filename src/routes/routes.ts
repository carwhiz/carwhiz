import type { SvelteComponent } from 'svelte';
import AuthLogin from '../pages/auth/AuthLogin.svelte';
import AuthSignUp from '../pages/auth/AuthSignUp.svelte';
import MobileLayout from '../pages/mobile/MobileLayout.svelte';
import DesktopLayout from '../pages/desktop/DesktopLayout.svelte';
import PrivacyPolicy from '../pages/info/PrivacyPolicy.svelte';
import MobileMyJobs from '../pages/mobile/MobileMyJobs.svelte';
import MobileAttendance from '../pages/mobile/MobileAttendance.svelte';

export type InterfaceMode = 'login' | 'signup' | 'mobile' | 'desktop' | 'privacy' | 'my-jobs' | 'attendance';

export interface Route {
  path: InterfaceMode;
  url: string;
  name: string;
  component: typeof SvelteComponent;
  requiresAuth: boolean;
  description: string;
}

export const routes: Record<InterfaceMode, Route> = {
  login: {
    path: 'login',
    url: '/',
    name: 'Login',
    component: AuthLogin,
    requiresAuth: false,
    description: 'User authentication page'
  },
  signup: {
    path: 'signup',
    url: '/signup',
    name: 'Sign Up',
    component: AuthSignUp,
    requiresAuth: false,
    description: 'User registration page'
  },
  mobile: {
    path: 'mobile',
    url: '/mobile',
    name: 'Mobile Interface',
    component: MobileLayout,
    requiresAuth: true,
    description: 'Mobile application interface'
  },
  desktop: {
    path: 'desktop',
    url: '/desktop',
    name: 'Desktop Interface',
    component: DesktopLayout,
    requiresAuth: true,
    description: 'Desktop application interface'
  },
  privacy: {
    path: 'privacy',
    url: '/privacy-policy',
    name: 'Privacy Policy',
    component: PrivacyPolicy,
    requiresAuth: false,
    description: 'Privacy policy page'
  },
  'my-jobs': {
    path: 'my-jobs',
    url: '/my-jobs',
    name: 'My Jobs',
    component: MobileMyJobs,
    requiresAuth: true,
    description: 'User job cards page'
  },
  'attendance': {
    path: 'attendance',
    url: '/attendance',
    name: 'Attendance',
    component: MobileAttendance,
    requiresAuth: true,
    description: 'Attendance tracking page'
  }
};

/**
 * Get a route configuration by path
 */
export function getRoute(path: InterfaceMode): Route {
  return routes[path];
}

/**
 * Get a route configuration by URL
 */
export function getRouteByUrl(url: string): Route | undefined {
  return Object.values(routes).find(route => route.url === url || route.url === `/${url}` || `/${url}` === route.url);
}

/**
 * Get interface mode from URL
 */
export function getModeFromUrl(url: string): InterfaceMode | undefined {
  const route = getRouteByUrl(url);
  return route?.path;
}

/**
 * Get URL from interface mode
 */
export function getUrlFromMode(mode: InterfaceMode): string {
  return routes[mode]?.url || '/';
}

/**
 * Check if a route requires authentication
 */
export function requiresAuth(path: InterfaceMode): boolean {
  return routes[path]?.requiresAuth ?? false;
}

/**
 * Get all available routes
 */
export function getAllRoutes(): Route[] {
  return Object.values(routes);
}

/**
 * Get public routes (no auth required)
 */
export function getPublicRoutes(): Route[] {
  return Object.values(routes).filter(route => !route.requiresAuth);
}

/**
 * Get protected routes (auth required)
 */
export function getProtectedRoutes(): Route[] {
  return Object.values(routes).filter(route => route.requiresAuth);
}
