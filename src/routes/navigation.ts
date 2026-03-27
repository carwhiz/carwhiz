import { interfaceStore } from '../stores/interfaceStore';
import type { InterfaceMode } from './routes';
import { canAccessRoute, getRedirectPath } from './routeGuards';
import { navigateToMode } from './router';

/**
 * Navigate to a specific route
 */
export function navigateTo(routePath: InterfaceMode): boolean {
  if (!canAccessRoute(routePath)) {
    console.warn(`Access denied to route: ${routePath}`);
    return false;
  }

  navigateToMode(routePath);
  return true;
}

/**
 * Navigate to desktop interface
 */
export function goToDesktop(): boolean {
  return navigateTo('desktop');
}

/**
 * Navigate to mobile interface
 */
export function goToMobile(): boolean {
  return navigateTo('mobile');
}

/**
 * Navigate to login page
 */
export function goToLogin(): boolean {
  return navigateTo('login');
}

/**
 * Navigate to signup page
 */
export function goToSignUp(): boolean {
  return navigateTo('signup');
}

/**
 * Navigate to privacy policy
 */
export function goToPrivacy(): boolean {
  return navigateTo('privacy');
}

/**
 * Navigate to my jobs page
 */
export function goToMyJobs(): boolean {
  return navigateTo('my-jobs');
}

/**
 * Navigate to attendance page
 */
export function goToAttendance(): boolean {
  return navigateTo('attendance');
}

/**
 * Navigate to salary page
 */
export function goToSalary(): boolean {
  return navigateTo('salary' as InterfaceMode);
}

/**
 * Navigate back (to previous interface)
 */
export function goBack(fallback: InterfaceMode = 'login'): boolean {
  return navigateTo(fallback);
}
