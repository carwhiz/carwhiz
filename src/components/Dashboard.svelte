<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../stores/authStore';
  import { logout } from '../lib/services/authService';
  import { interfaceStore } from '../stores/interfaceStore';
  import { windowStore } from '../stores/windowStore';
  import { supabase } from '../lib/supabaseClient';
  import { tick } from 'svelte';
  import AppWindow from './AppWindow.svelte';
  import SalesWindow from './windows/finance/operations/SalesWindow.svelte';
  import PurchaseWindow from './windows/finance/operations/PurchaseWindow.svelte';
  import ReceiptWindow from './windows/finance/operations/ReceiptWindow.svelte';
  import PaymentWindow from './windows/finance/operations/PaymentWindow.svelte';
  import VehiclesWindow from './windows/products/manage/VehiclesWindow.svelte';
  import CreateVehicleWindow from './windows/products/manage/CreateVehicleWindow.svelte';
  import EditVehicleWindow from './windows/products/manage/EditVehicleWindow.svelte';
  import ProductsWindow from './windows/products/manage/ProductsWindow.svelte';
  import CreateProductWindow from './windows/products/manage/CreateProductWindow.svelte';
  import EditProductWindow from './windows/products/manage/EditProductWindow.svelte';
  import CustomersWindow from './windows/finance/manage/CustomersWindow.svelte';
  import CreateCustomerWindow from './windows/finance/manage/CreateCustomerWindow.svelte';
  import VendorsWindow from './windows/finance/manage/VendorsWindow.svelte';
  import CreateVendorWindow from './windows/finance/manage/CreateVendorWindow.svelte';
  import LedgerWindow from './windows/finance/manage/LedgerWindow.svelte';
  import CreateLedgerWindow from './windows/finance/manage/CreateLedgerWindow.svelte';
  import EditLedgerWindow from './windows/finance/manage/EditLedgerWindow.svelte';
  import CreateEmployeeWindow from './windows/finance/manage/CreateEmployeeWindow.svelte';
  import AssetsWindow from './windows/finance/manage/AssetsWindow.svelte';
  import CreateAssetWindow from './windows/finance/manage/CreateAssetWindow.svelte';
  import SalesReportWindow from './windows/finance/reports/SalesReportWindow.svelte';
  import PurchaseReportWindow from './windows/finance/reports/PurchaseReportWindow.svelte';
  import LedgerBalanceWindow from './windows/finance/reports/LedgerBalanceWindow.svelte';
  import DayBookWindow from './windows/finance/reports/DayBookWindow.svelte';
  import TrialBalanceWindow from './windows/finance/reports/TrialBalanceWindow.svelte';
  import ProfitLossWindow from './windows/finance/reports/ProfitLossWindow.svelte';
  import BalanceSheetWindow from './windows/finance/reports/BalanceSheetWindow.svelte';
  import AuditLogWindow from './windows/appcontrol/reports/AuditLogWindow.svelte';
  import UsersWindow from './windows/appcontrol/manage/UsersWindow.svelte';
  import PermissionsWindow from './windows/appcontrol/manage/PermissionsWindow.svelte';
  import StockReportWindow from './windows/products/reports/StockReportWindow.svelte';
  import AttendanceReportWindow from './windows/hr/reports/AttendanceReportWindow.svelte';
  import { createEventDispatcher } from 'svelte';
  import { onDestroy } from 'svelte';
  import QRCode from 'qrcode';

  const dispatch = createEventDispatcher();

  // Sidebar section collapse state
  let expandedSections: Record<string, boolean> = { finance: false, products: false, appcontrol: false, hr: false };
  let expandedSubs: Record<string, boolean> = {};

  // ---- QR Attendance (Desktop) ----
  let qrDataUrl = '';
  let qrTimer: any = null;

  async function generateQR() {
    const { data, error } = await supabase.rpc('fn_generate_attendance_token');
    if (!error && data) {
      const token = JSON.stringify({ t: data, ts: Date.now() });
      qrDataUrl = await QRCode.toDataURL(token, { width: 200, margin: 1, color: { dark: '#111827', light: '#ffffff' } });
    }
  }

  function startQRTimer() {
    generateQR();
    qrTimer = setInterval(generateQR, 10000);
  }

  function stopQRTimer() {
    if (qrTimer) { clearInterval(qrTimer); qrTimer = null; }
  }

  // ---- QR Attendance (Mobile) ----
  let showScanner = false;
  let scanResult = '';
  let scanError = '';
  let scanLoading = false;
  let html5QrScanner: any = null;

  async function startScanner() {
    scanResult = '';
    scanError = '';
    showScanner = true;
    // Wait for Svelte DOM update
    await tick();
    await new Promise(r => setTimeout(r, 500));

    const readerEl = document.getElementById('qr-reader');
    if (!readerEl) { scanError = 'Scanner element not found.'; showScanner = false; return; }

    try {
      const { Html5Qrcode } = await import('html5-qrcode');
      html5QrScanner = new Html5Qrcode('qr-reader');

      const cameras = await Html5Qrcode.getCameras();
      if (!cameras || cameras.length === 0) {
        scanError = 'No camera found on this device.';
        showScanner = false;
        return;
      }

      // Prefer back camera, fallback to first available
      const backCam = cameras.find((c: any) => c.label.toLowerCase().includes('back') || c.label.toLowerCase().includes('rear'));
      const cameraId = backCam ? backCam.id : cameras[cameras.length - 1].id;

      await html5QrScanner.start(
        cameraId,
        { fps: 10, qrbox: { width: 200, height: 200 } },
        onScanSuccess,
        () => {}
      );
    } catch (err: any) {
      scanError = err?.message || 'Camera access denied or not available.';
      showScanner = false;
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
      const payload = JSON.parse(decodedText);
      const token = payload.t;
      const userId = $authStore.user?.id;
      if (!userId) { scanError = 'Not logged in.'; scanLoading = false; return; }

      const { data, error } = await supabase.rpc('fn_attendance_punch', { p_token: token, p_user_id: userId });
      if (error) { scanError = error.message; }
      else if (data?.success) { scanResult = data.message; }
      else { scanError = data?.message || 'Punch failed.'; }
    } catch {
      scanError = 'Invalid QR code.';
    }
    scanLoading = false;
  }

  function toggleSection(key: string) {
    expandedSections[key] = !expandedSections[key];
  }

  function toggleSub(key: string) {
    expandedSubs[key] = !expandedSubs[key];
  }

  function openWindow(id: string, title: string) {
    windowStore.open(id, title);
  }

  async function handleLogout() {
    await logout();
    dispatch('logout');
  }

  // ---- Mobile Dashboard Data ----
  let mobileDate = new Date().toISOString().split('T')[0];
  let salesToday = 0;
  let salesCount = 0;
  let purchaseToday = 0;
  let purchaseCount = 0;
  let expenseToday = 0;
  let expenseCount = 0;
  let cashBalance = 0;
  let bankBalance = 0;
  let salesBalanceTotal = 0;
  let purchaseBalanceTotal = 0;
  let mobileLoading = true;

  function formatMobileAmt(val: number): string {
    const sign = val < 0 ? '-' : '';
    const abs = Math.abs(val);
    return sign + '₹' + abs.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function formatDisplayDate(dateStr: string): string {
    const d = new Date(dateStr + 'T00:00:00');
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    return `${dd}/${mm}/${d.getFullYear()}`;
  }

  function changeDate(offset: number) {
    const d = new Date(mobileDate + 'T00:00:00');
    d.setDate(d.getDate() + offset);
    mobileDate = d.toISOString().split('T')[0];
    loadMobileData();
  }

  async function loadMobileData() {
    mobileLoading = true;

    const { data, error } = await supabase.rpc('fn_dashboard_summary', { p_date: mobileDate });
    if (!error && data) {
      salesToday = data.sales_total || 0;
      salesCount = data.sales_count || 0;
      purchaseToday = data.purchase_total || 0;
      purchaseCount = data.purchase_count || 0;
      expenseToday = data.expense_total || 0;
      expenseCount = data.expense_count || 0;
      cashBalance = data.cash_balance || 0;
      bankBalance = data.bank_balance || 0;
      salesBalanceTotal = data.sales_balance || 0;
      purchaseBalanceTotal = data.purchase_balance || 0;
    }

    mobileLoading = false;
  }

  onMount(() => {
    if ($interfaceStore === 'mobile') loadMobileData();
    if ($interfaceStore === 'desktop') startQRTimer();
  });

  onDestroy(() => { stopQRTimer(); });

  // Reload when switching to mobile
  $: if ($interfaceStore === 'mobile') { loadMobileData(); stopQRTimer(); }
  $: if ($interfaceStore === 'desktop') startQRTimer();
</script>

<!-- ================================================================
     DASHBOARD - Main application interface
     Supports Mobile and Desktop modes via interfaceStore
     ================================================================ -->
<div class="dashboard" class:desktop-mode={$interfaceStore === 'desktop'} class:mobile-mode={$interfaceStore === 'mobile'}>
  {#if $interfaceStore === 'mobile'}
    <!-- ============================================================
         MOBILE INTERFACE
         ============================================================ -->
    <div class="mobile-layout">
      <div class="mobile-top-bar">
        <img src="/logo.jpeg" alt="CarWhizz" class="top-bar-logo" />
        <button class="logout-btn" on:click={handleLogout}>Logout</button>
      </div>

      <div class="mobile-content">
        <!-- Date Navigation -->
        <div class="m-date-nav">
          <button class="m-date-btn" on:click={() => changeDate(-1)} title="Previous day">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
            <span class="sr-only">Previous day</span>
          </button>
          <span class="m-date-label">{formatDisplayDate(mobileDate)}</span>
          <button class="m-date-btn" on:click={() => changeDate(1)} title="Next day">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="9 18 15 12 9 6"/></svg>
            <span class="sr-only">Next day</span>
          </button>
        </div>

        {#if mobileLoading}
          <div class="m-loading">Loading...</div>
        {:else}
          <!-- Cards Grid: 2 per row -->
          <div class="m-cards">
            <!-- Sales Card -->
            <div class="m-card sales">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>
              </div>
              <div class="m-card-label">Sales</div>
              <div class="m-card-amount">{formatMobileAmt(salesToday)}</div>
              <div class="m-card-sub">{salesCount} bill{salesCount !== 1 ? 's' : ''}</div>
            </div>

            <!-- Purchase Card -->
            <div class="m-card purchase">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>
              </div>
              <div class="m-card-label">Purchase</div>
              <div class="m-card-amount">{formatMobileAmt(purchaseToday)}</div>
              <div class="m-card-sub">{purchaseCount} invoice{purchaseCount !== 1 ? 's' : ''}</div>
            </div>

            <!-- Expense Card -->
            <div class="m-card expense">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" width="22" height="22"><text x="12" y="18" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor" stroke="none">₹</text></svg>
              </div>
              <div class="m-card-label">Expenses</div>
              <div class="m-card-amount">{formatMobileAmt(expenseToday)}</div>
              <div class="m-card-sub">{expenseCount} entr{expenseCount !== 1 ? 'ies' : 'y'}</div>
            </div>

            <!-- Cash Balance Card -->
            <div class="m-card cash">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M12 8v8"/><path d="M8 12h8"/></svg>
              </div>
              <div class="m-card-label">Cash Balance</div>
              <div class="m-card-amount">{formatMobileAmt(cashBalance)}</div>
              <div class="m-card-sub">All cash ledgers</div>
            </div>

            <!-- Bank Balance Card -->
            <div class="m-card bank">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M3 21h18"/><path d="M3 10h18"/><path d="M12 3l9 7H3l9-7z"/><path d="M5 10v11"/><path d="M19 10v11"/><path d="M9 10v11"/><path d="M15 10v11"/></svg>
              </div>
              <div class="m-card-label">Bank Balance</div>
              <div class="m-card-amount">{formatMobileAmt(bankBalance)}</div>
              <div class="m-card-sub">All bank ledgers</div>
            </div>

            <!-- Sales Balance Card -->
            <div class="m-card sales-bal">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
              </div>
              <div class="m-card-label">Sales Balance</div>
              <div class="m-card-amount">{formatMobileAmt(salesBalanceTotal)}</div>
              <div class="m-card-sub">Total receivable</div>
            </div>

            <!-- Purchase Balance Card -->
            <div class="m-card purchase-bal">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/><line x1="9" y1="12" x2="15" y2="12"/><line x1="9" y1="16" x2="15" y2="16"/></svg>
              </div>
              <div class="m-card-label">Purchase Balance</div>
              <div class="m-card-amount">{formatMobileAmt(purchaseBalanceTotal)}</div>
              <div class="m-card-sub">Total payable</div>
            </div>
          </div>
        {/if}

        <!-- QR Scanner Overlay -->
        {#if showScanner}
          <div class="qr-overlay">
            <div class="qr-scanner-box">
              <div class="qr-scanner-header">
                <h3>Scan Attendance QR</h3>
                <button class="qr-close-btn" on:click={stopScanner}>&times;</button>
              </div>
              <div id="qr-reader" style="width:100%;min-height:260px;"></div>
              {#if scanLoading}<p class="qr-msg">Processing...</p>{/if}
            </div>
          </div>
        {/if}

        <!-- Scan Result/Error -->
        {#if scanResult}
          <div class="scan-toast success" on:click={() => scanResult = ''} on:keydown={() => {}} role="button" tabindex="-1">{scanResult}</div>
        {/if}
        {#if scanError}
          <div class="scan-toast error" on:click={() => scanError = ''} on:keydown={() => {}} role="button" tabindex="-1">{scanError}</div>
        {/if}
      </div>

      <div class="mobile-bottom-bar">
        <div class="bottom-bar-item active">
          <svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>
          <span>Home</span>
        </div>
        <button class="bottom-bar-item" on:click={startScanner}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><circle cx="17.5" cy="17.5" r="3.5"/></svg>
          <span>Attendance</span>
        </button>
        <div class="bottom-bar-item">
          <span class="placeholder-icon"></span>
          <span>&nbsp;</span>
        </div>
        <div class="bottom-bar-item">
          <span class="placeholder-icon"></span>
          <span>&nbsp;</span>
        </div>
      </div>
    </div>
  {:else}
    <!-- ============================================================
         DESKTOP INTERFACE
         ============================================================ -->
    <div class="desktop-layout">
      <!-- ========================================================
           SIDEBAR NAVIGATION
           ======================================================== -->
      <div class="desktop-sidebar">
        <nav class="sidebar-nav">
          <!-- ====================================================
               MAIN SECTION: FINANCE
               Sub-sections: Manage | Operations | Reports
               ==================================================== -->
          <button class="nav-section" class:expanded={expandedSections.finance} on:click={() => toggleSection('finance')}>
            <svg viewBox="0 0 24 24"><text x="12" y="18" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor" stroke="none">₹</text></svg>
            <span>Finance</span>
            <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
          </button>

          {#if expandedSections.finance}
            <div class="sub-sections">
              <!-- ---- Finance > Manage ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['finance-manage']} on:click={() => toggleSub('finance-manage')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Manage</span>
              </button>
              {#if expandedSubs['finance-manage']}
                <div class="sub-items">
                  <!-- Finance > Manage > Customers -->
                  <button class="nav-item" on:click={() => openWindow('finance-customers', 'Customers')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                    <span>Customers</span>
                  </button>
                  <!-- Finance > Manage > Vendors -->
                  <button class="nav-item" on:click={() => openWindow('finance-vendors', 'Vendors')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                    <span>Vendors</span>
                  </button>
                  <!-- Finance > Manage > Ledger -->
                  <button class="nav-item" on:click={() => openWindow('finance-ledger', 'Ledger')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>
                    <span>Ledger</span>
                  </button>
                  <!-- Finance > Manage > Assets -->
                  <button class="nav-item" on:click={() => openWindow('finance-assets', 'Fixed Assets')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/></svg>
                    <span>Fixed Assets</span>
                  </button>
                </div>
              {/if}

              <!-- ---- Finance > Operations ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['finance-operations']} on:click={() => toggleSub('finance-operations')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Operations</span>
              </button>
              {#if expandedSubs['finance-operations']}
                <div class="sub-items">
                  <!-- Finance > Operations > Sales -->
                  <button class="nav-item" on:click={() => openWindow('finance-sales', 'Sales')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>
                    <span>Sales</span>
                  </button>
                  <!-- Finance > Operations > Purchase -->
                  <button class="nav-item" on:click={() => openWindow('finance-purchase', 'Purchase')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>
                    <span>Purchase</span>
                  </button>
                  <!-- Finance > Operations > Receipts -->
                  <button class="nav-item" on:click={() => openWindow('finance-receipt', 'Receipts')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
                    <span>Receipts</span>
                  </button>
                  <!-- Finance > Operations > Payments -->
                  <button class="nav-item" on:click={() => openWindow('finance-payment', 'Payments')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 11V3H7v8"/><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                    <span>Payments</span>
                  </button>
                </div>
              {/if}

              <!-- ---- Finance > Reports ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['finance-reports']} on:click={() => toggleSub('finance-reports')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Reports</span>
              </button>
              {#if expandedSubs['finance-reports']}
                <div class="sub-items">
                  <!-- Finance > Reports > Sales Report -->
                  <button class="nav-item" on:click={() => openWindow('finance-sales-report', 'Sales Report')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                    <span>Sales Report</span>
                  </button>
                  <!-- Finance > Reports > Purchase Report -->
                  <button class="nav-item" on:click={() => openWindow('finance-purchase-report', 'Purchase Report')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                    <span>Purchase Report</span>
                  </button>
                  <!-- Finance > Reports > Ledger Balance -->
                  <button class="nav-item" on:click={() => openWindow('finance-ledger-balance', 'Ledger Balance')}>
                    <svg viewBox="0 0 24 24"><text x="12" y="18" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor" stroke="none">₹</text></svg>
                    <span>Ledger Balance</span>
                  </button>
                  <!-- Finance > Reports > Day Book -->
                  <button class="nav-item" on:click={() => openWindow('finance-day-book', 'Day Book')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>
                    <span>Day Book</span>
                  </button>
                  <!-- Finance > Reports > Trial Balance -->
                  <button class="nav-item" on:click={() => openWindow('finance-trial-balance', 'Trial Balance')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3v18"/><path d="M3 9h18"/><circle cx="6" cy="15" r="2"/><circle cx="18" cy="15" r="2"/></svg>
                    <span>Trial Balance</span>
                  </button>
                  <!-- Finance > Reports > Profit & Loss -->
                  <button class="nav-item" on:click={() => openWindow('finance-profit-loss', 'Profit & Loss')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>
                    <span>Profit & Loss</span>
                  </button>
                  <!-- Finance > Reports > Balance Sheet -->
                  <button class="nav-item" on:click={() => openWindow('finance-balance-sheet', 'Balance Sheet')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="12" y1="3" x2="12" y2="21"/></svg>
                    <span>Balance Sheet</span>
                  </button>
                </div>
              {/if}
            </div>
          {/if}

          <!-- ====================================================
               MAIN SECTION: PRODUCTS
               Sub-sections: Manage | Operations | Reports
               ==================================================== -->
          <button class="nav-section" class:expanded={expandedSections.products} on:click={() => toggleSection('products')}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
            <span>Products</span>
            <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
          </button>

          {#if expandedSections.products}
            <div class="sub-sections">
              <!-- ---- Products > Manage ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['products-manage']} on:click={() => toggleSub('products-manage')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Manage</span>
              </button>
              {#if expandedSubs['products-manage']}
                <div class="sub-items">
                  <!-- Products > Manage > Vehicles -->
                  <button class="nav-item" on:click={() => openWindow('products-vehicles', 'Vehicles')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 17h14M5 17a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2M5 17l-1 3h16l-1-3"/><circle cx="7.5" cy="17" r="1.5"/><circle cx="16.5" cy="17" r="1.5"/></svg>
                    <span>Vehicles</span>
                  </button>
                  <!-- Products > Manage > Products -->
                  <button class="nav-item" on:click={() => openWindow('products-products', 'Products')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
                    <span>Products</span>
                  </button>
                </div>
              {/if}

              <!-- ---- Products > Operations ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['products-operations']} on:click={() => toggleSub('products-operations')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Operations</span>
              </button>
              {#if expandedSubs['products-operations']}
                <div class="sub-items">
                  <!-- Products > Operations items go here -->
                </div>
              {/if}

              <!-- ---- Products > Reports ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['products-reports']} on:click={() => toggleSub('products-reports')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Reports</span>
              </button>
              {#if expandedSubs['products-reports']}
                <div class="sub-items">
                  <!-- Products > Reports > Stock Report -->
                  <button class="nav-item" on:click={() => openWindow('products-stock-report', 'Stock Report')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
                    <span>Stock Report</span>
                  </button>
                </div>
              {/if}
            </div>
          {/if}

          <!-- ====================================================
               MAIN SECTION: HR
               Sub-sections: Manage | Operations | Reports
               ==================================================== -->
          <button class="nav-section" class:expanded={expandedSections.hr} on:click={() => toggleSection('hr')}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
            <span>HR</span>
            <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
          </button>

          {#if expandedSections.hr}
            <div class="sub-sections">
              <!-- ---- HR > Manage ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['hr-manage']} on:click={() => toggleSub('hr-manage')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Manage</span>
              </button>
              {#if expandedSubs['hr-manage']}
                <div class="sub-items">
                  <!-- HR > Manage items go here -->
                </div>
              {/if}

              <!-- ---- HR > Operations ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['hr-operations']} on:click={() => toggleSub('hr-operations')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Operations</span>
              </button>
              {#if expandedSubs['hr-operations']}
                <div class="sub-items">
                  <!-- HR > Operations items go here -->
                </div>
              {/if}

              <!-- ---- HR > Reports ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['hr-reports']} on:click={() => toggleSub('hr-reports')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Reports</span>
              </button>
              {#if expandedSubs['hr-reports']}
                <div class="sub-items">
                  <!-- HR > Reports > Attendance Report -->
                  <button class="nav-item" on:click={() => openWindow('hr-attendance-report', 'Attendance Report')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><path d="M8 14h.01"/><path d="M12 14h.01"/><path d="M16 14h.01"/><path d="M8 18h.01"/><path d="M12 18h.01"/></svg>
                    <span>Attendance Report</span>
                  </button>
                </div>
              {/if}
            </div>
          {/if}

          <!-- ====================================================
               MAIN SECTION: APP CONTROL
               Sub-sections: Manage | Operations | Reports
               ==================================================== -->
          <button class="nav-section" class:expanded={expandedSections.appcontrol} on:click={() => toggleSection('appcontrol')}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            <span>App Control</span>
            <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
          </button>

          {#if expandedSections.appcontrol}
            <div class="sub-sections">
              <!-- ---- App Control > Manage ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['appcontrol-manage']} on:click={() => toggleSub('appcontrol-manage')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Manage</span>
              </button>
              {#if expandedSubs['appcontrol-manage']}
                <div class="sub-items">
                  <!-- App Control > Manage > Permissions -->
                  <button class="nav-item" on:click={() => openWindow('appcontrol-permissions', 'Permissions')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                    <span>Permissions</span>
                  </button>
                  <!-- App Control > Manage > Users -->
                  <button class="nav-item" on:click={() => openWindow('appcontrol-users', 'Users')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                    <span>Users</span>
                  </button>
                </div>
              {/if}

              <!-- ---- App Control > Operations ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['appcontrol-operations']} on:click={() => toggleSub('appcontrol-operations')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Operations</span>
              </button>
              {#if expandedSubs['appcontrol-operations']}
                <div class="sub-items">
                  <!-- App Control > Operations items go here -->
                </div>
              {/if}

              <!-- ---- App Control > Reports ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['appcontrol-reports']} on:click={() => toggleSub('appcontrol-reports')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Reports</span>
              </button>
              {#if expandedSubs['appcontrol-reports']}
                <div class="sub-items">
                  <!-- App Control > Reports > Audit Logs -->
                  <button class="nav-item" on:click={() => openWindow('appcontrol-audit-log', 'Audit Logs')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                    <span>Audit Logs</span>
                  </button>
                </div>
              {/if}
            </div>
          {/if}
        </nav>

        <div class="sidebar-spacer"></div>
        <hr class="sidebar-divider" />
        <button class="logout-btn sidebar-logout" on:click={handleLogout}>Logout</button>
      </div>

      <!-- ========================================================
           MAIN CONTENT AREA + WINDOW MANAGER
           ======================================================== -->
      <div class="desktop-main">
        <!-- Centered Logo -->
        <div class="desktop-logo-center">
          <img src="/logo.jpeg" alt="CarWhizz" class="center-logo" />
          <!-- QR Attendance Widget -->
          <div class="qr-widget">
            <div class="qr-widget-label">Attendance QR</div>
            {#if qrDataUrl}
              <img src={qrDataUrl} alt="Attendance QR" class="qr-img" />
            {:else}
              <div class="qr-placeholder">Loading...</div>
            {/if}
            <div class="qr-widget-hint">Auto-refreshes every 10s</div>
          </div>
        </div>

        <div class="desktop-content">
          {#each $windowStore as win (win.id)}
            <AppWindow {win}>
              <!-- Render window content based on window ID -->
              {#if win.id === 'finance-sales'}
                <!-- Finance > Operations > Sales Window -->
                <SalesWindow />
              {:else if win.id === 'products-vehicles'}
                <!-- Products > Manage > Vehicles Window -->
                <VehiclesWindow />
              {:else if win.id === 'products-create-vehicle'}
                <!-- Products > Manage > Create Vehicle Window -->
                <CreateVehicleWindow />
              {:else if win.id.startsWith('products-edit-vehicle-')}
                <!-- Products > Manage > Edit Vehicle Window -->
                <EditVehicleWindow vehicleId={win.id.replace('products-edit-vehicle-', '')} />
              {:else if win.id === 'products-products'}
                <!-- Products > Manage > Products Window -->
                <ProductsWindow />
              {:else if win.id === 'products-create-product'}
                <!-- Products > Manage > Create Product Window -->
                <CreateProductWindow />
              {:else if win.id.startsWith('products-edit-product-')}
                <EditProductWindow productId={win.id.replace('products-edit-product-', '')} />
              {:else if win.id === 'finance-customers'}
                <!-- Finance > Manage > Customers Window -->
                <CustomersWindow />
              {:else if win.id === 'finance-create-customer'}
                <!-- Finance > Manage > Create Customer Window -->
                <CreateCustomerWindow />
              {:else if win.id === 'finance-vendors'}
                <!-- Finance > Manage > Vendors Window -->
                <VendorsWindow />
              {:else if win.id === 'finance-create-vendor'}
                <!-- Finance > Manage > Create Vendor Window -->
                <CreateVendorWindow />
              {:else if win.id === 'finance-ledger'}
                <!-- Finance > Manage > Ledger Window -->
                <LedgerWindow />
              {:else if win.id === 'finance-create-ledger'}
                <!-- Finance > Manage > Create Ledger Window -->
                <CreateLedgerWindow />
              {:else if win.id.startsWith('finance-edit-ledger-')}
                <!-- Finance > Manage > Edit Ledger Window -->
                <EditLedgerWindow ledgerId={win.id.replace('finance-edit-ledger-', '')} />
              {:else if win.id === 'finance-create-employee'}
                <!-- Finance > Manage > Create Employee Window -->
                <CreateEmployeeWindow />
              {:else if win.id === 'finance-assets'}
                <AssetsWindow />
              {:else if win.id === 'finance-create-asset'}
                <CreateAssetWindow />
              {:else if win.id === 'finance-purchase'}
                <!-- Finance > Operations > Purchase Window -->
                <PurchaseWindow />
              {:else if win.id === 'finance-receipt'}
                <!-- Finance > Operations > Receipt Window -->
                <ReceiptWindow />
              {:else if win.id === 'finance-payment'}
                <!-- Finance > Operations > Payment Window -->
                <PaymentWindow />
              {:else if win.id === 'finance-sales-report'}
                <!-- Finance > Reports > Sales Report Window -->
                <SalesReportWindow />
              {:else if win.id === 'finance-purchase-report'}
                <!-- Finance > Reports > Purchase Report Window -->
                <PurchaseReportWindow />
              {:else if win.id === 'finance-ledger-balance'}
                <!-- Finance > Reports > Ledger Balance Window -->
                <LedgerBalanceWindow />
              {:else if win.id === 'finance-day-book'}
                <DayBookWindow />
              {:else if win.id === 'finance-trial-balance'}
                <TrialBalanceWindow />
              {:else if win.id === 'finance-profit-loss'}
                <ProfitLossWindow />
              {:else if win.id === 'finance-balance-sheet'}
                <BalanceSheetWindow />
              {:else if win.id === 'appcontrol-permissions'}
                <PermissionsWindow />
              {:else if win.id === 'appcontrol-users'}
                <UsersWindow />
              {:else if win.id === 'appcontrol-audit-log'}
                <!-- App Control > Reports > Audit Logs Window -->
                <AuditLogWindow />
              {:else if win.id === 'products-stock-report'}
                <StockReportWindow />
              {:else if win.id === 'hr-attendance-report'}
                <AttendanceReportWindow />
              {/if}
            </AppWindow>
          {/each}
        </div>

        <!-- ====================================================
             TASKBAR - Bottom bar showing open windows
             ==================================================== -->
        <div class="desktop-bottom-bar">
          <div class="taskbar">
            {#each $windowStore as win (win.id)}
              <button
                class="taskbar-item"
                class:minimized={win.minimized}
                on:click={() => {
                  if (win.minimized) {
                    windowStore.open(win.id, win.title);
                  } else {
                    windowStore.focus(win.id);
                  }
                }}
              >
                {win.title}
              </button>
            {/each}
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .dashboard {
    min-height: 100vh;
    background: linear-gradient(135deg, #fff7ed 0%, #f0f9ff 50%, #f0fdf4 100%);
    position: relative;
  }

  /* ========== LOGOUT BUTTON ========== */
  .logout-btn {
    background: linear-gradient(135deg, #ea580c, #dc2626);
    color: white;
    border: none;
    padding: 10px 16px;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.25s;
    box-shadow: 0 4px 12px rgba(234, 88, 12, 0.35);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .logout-btn:hover {
    background: linear-gradient(135deg, #c2410c, #b91c1c);
    transform: translateY(-1px);
    box-shadow: 0 6px 16px rgba(234, 88, 12, 0.45);
  }

  /* ========== MOBILE LAYOUT ========== */
  .mobile-layout {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  .mobile-top-bar {
    height: 56px;
    background: linear-gradient(135deg, #ea580c, #f97316);
    border-bottom: none;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 16px;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
    box-shadow: 0 4px 20px rgba(234, 88, 12, 0.3);
  }

  .top-bar-logo {
    height: 36px;
    width: auto;
    object-fit: contain;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  }

  .mobile-content {
    flex: 1;
    margin-top: 56px;
    margin-bottom: 64px;
    padding: 16px;
  }

  .mobile-bottom-bar {
    height: 64px;
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-top: 1px solid rgba(234, 88, 12, 0.15);
    display: flex;
    align-items: center;
    justify-content: space-around;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 100;
    box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.08);
  }

  .bottom-bar-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    font-size: 11px;
    color: #6b7280;
    cursor: pointer;
    padding: 6px 14px;
    background: none;
    border: none;
    border-radius: 12px;
    transition: all 0.2s;
    -webkit-tap-highlight-color: transparent;
  }

  .bottom-bar-item.active {
    color: #ea580c;
    background: rgba(234, 88, 12, 0.1);
  }

  .bottom-bar-item svg {
    width: 24px;
    height: 24px;
  }

  .placeholder-icon {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    background: rgba(234, 88, 12, 0.1);
  }

  /* ========== MOBILE DASHBOARD CARDS ========== */
  .sr-only { position:absolute; width:1px; height:1px; padding:0; margin:-1px; overflow:hidden; clip:rect(0,0,0,0); border:0; }
  .m-date-nav {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 12px;
    margin-bottom: 16px;
  }
  .m-date-btn {
    background: rgba(255, 255, 255, 0.7);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    border: 1px solid rgba(234, 88, 12, 0.2);
    border-radius: 10px;
    padding: 6px 10px;
    cursor: pointer;
    color: #ea580c;
    display: flex;
    align-items: center;
    transition: all 0.2s;
  }
  .m-date-btn:hover { background: rgba(255, 255, 255, 0.9); }
  .m-date-label {
    font-size: 15px;
    font-weight: 700;
    color: #111827;
    min-width: 110px;
    text-align: center;
  }
  .m-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 200px;
    color: #9ca3af;
    font-size: 14px;
  }
  .m-cards {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .m-card {
    background: rgba(255, 255, 255, 0.6);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border-radius: 16px;
    padding: 16px 14px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.06), inset 0 1px 0 rgba(255,255,255,0.8);
    display: flex;
    flex-direction: column;
    gap: 4px;
    border: 1px solid rgba(255,255,255,0.5);
    border-left: 4px solid transparent;
    transition: transform 0.2s, box-shadow 0.2s;
  }
  .m-card:active { transform: scale(0.97); }
  .m-card.sales { border-left-color: #22c55e; background: rgba(240, 253, 244, 0.65); }
  .m-card.purchase { border-left-color: #3b82f6; background: rgba(239, 246, 255, 0.65); }
  .m-card.expense { border-left-color: #ef4444; background: rgba(254, 242, 242, 0.65); }
  .m-card.cash { border-left-color: #f59e0b; background: rgba(255, 251, 235, 0.65); }
  .m-card.bank { border-left-color: #8b5cf6; background: rgba(245, 243, 255, 0.65); }
  .m-card.sales-bal { border-left-color: #06b6d4; background: rgba(236, 254, 255, 0.65); }
  .m-card.purchase-bal { border-left-color: #e11d48; background: rgba(255, 241, 242, 0.65); }
  .m-card-icon {
    width: 40px;
    height: 40px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 4px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  }
  .m-card.sales .m-card-icon { background: linear-gradient(135deg, #22c55e, #16a34a); color: white; }
  .m-card.purchase .m-card-icon { background: linear-gradient(135deg, #3b82f6, #2563eb); color: white; }
  .m-card.expense .m-card-icon { background: linear-gradient(135deg, #ef4444, #dc2626); color: white; }
  .m-card.cash .m-card-icon { background: linear-gradient(135deg, #f59e0b, #d97706); color: white; }
  .m-card.bank .m-card-icon { background: linear-gradient(135deg, #8b5cf6, #7c3aed); color: white; }
  .m-card.sales-bal .m-card-icon { background: linear-gradient(135deg, #06b6d4, #0891b2); color: white; }
  .m-card.purchase-bal .m-card-icon { background: linear-gradient(135deg, #e11d48, #be123c); color: white; }
  .m-card-label {
    font-size: 11px;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
  .m-card-amount {
    font-size: 18px;
    font-weight: 800;
    color: #111827;
    line-height: 1.2;
  }
  .m-card-sub {
    font-size: 11px;
    color: #9ca3af;
  }

  /* ========== DESKTOP LAYOUT ========== */
  .desktop-layout {
    display: flex;
    min-height: 100vh;
  }

  .desktop-sidebar {
    width: 200px;
    background: linear-gradient(180deg, #ea580c 0%, #c2410c 60%, #9a3412 100%);
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 20px 14px;
    position: fixed;
    top: 0;
    left: 0;
    bottom: 48px;
    z-index: 100;
    box-shadow: 4px 0 24px rgba(234, 88, 12, 0.25);
    overflow-y: auto;
  }

  .sidebar-divider {
    width: 100%;
    border: none;
    border-top: 1px solid rgba(255, 255, 255, 0.2);
    margin: 12px 0;
  }

  .sidebar-nav {
    width: 100%;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
  }

  .nav-section {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding: 11px 14px;
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 12px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 700;
    color: rgba(255, 255, 255, 0.95);
    transition: all 0.2s;
    text-align: left;
    margin-bottom: 4px;
  }

  .nav-section:hover {
    background: rgba(255, 255, 255, 0.2);
    transform: translateX(2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .nav-section.expanded {
    background: rgba(255, 255, 255, 0.25);
    border-color: rgba(255, 255, 255, 0.3);
    color: white;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2), inset 0 1px 0 rgba(255,255,255,0.3);
  }

  .nav-section > svg:first-child {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }

  .nav-section > span {
    flex: 1;
  }

  .chevron {
    width: 16px;
    height: 16px;
    flex-shrink: 0;
    transition: transform 0.2s;
  }

  .nav-section.expanded .chevron {
    transform: rotate(180deg);
  }

  .sub-sections {
    display: flex;
    flex-direction: column;
    padding-left: 10px;
    margin-bottom: 4px;
  }

  .nav-sub {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 8px 12px;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid transparent;
    border-radius: 10px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.75);
    transition: all 0.2s;
    text-align: left;
    margin-bottom: 2px;
  }

  .nav-sub:hover {
    background: rgba(255, 255, 255, 0.12);
    color: white;
  }

  .nav-sub.expanded {
    color: white;
    background: rgba(255, 255, 255, 0.15);
    border-color: rgba(255, 255, 255, 0.15);
  }

  .chevron-sm {
    width: 14px;
    height: 14px;
    flex-shrink: 0;
    transition: transform 0.2s;
  }

  .nav-sub.expanded .chevron-sm {
    transform: rotate(180deg);
  }

  .sub-items {
    display: flex;
    flex-direction: column;
    padding-left: 16px;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 8px 12px;
    background: none;
    border: 1px solid transparent;
    border-radius: 10px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.7);
    transition: all 0.2s;
    text-align: left;
    margin-bottom: 1px;
  }

  .nav-item:hover {
    background: rgba(255, 255, 255, 0.15);
    color: white;
    border-color: rgba(255, 255, 255, 0.15);
    transform: translateX(3px);
  }

  .nav-item svg {
    width: 15px;
    height: 15px;
    flex-shrink: 0;
  }

  .sidebar-spacer {
    flex: 1;
  }

  .sidebar-logout {
    width: 100%;
    padding: 12px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.15) !important;
    border: 1px solid rgba(255, 255, 255, 0.25) !important;
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .sidebar-logout:hover {
    background: rgba(255, 255, 255, 0.25) !important;
  }

  .desktop-main {
    flex: 1;
    margin-left: 200px;
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    position: relative;
  }

  .desktop-logo-center {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    pointer-events: none;
    opacity: 1;
    z-index: 0;
  }

  .center-logo {
    max-width: 60%;
    max-height: 50%;
    object-fit: contain;
  }

  .desktop-content {
    flex: 1;
    padding: 24px;
    padding-bottom: 72px;
    position: relative;
    overflow: hidden;
  }

  .desktop-bottom-bar {
    height: 48px;
    background: rgba(255, 255, 255, 0.75);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-top: 1px solid rgba(234, 88, 12, 0.12);
    box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.06);
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 200;
    display: flex;
    align-items: center;
    padding: 0 8px;
  }

  .taskbar {
    display: flex;
    align-items: center;
    gap: 4px;
    overflow-x: auto;
    padding: 4px 0;
  }

  .taskbar-item {
    padding: 6px 14px;
    background: rgba(255, 255, 255, 0.6);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    border: 1px solid rgba(234, 88, 12, 0.15);
    border-radius: 10px;
    font-size: 12px;
    font-weight: 600;
    color: #374151;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
    box-shadow: 0 2px 6px rgba(0,0,0,0.04);
  }

  .taskbar-item:hover {
    background: linear-gradient(135deg, rgba(234, 88, 12, 0.1), rgba(249, 115, 22, 0.1));
    border-color: #f97316;
    color: #ea580c;
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(234, 88, 12, 0.15);
  }

  .taskbar-item.minimized {
    opacity: 0.5;
    border-style: dashed;
  }

  /* ========== QR WIDGET (DESKTOP) ========== */
  .qr-widget {
    pointer-events: auto;
    background: rgba(255, 255, 255, 0.7);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border: 1px solid rgba(234, 88, 12, 0.15);
    border-radius: 18px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    align-items: center;
    box-shadow: 0 8px 32px rgba(234, 88, 12, 0.12), inset 0 1px 0 rgba(255,255,255,0.8);
  }
  .qr-widget-label {
    font-size: 11px;
    font-weight: 700;
    color: #ea580c;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 6px;
  }
  .qr-img { width: 140px; height: 140px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
  .qr-placeholder { width: 140px; height: 140px; display: flex; align-items: center; justify-content: center; color: #9ca3af; font-size: 12px; }
  .qr-widget-hint { font-size: 9px; color: #9ca3af; margin-top: 4px; }

  /* ========== QR SCANNER (MOBILE) ========== */
  .qr-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    z-index: 999;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .qr-scanner-box {
    background: rgba(255, 255, 255, 0.9);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-radius: 20px;
    padding: 20px;
    width: 300px;
    max-width: 90vw;
    box-shadow: 0 16px 48px rgba(0,0,0,0.2);
    border: 1px solid rgba(255,255,255,0.8);
  }
  .qr-scanner-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 10px;
  }
  .qr-scanner-header h3 { font-size: 16px; font-weight: 700; color: #ea580c; margin: 0; }
  .qr-close-btn {
    background: rgba(234, 88, 12, 0.1);
    border: none;
    font-size: 20px;
    cursor: pointer;
    color: #ea580c;
    line-height: 1;
    width: 32px;
    height: 32px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
  }
  .qr-close-btn:hover { background: rgba(234, 88, 12, 0.2); }
  .qr-msg { text-align: center; color: #6b7280; font-size: 13px; margin-top: 8px; }

  /* ========== SCAN TOAST ========== */
  .scan-toast {
    position: fixed;
    bottom: 80px;
    left: 50%;
    transform: translateX(-50%);
    padding: 12px 24px;
    border-radius: 14px;
    font-size: 14px;
    font-weight: 600;
    z-index: 200;
    cursor: pointer;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    animation: toastSlide 0.3s ease;
  }
  .scan-toast.success { background: rgba(220, 252, 231, 0.9); color: #166534; border: 1px solid rgba(34, 197, 94, 0.3); }
  .scan-toast.error { background: rgba(254, 226, 226, 0.9); color: #991b1b; border: 1px solid rgba(239, 68, 68, 0.3); }
  @keyframes toastSlide { from { opacity: 0; transform: translateX(-50%) translateY(10px); } to { opacity: 1; transform: translateX(-50%) translateY(0); } }
</style>
