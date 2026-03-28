# PWA QR Code System - Developer Guide

## The Problem We Fixed

**Issue:** When the CarWhizz PWA was installed on a laptop and the window lost focus (minimized, app in background, or system sleep), the QR code would become **stale and invalid** for scanning.

**Root Cause:** 
- Browser/OS throttles JavaScript execution when PWA loses focus (battery saving)
- The 10-second QR refresh timer (`setInterval`) pauses during throttling
- Server only accepts QR codes generated in the **current or previous 10-second window** (20-second max grace period)
- After 20+ seconds of the app being in background, the displayed QR becomes "invalid"
- User has to refresh the page to get a working QR code

**Impact:**
- ❌ Attendance scanning fails with "Invalid QR code"
- ❌ Users must manually refresh the page
- ❌ Poor user experience
- ❌ Defeats the purpose of a PWA

## The Solution

### For Developers - How to Use QR Codes

**DO: Use the `qrUtils.ts` Utility**

```typescript
import { generateQRImage, setupQRWithPWAFix } from '../../lib/services/qrUtils';

let qrDataUrl: string = '';
let qrRefreshInterval: any;
let cleanupFocusDetection: (() => void) | null = null;

async function generateQR() {
  qrDataUrl = await generateQRImage({ width: 250, margin: 2 });
  // Image is automatically set with proper MD5 hashing
}

onMount(async () => {
  await generateQR(); // Initial generation
  
  // This handles PWA background throttling automatically
  const { interval, cleanup } = setupQRWithPWAFix(generateQR);
  qrRefreshInterval = interval;
  cleanupFocusDetection = cleanup;
  
  return cleanup;
});

onDestroy(() => {
  clearInterval(qrRefreshInterval);
  if (cleanupFocusDetection) cleanupFocusDetection();
});
```

**DON'T: Manually implement QR generation**

❌ Don't do this - it won't handle the PWA issue:
```typescript
// BAD - Missing PWA throttling fix
const token = `${userId}|${timestamp}`;
const qr = await QRCode.toDataURL(token);
```

### For Developers - What the Utility Does

The `qrUtils.ts` module provides:

1. **`generateQRToken()`** - Generates a time-slot based MD5 hash that matches server validation
   - Uses: `md5(timeSlot || 'CARWHIZZ_HR_2026_SECRET')`
   - Time slot = current seconds / 10 (10-second blocks)
   - Returns a 32-character MD5 hash

2. **`generateQRImage(options)`** - Creates the QR code image
   - Calls `generateQRToken()` internally
   - Returns a Data URL for displaying in `<img>` tag

3. **`setupQRFocusDetection(callback)`** - Watches for app focus/visibility changes
   - Listens for `visibilitychange` event (tab switching)
   - Listens for `focus` event (window regaining focus)
   - **Immediately** regenerates QR code when app comes back into focus
   - Prevents stale codes from being scanned

4. **`setupQRWithPWAFix(callback)`** - Complete setup (recommended)
   - Starts the 10-second refresh interval
   - Adds focus detection
   - Returns both the interval ID and cleanup function

### How It Works Now

**Timeline:**
```
Browser running normally:
└─ Every 10 seconds: generateQR() fires automatically ✅

User minimizes/focus lost:
├─ Browser pauses setInterval (throttling)
├─ QR code is 20, 30, 40+ seconds old
└─ Server would reject it as expired ❌

User brings window back into focus:
├─ Browser/OS detects window focus
├─ setupQRFocusDetection() triggers immediately
├─ generateQR() fires BEFORE user scans
└─ Fresh QR code with valid timestamp ✅
```

## Technical Details

### Server-Side Validation (Database)

The server accepts QR codes only if the MD5 hash matches:
```sql
time_slot := EXTRACT(EPOCH FROM now())::BIGINT / 10;
valid_token := md5(time_slot::TEXT || 'CARWHIZZ_HR_2026_SECRET');
prev_token := md5((time_slot - 1)::TEXT || 'CARWHIZZ_HR_2026_SECRET');

-- Accepts current slot OR previous slot (10-second grace period)
IF p_token != valid_token AND p_token != prev_token THEN
  RETURN 'Invalid or expired QR code';
END IF;
```

### Client-Side Generation (Now)

Uses the utility to match server's expected format:
```typescript
const timeSlot = Math.floor(Date.now() / 1000 / 10);
const token = md5(String(timeSlot) + 'CARWHIZZ_HR_2026_SECRET');
// Returns a 32-char hex string like "a1b2c3d4e5f6..."
```

## Configuration

If you need to change QR parameters, edit in `qrUtils.ts`:

```typescript
export const QR_CONFIG = {
  SECRET: 'CARWHIZZ_HR_2026_SECRET',        // Shared with database
  REFRESH_INTERVAL: 10000,                   // 10 seconds (ms)
  SLOT_DURATION: 10                          // Seconds per time slot
};
```

⚠️ **IMPORTANT:** If you change these values:
- Update the database `fn_attendance_punch()` function to match
- Update the secret in Supabase migrations
- Ensure server and client use identical values

## Files Affected

1. **[src/lib/services/qrUtils.ts](src/lib/services/qrUtils.ts)** - Utility implementation
2. **[src/components/windows/hr/AttendanceQRWindow.svelte](src/components/windows/hr/AttendanceQRWindow.svelte)** - Updated to use utility
3. **[src/pages/desktop/DesktopLayout.svelte](src/pages/desktop/DesktopLayout.svelte)** - Updated to use utility

## Testing the Fix

**Before:**
1. Open CarWhizz PWA on laptop
2. Minimize window for 30+ seconds
3. Restore window
4. Try to scan QR → ❌ "Invalid QR code" error
5. Refresh page
6. Scan again → ✅ Works now

**After (With Fix):**
1. Open CarWhizz PWA on laptop
2. Minimize window for 30+ seconds
3. Restore window (QR regenerates automatically)
4. Try to scan QR → ✅ Works immediately!
5. No refresh needed

## Future Implementations

If you need to add QR codes to other features (not just attendance):

```typescript
// Example: Adding QR codes to a new feature
import { setupQRWithPWAFix } from '../lib/services/qrUtils';

onMount(() => {
  const { interval, cleanup } = setupQRWithPWAFix(generatorFunction);
  // ... store interval and cleanup
  return cleanup;
});
```

The utility automatically handles all PWA throttling issues.

## Debugging

Check the console for debug logs:
```
✅ QR Code refreshed at 10:30:45
🔄 [QR] Window regained visibility - refreshing QR code
🔄 [QR] Window focus event - refreshing QR code
```

If you see "Window regained focus" multiple times, that's normal—it means the PWA is properly detecting focus changes.

---

**Last Updated:** March 29, 2026
**Status:** ✅ Fixed and documented
