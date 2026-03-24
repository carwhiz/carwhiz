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

  let attendanceRecords: AttendanceRecord[] = [];
  let attendanceSummary: AttendanceSummary[] = [];
  let loading = true;
  let error = '';
  
  // Initialize dates in IST (Asia/Kolkata) to match RPC queries
  function getISTDate(): string {
    const now = new Date();
    const istTime = new Date(now.getTime() + (330 * 60 * 1000)); // IST is UTC+5:30
    return istTime.toISOString().split('T')[0];
  }
  
  let selectedDate = getISTDate();
  let currentMonth = new Date().toISOString().slice(0, 7);

  // QR Scanning state
  let showScanner = false;
  let showPunchChoice = false;
  let scannedToken = '';
  let scanResult = '';
  let scanError = '';
  let scanLoading = false;
  let html5QrScanner: any = null;

  async function loadAttendance() {
    if (!$authStore.user?.id) {
      error = 'User not authenticated';
      loading = false;
      return;
    }

    try {
      loading = true;
      error = '';

      console.log('Loading attendance for user:', $authStore.user.id, 'date:', selectedDate);

      // Direct query instead of RPC - same approach as desktop report
      const { data, error: queryError } = await supabase
        .from('attendance')
        .select('id, check_in, check_out, punch_order, date')
        .eq('user_id', $authStore.user.id)
        .eq('date', selectedDate)
        .order('punch_order', { ascending: true });

      console.log('Attendance data:', { data, error: queryError });

      if (queryError) {
        error = `Failed to load attendance: ${queryError.message}`;
        attendanceRecords = [];
      } else {
        attendanceRecords = data || [];
        console.log(`Loaded ${attendanceRecords.length} attendance records`);
      }
    } catch (err) {
      console.error('Attendance load error:', err);
      error = `Error: ${err instanceof Error ? err.message : 'Unknown error'}`;
    } finally {
      loading = false;
    }
  }

  async function loadMonthlySummary() {
    if (!$authStore.user?.id) {
      console.warn('User not authenticated, skipping monthly summary');
      return;
    }

    try {
      const [year, month] = currentMonth.split('-');
      const monthStart = `${year}-${month}-01`;
      const monthEnd = new Date(parseInt(year), parseInt(month), 0).toISOString().split('T')[0];

      console.log('Loading monthly summary for:', { year, month, monthStart, monthEnd });

      // Direct query for daily summaries - same approach as desktop
      const { data, error: queryError } = await supabase
        .from('attendance')
        .select('id, check_in, check_out, punch_order, date')
        .eq('user_id', $authStore.user.id)
        .gte('date', monthStart)
        .lte('date', monthEnd)
        .order('date', { ascending: false })
        .order('punch_order', { ascending: true });

      console.log('Monthly data from query:', { data, error: queryError });

      if (queryError) {
        console.error('Error loading monthly data:', queryError);
        attendanceSummary = [];
      } else {
        // Aggregate by date
        const summaryMap = new Map<string, any>();
        if (data) {
          for (const record of data) {
            if (!summaryMap.has(record.date)) {
              summaryMap.set(record.date, {
                date: record.date,
                check_in_count: 0,
                total_hours: 0,
                status: 'Absent',
                punches: []
              });
            }
            const summary = summaryMap.get(record.date)!;
            summary.check_in_count++;
            summary.punches.push(record);

            // Calculate hours for this punch
            if (record.check_in && record.check_out) {
              const checkIn = new Date(record.check_in).getTime();
              const checkOut = new Date(record.check_out).getTime();
              const hours = (checkOut - checkIn) / (1000 * 60 * 60);
              summary.total_hours += hours;
            }

            // Set status
            if (record.check_out === null) {
              summary.status = 'Checked In';
            } else if (summary.check_in_count > 0) {
              summary.status = 'Present';
            }
          }
        }

        attendanceSummary = Array.from(summaryMap.values())
          .map(s => ({
            date: s.date,
            check_in_count: s.check_in_count,
            total_hours: Math.round(s.total_hours * 100) / 100, // Round to 2 decimals
            status: s.status
          }))
          .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

        console.log(`Loaded ${attendanceSummary.length} monthly summary records`);
      }
    } catch (err) {
      console.error('Summary load error:', err);
    }
  }

  function formatTime(timestamp: string | null): string {
    if (!timestamp) return '--:--';
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: true
    });
  }

  function calculateWorkedHours(record: AttendanceRecord): string {
    if (!record.check_out) return 'Ongoing';
    const checkIn = new Date(record.check_in);
    const checkOut = new Date(record.check_out);
    const hours = (checkOut.getTime() - checkIn.getTime()) / 3600000;
    return hours.toFixed(2) + ' hrs';
  }

  function goBack() {
    navigateTo('mobile');
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
          fps: 10, 
          qrbox: { width: 200, height: 200 },
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
      scannedToken = decodedText.trim();
      
      // Validate it looks like an MD5 hash (32 hex characters)
      if (!/^[a-f0-9]{32}$/.test(scannedToken)) {
        scanError = 'Invalid QR code format (not a valid hash).';
        scanLoading = false;
        return;
      }
      
      if (!$authStore.user?.id) {
        scanError = 'Not logged in.';
        scanLoading = false;
        return;
      }
      showPunchChoice = true;
    } catch {
      scanError = 'Invalid QR code format.';
    }
    scanLoading = false;
  }

  async function doPunch(action: 'check_in' | 'check_out') {
    showPunchChoice = false;
    scanLoading = true;
    try {
      const userId = $authStore.user?.id;
      if (!userId) { 
        scanError = 'Not logged in.'; 
        scanLoading = false; 
        return; 
      }

      const { data, error: punchError } = await supabase.rpc('fn_attendance_punch', {
        p_token: scannedToken,
        p_user_id: userId,
        p_action: action,
        p_date: selectedDate  // ← Pass IST date from mobile
      });
      
      if (punchError) { 
        scanError = punchError.message; 
      } else if (data?.success) { 
        scanResult = data.message;
        await loadAttendance();
      } else { 
        scanError = data?.message || 'Punch failed.'; 
      }
    } catch {
      scanError = 'Something went wrong.';
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
    // Always load today's attendance (IST date)
    loadAttendance();
    loadMonthlySummary();
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

      <!-- Day Wise Attendance -->
      <div class="section">
        <h2>Day Wise Attendance</h2>
        <div class="date-selector">
          <input type="date" bind:value={selectedDate} on:change={loadAttendance} />
        </div>

        {#if loading}
          <div class="loading">Loading attendance...</div>
        {:else if attendanceRecords.length === 0}
          <div class="empty-state">
            <p>No attendance records for this date</p>
          </div>
        {:else}
          <div class="attendance-list">
            {#each attendanceRecords as record (record.id)}
              <div class="attendance-item">
                <div class="punch-info">
                  <div class="punch-number">Punch #{record.punch_order}</div>
                  <div class="times">
                    <span class="check-in">
                      🕐 In: {formatTime(record.check_in)}
                    </span>
                    <span class="check-out">
                      🕑 Out: {formatTime(record.check_out)}
                    </span>
                  </div>
                </div>
                <div class="worked-hours">
                  {calculateWorkedHours(record)}
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Monthly Summary -->
      <div class="section">
        <h2>Monthly Summary</h2>
        <div class="month-selector">
          <input type="month" bind:value={currentMonth} on:change={loadMonthlySummary} />
        </div>

        {#if attendanceSummary.length === 0}
          <div class="empty-state">
            <p>No attendance data for this month</p>
          </div>
        {:else}
          <div class="summary-list">
            {#each attendanceSummary.slice(0, 15) as summary (summary.date)}
              <div class="summary-item">
                <div class="date-status">
                  <span class="date">{new Date(summary.date).toLocaleDateString('en-IN')}</span>
                  <span class="status {summary.status.toLowerCase()}">{summary.status}</span>
                </div>
                <div class="summary-details">
                  <span class="punches">Punches: {summary.check_in_count}</span>
                  <span class="hours">Hours: {summary.total_hours?.toFixed(1) || '0'}</span>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
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

  .date-selector,
  .month-selector {
    margin-bottom: 1rem;
  }

  input[type='date'],
  input[type='month'] {
    padding: 0.75rem 1rem;
    border: 1px solid var(--neutral-300);
    border-radius: 8px;
    font-size: 0.95rem;
    width: 100%;
    max-width: 240px;
    background: white;
    color: var(--neutral-900);
    transition: all 0.2s ease;
    font-weight: 500;
  }

  input[type='date']:focus,
  input[type='month']:focus {
    outline: none;
    border-color: var(--brand-primary);
    box-shadow: 0 0 0 3px var(--brand-primary-light);
    background: var(--neutral-50);
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

  .attendance-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .attendance-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.25rem;
    background: var(--neutral-50);
    border-left: 4px solid var(--brand-primary);
    border-radius: 8px;
    transition: all 0.2s ease;
  }

  .attendance-item:hover {
    background: var(--neutral-100);
  }

  .punch-info {
    flex: 1;
  }

  .punch-number {
    font-weight: 700;
    color: var(--neutral-900);
    margin-bottom: 0.5rem;
    font-size: 0.95rem;
  }

  .times {
    display: flex;
    gap: 1.25rem;
    font-size: 0.85rem;
    color: var(--neutral-600);
  }

  .check-in,
  .check-out {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    font-weight: 500;
  }

  .check-in {
    color: var(--status-success);
  }

  .check-out {
    color: var(--status-warning);
  }

  .worked-hours {
    text-align: right;
    font-weight: 700;
    color: var(--brand-primary);
    min-width: 100px;
  }

  .summary-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: var(--neutral-50);
    border-radius: 8px;
    border: 1px solid var(--neutral-100);
    transition: all 0.2s ease;
  }

  .summary-item:hover {
    border-color: var(--neutral-200);
    background: var(--neutral-100);
  }

  .date-status {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .date {
    font-weight: 600;
    color: var(--neutral-900);
    min-width: 110px;
    font-size: 0.9rem;
  }

  .status {
    display: inline-block;
    padding: 0.375rem 0.95rem;
    border-radius: 20px;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }

  .status.present {
    background: rgba(16, 185, 129, 0.1);
    color: #059669;
  }

  .status.absent {
    background: rgba(196, 30, 58, 0.1);
    color: #991b1b;
  }

  .status.checked\ in {
    background: rgba(59, 130, 246, 0.1);
    color: #1565c0;
  }

  .summary-details {
    display: flex;
    gap: 1.25rem;
    font-size: 0.85rem;
    color: var(--neutral-600);
    font-weight: 500;
  }

  /* ========== QR SCAN BUTTON ========== */
  .qr-scan-button {
    width: 100%;
    padding: 1rem;
    background: linear-gradient(135deg, var(--brand-primary) 0%, var(--brand-secondary) 100%);
    color: white;
    border: none;
    border-radius: 10px;
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
    margin-bottom: 1.5rem;
    box-shadow: var(--shadow-md);
    transition: all 0.3s ease;
  }

  .qr-scan-button:hover {
    transform: translateY(-3px);
    box-shadow: var(--shadow-lg);
  }

  .qr-scan-button:active {
    transform: translateY(0);
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
    padding: 1rem 1rem;
    border: none;
    border-radius: 12px;
    font-size: 0.95rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    color: white;
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

  .punch-btn.checkout {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    box-shadow: 0 6px 20px rgba(59, 130, 246, 0.35);
  }

  .punch-btn.checkout:hover:not(:disabled) {
    transform: translateY(-3px);
    box-shadow: 0 8px 24px rgba(59, 130, 246, 0.45);
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
</style>
