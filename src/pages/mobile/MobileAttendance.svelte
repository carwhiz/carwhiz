<script lang="ts">
  import { onMount, tick } from 'svelte';
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
  let selectedDate = new Date().toISOString().split('T')[0];
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
    if (!$authStore.user) return;

    try {
      loading = true;
      error = '';

      // Load attendance for selected date using RPC
      const { data: records, error: recordsError } = await supabase.rpc(
        'fn_get_user_attendance',
        { p_date: selectedDate }
      );

      if (recordsError) {
        console.error('Error loading attendance records:', recordsError);
        error = `Failed to load attendance: ${recordsError.message}`;
        attendanceRecords = [];
      } else {
        attendanceRecords = records || [];
      }
    } catch (err) {
      console.error('Attendance load error:', err);
      error = `Error: ${err instanceof Error ? err.message : 'Unknown error'}`;
    } finally {
      loading = false;
    }
  }

  async function loadMonthlySummary() {
    if (!$authStore.user) return;

    try {
      const [year, month] = currentMonth.split('-');
      const { data, error: summaryError } = await supabase.rpc(
        'fn_get_attendance_summary',
        { p_year: parseInt(year), p_month: parseInt(month) }
      );

      if (summaryError) {
        console.error('Error loading summary:', summaryError);
      } else {
        attendanceSummary = data || [];
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
      // The QR generator creates a string like: "userId|1711200000000"
      // not a JSON object, so we verify it contains a pipe character
      if (typeof decodedText === 'string' && decodedText.includes('|')) {
        scannedToken = decodedText;
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
      scanError = 'Invalid QR code format.';
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
        p_action: action
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
    loadAttendance();
    loadMonthlySummary();
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

      <!-- Today's Attendance -->
      <div class="section">
        <h2>Today's Attendance</h2>
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
    background: #f5f5f5;
  }

  .content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .section {
    background: white;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .section h2 {
    margin: 0 0 15px 0;
    color: #333;
    font-size: 18px;
  }

  .date-selector,
  .month-selector {
    margin-bottom: 15px;
  }

  input[type='date'],
  input[type='month'] {
    padding: 8px 12px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    width: 100%;
    max-width: 200px;
  }

  .loading,
  .empty-state {
    text-align: center;
    padding: 40px 20px;
    color: #999;
  }

  .error-message {
    background: #fee;
    border: 1px solid #fcc;
    color: #c33;
    padding: 15px;
    margin: 20px;
    border-radius: 4px;
  }

  .attendance-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .attendance-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 15px;
    background: #f9f9f9;
    border-left: 4px solid #C41E3A;
    border-radius: 4px;
  }

  .punch-info {
    flex: 1;
  }

  .punch-number {
    font-weight: bold;
    color: #333;
    margin-bottom: 5px;
  }

  .times {
    display: flex;
    gap: 20px;
    font-size: 13px;
    color: #666;
  }

  .check-in,
  .check-out {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .worked-hours {
    text-align: right;
    font-weight: bold;
    color: #C41E3A;
    width: 80px;
  }

  .summary-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .summary-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    background: #f9f9f9;
    border-radius: 4px;
  }

  .date-status {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .date {
    font-weight: bold;
    color: #333;
    min-width: 100px;
  }

  .status {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: bold;
    text-transform: uppercase;
  }

  .status.present {
    background: #e8f5e9;
    color: #2e7d32;
  }

  .status.absent {
    background: #ffebee;
    color: #c62828;
  }

  .status.checked\ in {
    background: #e3f2fd;
    color: #1565c0;
  }

  /* ========== QR SCAN BUTTON ========== */
  .qr-scan-button {
    width: 100%;
    padding: 16px;
    background: linear-gradient(135deg, #C41E3A 0%, #a01830 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    margin-bottom: 20px;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.3);
    transition: all 0.2s;
  }

  .qr-scan-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(196, 30, 58, 0.4);
  }

  .qr-scan-button:active {
    transform: translateY(0);
  }

  /* ========== QR SCANNER OVERLAY ========== */
  .qr-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    z-index: 999;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .qr-scanner-box {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 20px;
    padding: 20px;
    width: 320px;
    max-width: 90vw;
    box-shadow: 0 16px 48px rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.8);
  }

  .qr-scanner-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 15px;
  }

  .qr-scanner-header h3 {
    font-size: 16px;
    font-weight: 700;
    color: #C41E3A;
    margin: 0;
  }

  .qr-close-btn {
    background: rgba(196, 30, 58, 0.1);
    border: none;
    font-size: 20px;
    cursor: pointer;
    color: #C41E3A;
    width: 32px;
    height: 32px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
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
    color: #6b7280;
    font-size: 13px;
    margin-top: 8px;
  }

  .qr-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 260px;
    gap: 16px;
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
    width: 40px;
    height: 40px;
    border: 4px solid rgba(196, 30, 58, 0.2);
    border-top-color: #C41E3A;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .qr-loading p {
    color: #6b7280;
    font-size: 13px;
    margin: 0;
  }

  /* ========== PUNCH CHOICE POPUP ========== */
  .punch-choice-box {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-radius: 24px;
    padding: 28px 24px;
    width: 320px;
    max-width: 90vw;
    box-shadow: 0 16px 48px rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.8);
  }

  .punch-title {
    font-size: 18px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
    text-align: center;
  }

  .punch-subtitle {
    font-size: 14px;
    color: #6b7280;
    margin-bottom: 20px;
    text-align: center;
  }

  .punch-buttons {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 16px;
  }

  .punch-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 16px 12px;
    border: none;
    border-radius: 12px;
    font-size: 15px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.25s;
    color: white;
  }

  .punch-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .punch-btn.checkin {
    background: linear-gradient(135deg, #22c55e, #16a34a);
    box-shadow: 0 6px 20px rgba(34, 197, 94, 0.35);
  }

  .punch-btn.checkin:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(34, 197, 94, 0.45);
  }

  .punch-btn.checkout {
    background: linear-gradient(135deg, #3b82f6, #2563eb);
    box-shadow: 0 6px 20px rgba(59, 130, 246, 0.35);
  }

  .punch-btn.checkout:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(59, 130, 246, 0.45);
  }

  .punch-cancel {
    background: none;
    border: none;
    color: #9ca3af;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    padding: 8px 16px;
    border-radius: 8px;
    transition: all 0.2s;
    width: 100%;
  }

  .punch-cancel:hover {
    color: #6b7280;
    background: rgba(0, 0, 0, 0.04);
  }

  /* ========== SCAN TOAST ========== */
  .scan-toast {
    position: fixed;
    bottom: 100px;
    left: 50%;
    transform: translateX(-50%);
    padding: 12px 24px;
    border-radius: 14px;
    font-size: 14px;
    font-weight: 600;
    z-index: 9999;
    cursor: pointer;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    animation: toastSlide 0.3s ease;
  }

  .scan-toast.success {
    background: rgba(220, 252, 231, 0.9);
    color: #166534;
    border: 1px solid rgba(34, 197, 94, 0.3);
  }

  .scan-toast.error {
    background: rgba(254, 226, 226, 0.9);
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

  .status.absent {
    background: #ffebee;
    color: #c62828;
  }

  .status.checked\ in {
    background: #e3f2fd;
    color: #1565c0;
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
