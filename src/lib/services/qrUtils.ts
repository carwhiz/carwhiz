/**
 * QR Code Utility Functions
 * 
 * IMPORTANT: Handles PWA background throttling issue where JS timers pause
 * when the app loses focus, causing QR codes to become stale after 10+ seconds.
 * 
 * This utility ensures QR codes always refresh immediately when the app
 * regains focus, preventing "Invalid QR code" errors.
 */

import QRCode from 'qrcode';
import md5 from 'md5';

/**
 * Configuration for time-slot based QR codes (used by server for validation)
 */
export const QR_CONFIG = {
  SECRET: 'CARWHIZZ_HR_2026_SECRET',
  REFRESH_INTERVAL: 10000, // 10 seconds (matches server-side time slots)
  SLOT_DURATION: 10 // seconds
};

/**
 * Generates a time-slot based MD5 token for QR code (server-side compatible)
 * 
 * Server validation expects: md5(timeSlot || 'CARWHIZZ_HR_2026_SECRET')
 * where timeSlot = seconds_since_epoch / 10
 * 
 * @returns {string} MD5 hash token
 */
export function generateQRToken(): string {
  const timeSlot = Math.floor(Date.now() / 1000 / QR_CONFIG.SLOT_DURATION);
  const token = md5(String(timeSlot) + QR_CONFIG.SECRET);
  
  return token;
}

/**
 * Generates a QR code image with proper timing
 * 
 * @param options - QR code display options (width, margin, colors)
 * @returns {Promise<string>} Data URL of the QR code image
 */
export async function generateQRImage(options: any = {}): Promise<string> {
  const token = generateQRToken();
  const defaultOptions = {
    width: 250,
    margin: 2,
    color: { dark: '#111827', light: '#ffffff' }
  };

  const qrOptions = { ...defaultOptions, ...options };

  return QRCode.toDataURL(token, qrOptions);
}

/**
 * Sets up a managed QR refresh system that handles PWA focus/visibility changes
 * 
 * PROBLEM SOLVED:
 * - Browser throttles JS when PWA loses focus
 * - setTimeout/setInterval pause when app is in background
 * - Server rejects QR codes older than 10-20 seconds
 * 
 * SOLUTION:
 * - Watches for window focus and visibility changes
 * - Immediately regenerates QR code when app comes back into focus
 * - Regular 10-second refresh continues in foreground
 * 
 * @param onRefresh - Callback function to call when QR should refresh
 * @returns {Function} Cleanup function to remove all listeners
 * 
 * @example
 * let interval: any;
 * onMount(async () => {
 *   await onRefresh(); // Initial generation
 *   interval = setInterval(onRefresh, QR_CONFIG.REFRESH_INTERVAL);
 * 
 *   // This handles the PWA background throttling issue
 *   const cleanup = setupQRFocusDetection(async () => {
 *     await onRefresh();
 *   });
 * 
 *   return cleanup;
 * });
 */
export function setupQRFocusDetection(onRefresh: () => Promise<void>): () => void {
  const handleVisibilityChange = () => {
    if (!document.hidden) {
      console.log('🔄 [QR] Window regained visibility - refreshing QR code');
      onRefresh().catch(err => console.error('QR refresh failed:', err));
    }
  };

  const handleWindowFocus = () => {
    console.log('🔄 [QR] Window focus event - refreshing QR code');
    onRefresh().catch(err => console.error('QR refresh failed:', err));
  };

  // Attach listeners for focus detection
  document.addEventListener('visibilitychange', handleVisibilityChange);
  window.addEventListener('focus', handleWindowFocus);

  // Return cleanup function
  return () => {
    document.removeEventListener('visibilitychange', handleVisibilityChange);
    window.removeEventListener('focus', handleWindowFocus);
  };
}

/**
 * Complete setup for time-slot QR code generation with PWA handling
 * 
 * This is the recommended way to use QR codes in any new feature
 * that needs time-based validation (like attendance tracking)
 * 
 * @param onRefresh - Async callback to refresh the QR display
 * @param componentSetInterval - The setInterval ID to store (for cleanup)
 * @returns {Object} Setup result with interval ID and cleanup function
 * 
 * @example
 * let refreshInterval: any;
 * 
 * onMount(() => {
 *   const { interval, cleanup } = setupQRWithPWAFix(generateQR);
 *   refreshInterval = interval;
 *   return cleanup;
 * });
 * 
 * onDestroy(() => {
 *   clearInterval(refreshInterval);
 * });
 */
export function setupQRWithPWAFix(onRefresh: () => Promise<void>): {
  interval: any;
  cleanup: () => void;
} {
  // Start regular refresh interval
  const interval = setInterval(() => {
    onRefresh().catch(err => console.error('QR refresh failed:', err));
  }, QR_CONFIG.REFRESH_INTERVAL);

  // Setup focus detection for PWA background throttling issue
  const cleanup = setupQRFocusDetection(onRefresh);

  return { interval, cleanup };
}
