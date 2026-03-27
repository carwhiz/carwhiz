<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { supabase } from '../../lib/supabaseClient';
  import { authStore } from '../../stores/authStore';
  import { navigateTo } from '../../routes/navigation';
  import { setMobilePage } from '../../stores/mobilePageStore';
  import MobilePageWrapper from '../../components/shared/MobilePageWrapper.svelte';
  import { Html5Qrcode } from 'html5-qrcode';

  interface AttendanceRecord {
    id: string;
    check_in: string;
    check_out: string | null;
    punch_order: number;
    date: string;
  }

  interface AttendanceSummary {
    date: string;
    check_in_count: number;
    total_hours: number;
    status: string;
  }

  interface Employee {
    id: string;
    name: string;
    type: 'employee' | 'user';
  }

  let error = '';
  
  // Attendance report (for all users, admin sees all, others see only their own)
  let showAttendanceReport = false;
  let isAdmin = false;
  let allAttendanceRecords: any[] = [];
  let fromDate = '';
  let toDate = '';
  let userSearch = '';
  let reportLoading = false;

  // Computed filtered records
  $: filteredRecords = applyReportFilters(allAttendanceRecords, fromDate, toDate, userSearch);
  $: totalPunches = filteredRecords.length;
  $: totalHoursMs = filteredRecords.reduce((sum, r) => sum + calculatePunchMs(r.check_in, r.check_out), 0);
  $: totalHoursFormatted = formatMs(totalHoursMs);
  


  // QR Scanning state
  let showScanner = false;
  let showPunchChoice = false;
  let scannedToken = '';
  let scanResult = '';
  let scanError = '';
  let scanLoading = false;
  let html5QrScanner: any = null;







  function goBack() {
    navigateTo('mobile');
  }

  // Attendance Report Filter Functions (matches desktop)
  function setDefaultDates() {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    fromDate = `${y}-${m}-01`;
    toDate = now.toISOString().split('T')[0];
  }

  async function loadAllAttendanceRecords() {
    try {
      reportLoading = true;
      let query = supabase
        .from('attendance')
        .select('id, user_id, date, check_in, check_out, punch_order, users:user_id(email, user_name)')
        .order('date', { ascending: false })
        .order('punch_order', { ascending: true });

      // Non-admin users only see their own records
      if (!isAdmin && $authStore.user?.id) {
        query = query.eq('user_id', $authStore.user.id);
      }

      const { data } = await query;

      allAttendanceRecords = (data || []).map((r: any) => ({
        ...r,
        punch_order: r.punch_order || 1,
        user_email: r.users?.email || '—',
        user_name: r.users?.user_name || '',
      }));
      reportLoading = false;
    } catch (err) {
      console.error('Error loading attendance records:', err);
      reportLoading = false;
    }
  }

  function applyReportFilters(list: any[], from: string, to: string, search: string) {
    let result = list;
    if (from) result = result.filter(r => r.date >= from);
    if (to) result = result.filter(r => r.date <= to);
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      result = result.filter(r => 
        r.user_email.toLowerCase().includes(q) || 
        (r.user_name && r.user_name.toLowerCase().includes(q))
      );
    }
    return result;
  }

  function calculatePunchMs(checkIn: string | null, checkOut: string | null): number {
    if (!checkIn || !checkOut) return 0;
    return new Date(checkOut).getTime() - new Date(checkIn).getTime();
  }

  function formatMs(ms: number): string {
    if (ms <= 0) return '—';
    const hrs = Math.floor(ms / 3600000);
    const mins = Math.floor((ms % 3600000) / 60000);
    return `${hrs}h ${mins}m`;
  }

  function formatDateForDisplay(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt + 'T00:00:00');
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    return `${dd}/${mm}/${d.getFullYear()}`;
  }

  function formatTimeForDisplay(dt: string | null): string {
    if (!dt) return '—';
    const d = new Date(dt);
    let h = d.getHours();
    const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${h}:${min} ${ampm}`;
  }

  function getPunchDuration(checkIn: string | null, checkOut: string | null): string {
    const ms = calculatePunchMs(checkIn, checkOut);
    return formatMs(ms);
  }

  function clearReportFilters() {
    setDefaultDates();
    userSearch = '';
  }

  // QR Scanning functions
  async function startScanner() {
    scanResult = '';
    scanError = '';
    showPunchChoice = false;
    scannedToken = '';
    showScanner = true;
    scanLoading = true;  // Show loading indicator
    
    await tick();

    const readerEl = document.getElementById('qr-reader');
    if (!readerEl) { 
      scanError = 'Scanner element not found.'; 
      showScanner = false; 
      scanLoading = false;
      return; 
    }

    try {
      html5QrScanner = new Html5Qrcode('qr-reader');

      // For iOS/mobile, use facingMode constraint for rear camera
      const constraints = {
        facingMode: 'environment'
      };

      await html5QrScanner.start(
        constraints,
        { 
          fps: 15, 
          qrbox: { width: 300, height: 300 },
          disableFlip: false
        },
        onScanSuccess,
        (errorMsg: string) => {
          // Scan error handler - typically just log, don't stop scanner
          if (errorMsg && errorMsg.indexOf('NotFoundException') === -1) {
            console.log('Scan error:', errorMsg);
          }
        }
      );
      scanLoading = false;
    } catch (err: any) {
      const errMsg = err?.message || err?.toString() || 'Camera access denied or not available. Please ensure you have granted camera permissions to this site.';
      console.error('Scanner initialization failed:', errMsg, err);
      
      // Give a more user friendly error if it's permission denied
      if (err?.name === 'NotAllowedError' || errMsg.includes('Permission denied') || errMsg.includes('Permission dismissed')) {
         scanError = 'Camera permission denied. Please go to Settings > Safari and allow camera access for this site.';
      } else if (errMsg.includes('NotFoundError') || errMsg.includes('no camera')) {
         scanError = 'No camera found on your device.';
      } else if (errMsg.includes('NotSupportedError')) {
         scanError = 'QR scanning is not supported on your device or browser.';
      } else {
         scanError = errMsg || 'Failed to initialize camera. Please try again.';
      }
      showScanner = false;
      scanLoading = false;
    }
  }

  async function stopScanner() {
    if (html5QrScanner) {
      try { await html5QrScanner.stop(); } catch {}
      html5QrScanner = null;
    }
    showScanner = false;
  }

  async function onScanSuccess(decodedText: string) {
    if (scanLoading) return;
    scanLoading = true;
    await stopScanner();
    try {
      // QR now contains MD5 hash token (32 hex chars)
      // Format: md5(timeSlot + 'CARWHIZZ_HR_2026_SECRET')
      scannedToken = decodedText.trim().toLowerCase();
      
      // Get current time slot for debugging
      const currentTimeSlot = Math.floor(Date.now() / 1000 / 10);
      console.log('🔍 QR Scan Debug Info:');
      console.log('  Scanned Token:', scannedToken);
      console.log('  Current Time Slot:', currentTimeSlot);
      console.log('  Token Length:', scannedToken.length);
      
      // Validate it looks like an MD5 hash (32 hex characters) - case insensitive
      if (!/^[a-f0-9]{32}$/.test(scannedToken)) {
        console.error('❌ Token validation failed - not a valid MD5 hash');
        scanError = `Invalid QR code format: expected 32-character MD5 hash, received "${decodedText}" (${decodedText.length} chars).`;
        scanLoading = false;
        return;
      }
      
      if (!$authStore.user?.id) {
        scanError = 'Not logged in. Please log in and try again.';
        scanLoading = false;
        return;
      }
      console.log('✅ Token validated successfully. Awaiting check-in/check-out confirmation...');
      showPunchChoice = true;
    } catch (err) {
      console.error('❌ Unexpected error during QR scan:', err);
      scanError = 'Error processing QR code. Please try again.';
    }
    scanLoading = false;
  }

  async function doPunch(action: 'check_in' | 'check_out') {
    showPunchChoice = false;
    scanLoading = true;
    try {
      const userId = $authStore.user?.id;
      if (!userId) { 
        scanError = 'Not logged in. Please log in and try again.';
        scanLoading = false; 
        return; 
      }

      // Get today's date in IST (Asia/Kolkata)
      const formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Kolkata',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
      });
      const istDate = formatter.format(new Date());

      console.log(`📤 Sending ${action === 'check_in' ? '📍 CHECK-IN' : '📤 CHECK-OUT'} request...`);
      console.log('  Token:', scannedToken);
      console.log('  User ID:', userId);
      console.log('  Date:', istDate);

      const { data, error: punchError } = await supabase.rpc('fn_attendance_punch', {
        p_token: scannedToken,
        p_user_id: userId,
        p_action: action,
        p_date: istDate
      });
      
      if (punchError) { 
        console.error('❌ RPC Error:', punchError);
        scanError = `Database error: ${punchError.message}`; 
      } else if (data?.success) {
        console.log('✅ Punch successful:', data.message); 
        scanResult = data.message;
        await loadAllAttendanceRecords();
      } else {
        console.error('❌ Punch rejected by server:', data?.message); 
        scanError = data?.message || 'Punch failed. Your token may have expired - refresh the QR code and try again.'; 
      }
    } catch (err) {
      console.error('❌ Unexpected error during punch:', err);
      scanError = 'Network error occurred. Please check your connection and try again.';
    }
    scannedToken = '';
    scanLoading = false;
  }

  function cancelPunch() {
    showPunchChoice = false;
    scannedToken = '';
  }

  onMount(() => {
    setMobilePage('attendance', 'Attendance');
    
    // Show attendance report for all authenticated users
    if ($authStore.user?.id) {
      showAttendanceReport = true;
      isAdmin = $authStore.user?.role === 'admin';
      setDefaultDates();
      loadAllAttendanceRecords();
    }
  });

  onDestroy(() => {
    // Clean up QR scanner when leaving the page
    if (html5QrScanner) {
      try { 
        html5QrScanner.stop().catch(() => {}); 
      } catch {}
    }
    showScanner = false;
  });
</script>

<MobilePageWrapper>
  <div class="attendance-content">
    {#if error}
      <div class="error-message">
        <p>{error}</p>
      </div>
    {/if}

    <div class="content">
      <!-- QR Scan Button -->
      <button class="qr-scan-button" on:click={startScanner} title="Scan QR to mark attendance">
        <span>📱 Scan QR to Check In/Out</span>
      </button>

      <!-- Attendance Report (for all users) -->
      {#if showAttendanceReport}
        <div class="admin-report-section">
          <h3>{isAdmin ? 'Attendance Report' : 'My Attendance'}</h3>
          
          <!-- Summary Stats -->
          <div class="summary-stats">
            <div class="stat-card">
              <span class="stat-label">Punches</span>
              <span class="stat-value">{totalPunches}</span>
            </div>
            <div class="stat-card hours">
              <span class="stat-label">Total Hours</span>
              <span class="stat-value">{totalHoursFormatted}</span>
            </div>
          </div>

          <!-- Filters -->
          <div class="filters-section">
            <div class="filter-row">
              <div class="filter-group">
                <label for="from-date">From:</label>
                <input type="date" id="from-date" bind:value={fromDate} />
              </div>
              <div class="filter-group">
                <label for="to-date">To:</label>
                <input type="date" id="to-date" bind:value={toDate} />
              </div>
            </div>
            {#if isAdmin}
              <div class="filter-row">
                <div class="filter-group full-width">
                  <label for="user-search">Search User/Employee:</label>
                  <input 
                    type="text" 
                    id="user-search"
                    placeholder="Search by email or name..." 
                    bind:value={userSearch}
                  />
                </div>
              </div>
            {/if}
            <div class="filter-actions">
              <button class="btn-refresh" on:click={loadAllAttendanceRecords}>Refresh</button>
              <button class="btn-clear" on:click={clearReportFilters}>Clear Filters</button>
            </div>
          </div>

          <!-- Records Table -->
          {#if reportLoading}
            <div class="loading">Loading attendance records...</div>
          {:else if filteredRecords.length === 0}
            <div class="empty-state">No attendance records found</div>
          {:else}
            <div class="records-list">
              {#each filteredRecords as record (record.id)}
                <div class="record-item">
                  <div class="record-header">
                    <span class="user-info">
                      <strong>{record.user_email}</strong>
                      {#if record.user_name}
                        <span class="user-name">({record.user_name})</span>
                      {/if}
                    </span>
                    <span class="date">{formatDateForDisplay(record.date)}</span>
                  </div>
                  <div class="record-details">
                    <div class="detail-item">
                      <span class="label">Punch #{record.punch_order}</span>
                      <span class="value">
                        {formatTimeForDisplay(record.check_in)} - {formatTimeForDisplay(record.check_out)}
                      </span>
                    </div>
                    <div class="detail-item">
                      <span class="label">Duration</span>
                      <span class="value">{getPunchDuration(record.check_in, record.check_out)}</span>
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
        <hr class="section-divider" />
      {/if}
    </div>

    <!-- QR Scanner Overlay -->
    {#if showScanner}
      <div class="qr-overlay">
        <div class="qr-scanner-box">
          <div class="qr-scanner-header">
            <h3>Scan Attendance QR</h3>
            <button class="qr-close-btn" on:click={stopScanner}>&times;</button>
          </div>
          <div class="qr-reader-wrapper">
            {#if scanLoading}
              <div class="qr-loading">
                <div class="spinner"></div>
                <p>Initializing camera...</p>
              </div>
            {/if}
            <div id="qr-reader" style="width:100%; height:300px; overflow:hidden; border-radius:12px; background:#000;"></div>
          </div>
        </div>
      </div>
    {/if}

    <!-- Check-in / Check-out Choice Popup -->
    {#if showPunchChoice}
      <div class="qr-overlay">
        <div class="punch-choice-box">
          <h3 class="punch-title">Mark Attendance</h3>
          <p class="punch-subtitle">QR scanned successfully! Choose your action:</p>
          <div class="punch-buttons">
            <button class="punch-btn checkin" on:click={() => doPunch('check_in')} disabled={scanLoading}>
              ✓ Check In
            </button>
            <button class="punch-btn checkout" on:click={() => doPunch('check_out')} disabled={scanLoading}>
              → Check Out
            </button>
          </div>
          {#if scanLoading}<p class="qr-msg">Processing...</p>{/if}
          <button class="punch-cancel" on:click={cancelPunch}>Cancel</button>
        </div>
      </div>
    {/if}

    <!-- Scan Result/Error Toast -->
    {#if scanResult}
      <div class="scan-toast success" on:click={() => scanResult = ''} on:keydown={() => {}} role="button" tabindex="-1">
        {scanResult}
      </div>
    {/if}
    {#if scanError}
      <div class="scan-toast error" on:click={() => scanError = ''} on:keydown={() => {}} role="button" tabindex="-1">
        {scanError}
      </div>
    {/if}
  </div>
</MobilePageWrapper>

<style>
  .attendance-content {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--neutral-50);
  }

  .content {
    flex: 1;
    overflow-y: auto;
    padding: 1rem;
    -webkit-overflow-scrolling: touch;
  }

  @media (max-width: 640px) {
    .content {
      padding: 0.75rem;
    }
  }

  .section {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: var(--shadow-sm);
    border: 1px solid var(--neutral-200);
  }

  .section h2 {
    margin: 0 0 1.25rem 0;
    color: var(--neutral-900);
    font-size: 1.1rem;
    font-weight: 700;
  }

  .loading,
  .empty-state {
    text-align: center;
    padding: 2rem 1rem;
    color: var(--neutral-500);
    font-size: 0.95rem;
  }

  .error-message {
    background: rgba(196, 30, 58, 0.08);
    border: 1px solid rgba(196, 30, 58, 0.2);
    border-left: 4px solid var(--status-error);
    color: var(--status-error);
    padding: 1rem;
    margin: 1rem;
    border-radius: 8px;
    font-size: 0.9rem;
    font-weight: 500;
  }

  /* ========== QR SCAN BUTTON ========== */
  .qr-scan-button {
    width: 100%;
    padding: 1.25rem 1rem;
    background: linear-gradient(135deg, var(--brand-primary) 0%, var(--brand-secondary) 100%);
    color: white;
    border: none;
    border-radius: 12px;
    font-size: 1.1rem;
    font-weight: 700;
    cursor: pointer;
    margin-bottom: 1.5rem;
    box-shadow: var(--shadow-md);
    transition: all 0.3s ease;
    letter-spacing: 0.3px;
  }

  .qr-scan-button:hover {
    transform: translateY(-3px);
    box-shadow: var(--shadow-lg);
  }

  .qr-scan-button:active {
    transform: translateY(0);
  }

  @media (max-width: 640px) {
    .qr-scan-button {
      padding: 1.5rem 1rem;
      font-size: 1.05rem;
      margin-bottom: 1.25rem;
      border-radius: 10px;
    }
  }

  /* ========== QR SCANNER OVERLAY ========== */
  .qr-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    z-index: 999;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .qr-scanner-box {
    background: rgba(255, 255, 255, 0.97);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 20px;
    padding: 1.5rem;
    width: 320px;
    max-width: 90vw;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.3);
  }

  @media (max-width: 640px) {
    .qr-scanner-box {
      width: 100%;
      max-width: 95vw;
      padding: 1.25rem;
      border-radius: 16px;
    }
  }

  .qr-scanner-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .qr-scanner-header h3 {
    font-size: 1rem;
    font-weight: 700;
    color: var(--brand-primary);
    margin: 0;
  }

  .qr-close-btn {
    background: var(--brand-primary-light);
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: var(--brand-primary);
    width: 36px;
    height: 36px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }

  .qr-close-btn:hover {
    background: rgba(196, 30, 58, 0.2);
  }

  .qr-reader-wrapper {
    position: relative;
    width: 100%;
    min-height: 260px;
  }

  .qr-msg {
    text-align: center;
    color: var(--neutral-500);
    font-size: 0.85rem;
    margin-top: 0.75rem;
    font-weight: 500;
  }

  .qr-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 260px;
    gap: 1rem;
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(2px);
    -webkit-backdrop-filter: blur(2px);
    border-radius: 8px;
    z-index: 10;
  }

  .spinner {
    width: 48px;
    height: 48px;
    border: 4px solid var(--brand-primary-light);
    border-top-color: var(--brand-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .qr-loading p {
    color: var(--neutral-600);
    font-size: 0.85rem;
    margin: 0;
    font-weight: 500;
  }

  /* ========== PUNCH CHOICE POPUP ========== */
  .punch-choice-box {
    background: rgba(255, 255, 255, 0.97);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-radius: 24px;
    padding: 2rem 1.5rem;
    width: 320px;
    max-width: 90vw;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.3);
  }

  @media (max-width: 640px) {
    .punch-choice-box {
      width: 100%;
      max-width: 95vw;
      padding: 1.75rem 1.25rem;
      border-radius: 20px;
    }
  }

  .punch-title {
    font-size: 1.25rem;
    font-weight: 700;
    color: var(--neutral-900);
    margin: 0 0 0.5rem 0;
    text-align: center;
  }

  .punch-subtitle {
    font-size: 0.9rem;
    color: var(--neutral-600);
    margin-bottom: 1.5rem;
    text-align: center;
    font-weight: 500;
  }

  .punch-buttons {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-bottom: 1.25rem;
  }

  .punch-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 1.15rem 1rem;
    border: none;
    border-radius: 12px;
    font-size: 0.95rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    color: white;
    min-height: 48px;
  }

  .punch-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .punch-btn.checkin {
    background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
    box-shadow: 0 6px 20px rgba(34, 197, 94, 0.35);
  }

  .punch-btn.checkin:hover:not(:disabled) {
    transform: translateY(-3px);
    box-shadow: 0 8px 24px rgba(34, 197, 94, 0.45);
  }

  .punch-btn.checkin:active:not(:disabled) {
    transform: translateY(0);
  }

  .punch-btn.checkout {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    box-shadow: 0 6px 20px rgba(59, 130, 246, 0.35);
  }

  .punch-btn.checkout:hover:not(:disabled) {
    transform: translateY(-3px);
    box-shadow: 0 8px 24px rgba(59, 130, 246, 0.45);
  }

  .punch-btn.checkout:active:not(:disabled) {
    transform: translateY(0);
  }

  @media (max-width: 640px) {
    .punch-title {
      font-size: 1.15rem;
    }

    .punch-subtitle {
      font-size: 0.85rem;
      margin-bottom: 1.25rem;
    }

    .punch-buttons {
      gap: 0.75rem;
      margin-bottom: 1rem;
    }

    .punch-btn {
      padding: 1rem 0.85rem;
      font-size: 0.9rem;
      min-height: 44px;
      border-radius: 10px;
    }
  }

  .punch-cancel {
    background: none;
    border: none;
    color: var(--neutral-500);
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    padding: 0.75rem 1rem;
    border-radius: 8px;
    transition: all 0.2s ease;
    width: 100%;
  }

  .punch-cancel:hover {
    color: var(--neutral-700);
    background: rgba(0, 0, 0, 0.05);
  }

  /* ========== SCAN TOAST ========== */
  .scan-toast {
    position: fixed;
    bottom: 100px;
    left: 50%;
    transform: translateX(-50%);
    padding: 1rem 1.5rem;
    border-radius: 12px;
    font-size: 0.9rem;
    font-weight: 600;
    z-index: 9999;
    cursor: pointer;
    box-shadow: var(--shadow-lg);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    animation: toastSlide 0.3s ease;
  }

  .scan-toast.success {
    background: rgba(220, 252, 231, 0.95);
    color: #166534;
    border: 1px solid rgba(34, 197, 94, 0.3);
  }

  .scan-toast.error {
    background: rgba(254, 226, 226, 0.95);
    color: #991b1b;
    border: 1px solid rgba(239, 68, 68, 0.3);
  }

  @keyframes toastSlide {
    from {
      opacity: 0;
      transform: translateX(-50%) translateY(10px);
    }
    to {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
  }

  .scan-toast.info {
    background: var(--brand-primary-light);
    color: var(--brand-primary);
  }

  .summary-details {
    display: flex;
    gap: 20px;
    font-size: 13px;
    color: #666;
  }

  .punches,
  .hours {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .logs-section {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
  }

  .logs-section h4 {
    margin: 0 0 1rem 0;
    color: #1f2937;
  }

  .no-logs {
    text-align: center;
    color: #9ca3af;
    padding: 2rem 0;
    margin: 0;
  }

  .logs-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .log-entry {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem;
    background: #f9fafb;
    border-radius: 4px;
    font-size: 0.9rem;
  }

  .log-type {
    font-weight: 600;
    color: #1f2937;
  }

  .log-time {
    color: #6b7280;
  }

  /* ========== ADMIN REPORT SECTION ========== */
  .admin-report-section {
    background: linear-gradient(135deg, rgba(249, 115, 22, 0.08) 0%, rgba(59, 130, 246, 0.08) 100%);
    border: 1px solid rgba(249, 115, 22, 0.2);
    border-radius: 12px;
    padding: 1.25rem;
    margin: 0;
    margin-bottom: 1rem;
  }

  .admin-report-section h3 {
    margin: 0 0 1rem 0;
    font-size: 1.1rem;
    color: var(--neutral-900);
    font-weight: 700;
  }

  @media (max-width: 640px) {
    .admin-report-section {
      padding: 1rem;
      border-radius: 10px;
      margin-bottom: 0.75rem;
    }

    .admin-report-section h3 {
      font-size: 1rem;
      margin-bottom: 0.75rem;
    }
  }

  .summary-stats {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 1.25rem;
  }

  .stat-card {
    background: white;
    border: 1px solid var(--neutral-200);
    border-radius: 8px;
    padding: 0.85rem;
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.35rem;
  }

  .stat-card.hours {
    background: rgba(239, 68, 68, 0.05);
    border-color: rgba(239, 68, 68, 0.2);
  }

  .stat-label {
    font-size: 0.75rem;
    color: var(--neutral-600);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }

  .stat-value {
    font-size: 1.35rem;
    font-weight: 700;
    color: var(--brand-primary);
  }

  @media (max-width: 640px) {
    .summary-stats {
      gap: 0.5rem;
      margin-bottom: 1rem;
    }

    .stat-card {
      padding: 0.75rem;
      gap: 0.3rem;
    }

    .stat-label {
      font-size: 0.7rem;
    }

    .stat-value {
      font-size: 1.2rem;
    }
  }

  .filters-section {
    background: white;
    border-radius: 8px;
    padding: 1rem;
    margin-bottom: 1.25rem;
    border: 1px solid var(--neutral-200);
  }

  .filter-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .filter-row:last-of-type {
    margin-bottom: 0;
  }

  @media (max-width: 640px) {
    .filters-section {
      padding: 0.85rem;
      margin-bottom: 1rem;
    }

    .filter-row {
      grid-template-columns: 1fr;
      gap: 0.5rem;
      margin-bottom: 0.5rem;
    }
  }

  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .filter-group.full-width {
    grid-column: 1 / -1;
  }

  .filter-group label {
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--neutral-700);
    display: block;
    margin-bottom: 0.35rem;
  }

  .filter-group input {
    padding: 0.65rem 0.75rem;
    border: 1px solid var(--neutral-300);
    border-radius: 6px;
    font-size: 0.9rem;
    transition: all 0.2s ease;
    width: 100%;
    box-sizing: border-box;
  }

  .filter-group input:focus {
    outline: none;
    border-color: var(--brand-primary);
    box-shadow: 0 0 0 3px var(--brand-primary-light);
    background: var(--neutral-50);
  }

  @media (max-width: 640px) {
    .filter-group label {
      font-size: 0.75rem;
      margin-bottom: 0.25rem;
    }

    .filter-group input {
      padding: 0.6rem 0.65rem;
      font-size: 0.85rem;
    }
  }

  .filter-actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.75rem;
  }

  .btn-refresh,
  .btn-clear {
    flex: 1;
    padding: 0.65rem 0.85rem;
    border: 1px solid var(--neutral-300);
    border-radius: 6px;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    background: white;
    color: var(--neutral-700);
    white-space: nowrap;
  }

  .btn-refresh:active,
  .btn-clear:active {
    transform: scale(0.98);
  }

  .btn-refresh:hover {
    background: var(--neutral-50);
    border-color: var(--brand-primary);
    color: var(--brand-primary);
  }

  .btn-clear:hover {
    background: var(--neutral-100);
  }

  @media (max-width: 640px) {
    .filter-actions {
      gap: 0.35rem;
      margin-top: 0.5rem;
    }

    .btn-refresh,
    .btn-clear {
      padding: 0.55rem 0.65rem;
      font-size: 0.75rem;
    }
  }

  .records-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    max-height: 60vh;
    overflow-y: auto;
    padding-right: 0.25rem;
  }

  .records-list::-webkit-scrollbar {
    width: 6px;
  }

  .records-list::-webkit-scrollbar-thumb {
    background: rgba(0, 0, 0, 0.2);
    border-radius: 3px;
  }

  .record-item {
    background: white;
    border: 1px solid var(--neutral-200);
    border-left: 4px solid var(--brand-primary);
    border-radius: 8px;
    padding: 0.85rem;
    transition: all 0.2s ease;
  }

  .record-item:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }

  .record-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.6rem;
    padding-bottom: 0.6rem;
    border-bottom: 1px solid var(--neutral-100);
    flex-wrap: wrap;
    gap: 0.4rem;
  }

  .user-info {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    flex-wrap: wrap;
    font-size: 0.9rem;
  }

  .user-info strong {
    font-weight: 700;
  }

  .user-name {
    font-size: 0.8rem;
    color: var(--neutral-500);
    font-weight: normal;
  }

  .record-header .date {
    font-size: 0.8rem;
    color: var(--neutral-600);
    font-weight: 600;
  }

  .record-details {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  @media (max-width: 640px) {
    .records-list {
      gap: 0.4rem;
      max-height: 45vh;
      padding-right: 0.15rem;
    }

    .record-item {
      padding: 0.75rem;
      border-radius: 6px;
    }

    .record-header {
      margin-bottom: 0.5rem;
      padding-bottom: 0.5rem;
      gap: 0.3rem;
    }

    .user-info {
      gap: 0.3rem;
      font-size: 0.85rem;
    }

    .user-name {
      font-size: 0.75rem;
    }

    .record-header .date {
      font-size: 0.75rem;
    }

    .record-details {
      gap: 0.3rem;
    }
  }

  .detail-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.9rem;
    gap: 0.5rem;
  }

  .detail-item .label {
    color: var(--neutral-600);
    font-weight: 600;
  }

  .detail-item .value {
    color: var(--neutral-900);
    font-weight: 500;
    text-align: right;
  }

  @media (max-width: 640px) {
    .detail-item {
      font-size: 0.85rem;
      gap: 0.35rem;
    }

    .detail-item .label {
      font-weight: 600;
    }

    .detail-item .value {
      font-size: 0.85rem;
    }
  }

  .section-divider {
    border: none;
    border-top: 1px solid var(--neutral-200);
    margin: 0.75rem 0;
  }

</style>
