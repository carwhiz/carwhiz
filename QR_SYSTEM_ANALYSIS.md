# QR Code Scanning System - Complete Analysis

## EXECUTIVE SUMMARY

**Critical Issue Found:** The QR code generation format on the client-side **does NOT match** the token validation format expected by the database function. This causes all QR scans to fail with "invalid qr" error.

---

## 1. QR CODE GENERATION (Client-Side)

### Location
- **Desktop:** [src/pages/desktop/DesktopLayout.svelte](src/pages/desktop/DesktopLayout.svelte#L103-L114)
- **Mobile:** [src/components/windows/hr/AttendanceQRWindow.svelte](src/components/windows/hr/AttendanceQRWindow.svelte#L20-L30)

### Generated Token Format
```typescript
const token = `${$authStore.user?.id}|${new Date().getTime()}`;
```

### Example Output
```
a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6|1711270000000
```

**Format:** `UUID|MILLISECOND_TIMESTAMP` (plain text, human-readable)

**Refresh Interval:** Every 10 seconds (line 13 in both files)

---

## 2. MOBILE QR SCANNING (Client-Side)

### Location
[src/pages/mobile/MobileAttendance.svelte](src/pages/mobile/MobileAttendance.svelte#L187-L205)

### Scanning Function: `onScanSuccess()`
```typescript
async function onScanSuccess(decodedText: string) {
  if (scanLoading) return;
  scanLoading = true;
  await stopScanner();
  try {
    // The QR generator creates a string like: "userId|1711200000000"
    // not a JSON object, so we verify it contains a pipe character
    if (typeof decodedText === 'string' && decodedText.includes('|')) {
      scannedToken = decodedText;  // ← Takes the plain text as-is
    } else {
      // Fallback in case it was accidentally generated as JSON elsewhere
      const payload = JSON.parse(decodedText);
      scannedToken = payload.t || decodedText;
    }
    
    if (!$authStore.user?.id) {
      scanError = 'Not logged in.';
      scanLoading = false;
      return;
    }
    showPunchChoice = true;
  } catch {
    scanError = 'Invalid QR code format.';  // ← Error on client
  }
  scanLoading = false;
}
```

**What it does:**
- Reads the QR code as plain text (e.g., `userId|timestamp`)
- Validates it contains a pipe `|` separator
- Stores it directly in `scannedToken`
- Sends it to the database function as-is

---

## 3. DATABASE TOKEN VALIDATION (Server-Side)

### Location
- [supabase/migrations/025_multi_punch_attendance.sql](supabase/migrations/025_multi_punch_attendance.sql) (Latest version)
- Also in: [019_hr_attendance.sql](supabase/migrations/019_hr_attendance.sql) and [021_attendance_action_param.sql](supabase/migrations/021_attendance_action_param.sql)

### Function: `fn_attendance_punch()`
```sql
CREATE OR REPLACE FUNCTION public.fn_attendance_punch(
  p_token TEXT,
  p_user_id UUID,
  p_action TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  time_slot BIGINT;
  secret TEXT := 'CARWHIZZ_HR_2026_SECRET';
  valid_token TEXT;
  prev_token TEXT;
  today DATE := CURRENT_DATE;
  open_punch RECORD;
  punch_cnt INT;
BEGIN
  -- Validate token
  time_slot := EXTRACT(EPOCH FROM now())::BIGINT / 10;  -- Current 10-second slot
  valid_token := md5(time_slot::TEXT || secret);         -- Current slot hash
  prev_token := md5((time_slot - 1)::TEXT || secret);    -- Previous slot hash

  -- ⚠️ CRITICAL CHECK
  IF p_token != valid_token AND p_token != prev_token THEN
    RETURN json_build_object('success', false, 'message', 'Invalid or expired QR code. Please scan again.');
  END IF;
  
  -- ... rest of punch logic
END;
$$;
```

### Expected Token Format
The database expects `p_token` to be an **MD5 hash** of the format: `md5(timeslot || secret)`

**Example:**
```
Time: 2024-03-24 10:30:45 UTC
Time in seconds: 1711270245
Time slot (÷10): 171127024
Token expected: md5('171127024CARWHIZZ_HR_2026_SECRET')
              = a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6 (32 hex chars)
```

**Validation Window:**
- ✅ Current time slot: `md5(current_slot || secret)`
- ✅ Previous time slot: `md5((current_slot - 1) || secret)` (10-second grace period)
- ❌ Everything else: Returns error

---

## 4. THE CRITICAL MISMATCH

| Component | Format Sent | Format Expected | Status |
|-----------|------------|-----------------|--------|
| **Client QR Generation** | `UUID\|timestamp` | N/A | ✅ |
| **Client QR Parsing** | Takes plain text: `UUID\|timestamp` | N/A | ✅ |
| **Server Token Validation** | Receives: `UUID\|timestamp` | MD5 hash (32 hex) | ❌ **MISMATCH** |

### Example Breakdown

**What happens when scanning:**

1. **Desktop displays:** `a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6|1711270000000` (in QR)
2. **Mobile scans:** Camera reads it as `a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6|1711270000000`
3. **Sent to DB:** `p_token = "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6|1711270000000"`
4. **DB calculates:**
   - `valid_token = md5("171127024" || "CARWHIZZ_HR_2026_SECRET")`
   - `valid_token = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"` (different!)
5. **Comparison:** `"a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6|1711270000000"` ≠ `"a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"`
6. **Result:** ❌ Returns `'Invalid or expired QR code. Please scan again.'`

---

## 5. ERROR MESSAGE SOURCES

### Client-Side Error
**File:** [src/pages/mobile/MobileAttendance.svelte](src/pages/mobile/MobileAttendance.svelte#L204)
```typescript
scanError = 'Invalid QR code format.';
```
**Trigger:** If scanned text doesn't contain `|` or JSON parsing fails

### Server-Side Error
**File:** All attendance migrations (019, 021, 025)
```sql
RETURN json_build_object('success', false, 'message', 'Invalid or expired QR code. Please scan again.');
```
**Trigger:** Token validation fails (which it ALWAYS will with current format)

---

## 6. ROOT CAUSE ANALYSIS

### Why This Mismatch Exists

1. **History of Changes:**
   - Initially: QR codes probably used a simple format
   - Later: Security requirement added - tokens should be time-limited and cryptographically signed
   - Database function was updated to use MD5 hashing with time slots
   - **⚠️ Client-side generation was NEVER updated** to match the new validation logic

2. **No Client-Side Hashing:**
   - There is NO MD5 or crypto library imported in either `AttendanceQRWindow.svelte` or `DesktopLayout.svelte`
   - The QR generation remains the simple `userId|timestamp` format from the original implementation
   - The database expects a hash because it's STATELESS - it can't store tokens, so it validates them cryptographically

---

## 7. IMPACT ANALYSIS

### What Doesn't Work
- ❌ All QR code scanning from mobile app
- ❌ Attendance punch functionality entirely
- ❌ Both check-in and check-out operations
- ❌ Both check-in and check-out choices (when action parameter is used)

### What Still Works
- ✅ QR code generation and display
- ✅ QR code refresh every 10 seconds
- ✅ Mobile scanner initialization
- ✅ Database connection and RPC calls
- ✅ Attendance data retrieval functions (fn_get_user_attendance, fn_get_attendance_summary)

### Who Is Affected
- ✅ All employees trying to log attendance via QR scan
- ✅ Any device using MobileAttendance.svelte
- ✅ Not affected: Desktop employees trying to use HR menu (would attempt scanning but fail at DB)

---

## 8. RECOMMENDED FIX

### Option A: Update Client Generation to Use MD5 (Recommended for Security)
- Add crypto library to project (crypto-js or crypto module)
- Update `generateQR()` in both files to:
  ```typescript
  const timeSlot = Math.floor(Date.now() / 1000 / 10);
  const secret = 'CARWHIZZ_HR_2026_SECRET';
  const token = md5(timeSlot.toString() + secret);
  // Encode token in QR (no need for userId or timestamp)
  ```
- Client validation must match server-side time slot calculation
- **Pro:** More secure, time-limited tokens, matches server logic
- **Con:** Needs crypto library addition

### Option B: Simplify Server Validation (Less Secure)
- Remove MD5 hash validation from database
- Accept the `userId|timestamp` format as-is
- Validate timestamp is recent (within last 60 seconds)
- **Pro:** No client-side changes needed, simpler
- **Con:** Less secure, QR codes don't expire properly

### Option C: Server-Side Token Generation (Most Secure)
- Generate tokens on server (database function)
- Client calls RPC to get current token instead of computing it
- Database stores tokens in a temporary table with expiry
- Client encodes the token in QR
- **Pro:** Most secure, token rotation, server control
- **Con:** Requires session/temporary table and RPC endpoint

---

## 9. VERIFICATION CHECKLIST

- [x] QR generation format verified (plain text with pipe)
- [x] QR parsing logic verified (accepts pipe-separated text)
- [x] Database validation logic verified (expects MD5 hash)
- [x] Token format mismatch confirmed
- [x] No client-side crypto functions found
- [x] Error message paths identified
- [x] All migration versions checked (019, 021, 025)
- [x] Testing impact assessed

---

## KEY FINDINGS SUMMARY

| Finding | Details |
|---------|---------|
| **Critical Bug** | Token format mismatch between generation and validation |
| **Generation Format** | `UUID\|millisecond_timestamp` |
| **Expected Format** | `md5(timeslot \|\| secret)` (32 hex chars) |
| **Always Fails** | Yes, validation will always fail with current code |
| **Error Type** | Server-side validation failure (DB function) |
| **Severity** | CRITICAL - Attendance system completely non-functional |
| **Quick Fix** | Update client to calculate MD5 token like server does |

