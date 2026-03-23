/**
 * Routing module exports
 * Centralized routing configuration and utilities
 */

// Route definitions
export type { Route, InterfaceMode } from './routes';
export { routes, getRoute, getRouteByUrl, getModeFromUrl, getUrlFromMode, requiresAuth, getAllRoutes, getPublicRoutes, getProtectedRoutes } from './routes';

// Route guards
export { isAuthenticated, canAccessRoute, getRedirectPath, isPublicRoute, isProtectedRoute } from './routeGuards';

// Navigation
export { navigateTo, goToDesktop, goToMobile, goToLogin, goToSignUp, goToPrivacy, goToMyJobs, goToAttendance, goBack } from './navigation';

// Router
export { initRouter, navigateToUrl, navigateToMode, getCurrentUrl, getCurrentMode } from './router';
