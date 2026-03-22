<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../stores/authStore';
  import { logout } from '../lib/services/authService';
  import { canUserViewResources } from '../lib/services/permissionService';
  import { interfaceStore } from '../stores/interfaceStore';
  import { windowStore } from '../stores/windowStore';
  import { supabase } from '../lib/supabaseClient';
  import { tick } from 'svelte';
  import AppWindow from './AppWindow.svelte';
  import SalesWindow from './windows/finance/operations/SalesWindow.svelte';
  import PurchaseWindow from './windows/finance/operations/PurchaseWindow.svelte';
  import SalesReturnWindow from './windows/finance/operations/SalesReturnWindow.svelte';
  import PurchaseReturnWindow from './windows/finance/operations/PurchaseReturnWindow.svelte';
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
  import JobCardWindow from './windows/finance/manage/JobCardWindow.svelte';
  import JobCardReportWindow from './windows/finance/reports/JobCardReportWindow.svelte';
  import MyJobCardsWindow from './windows/finance/manage/MyJobCardsWindow.svelte';
  import { createEventDispatcher } from 'svelte';
  import { onDestroy } from 'svelte';
  import QRCode from 'qrcode';

  const dispatch = createEventDispatcher();

  // Sidebar section collapse state
  let expandedSections: Record<string, boolean> = { finance: true, products: true, appcontrol: true, hr: true };
  let expandedSubs: Record<string, boolean> = {
    'finance-manage': true,
    'finance-operations': true,
    'finance-reports': true,
    'products-manage': true,
    'products-operations': true,
    'products-reports': true,
    'hr-manage': true,
    'hr-operations': true,
    'hr-reports': true,
    'appcontrol-manage': true,
    'appcontrol-operations': true,
    'appcontrol-reports': true,
  };

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
  let showPunchChoice = false;
  let scannedToken = '';
  let scanResult = '';
  let scanError = '';
  let scanLoading = false;
  let html5QrScanner: any = null;

  async function startScanner() {
    scanResult = '';
    scanError = '';
    showPunchChoice = false;
    scannedToken = '';
    showScanner = true;
    // Wait for Svelte DOM update
    await tick();
    await new Promise(r => setTimeout(r, 500));

    const readerEl = document.getElementById('qr-reader');
    if (!readerEl) { scanError = 'Scanner element not found.'; showScanner = false; return; }

    try {
      let Html5Qrcode;
      try {
        ({ Html5Qrcode } = await import('html5-qrcode'));
      } catch (importErr: any) {
        // Fallback: retry import after delay if it fails
        console.error('Initial import failed, retrying...', importErr);
        await new Promise(r => setTimeout(r, 1000));
        ({ Html5Qrcode } = await import('html5-qrcode'));
      }
      
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
      const errMsg = err?.message || err?.toString() || 'Camera access denied or not available.';
      console.error('Scanner error:', errMsg, err);
      scanError = errMsg.includes('Failed to fetch') ? 'Network error: Failed to load camera module. Check your internet connection.' : errMsg;
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
      scannedToken = payload.t;
      if (!$authStore.user?.id) { scanError = 'Not logged in.'; scanLoading = false; return; }
      // Show check-in / check-out choice popup
      showPunchChoice = true;
    } catch {
      scanError = 'Invalid QR code.';
    }
    scanLoading = false;
  }

  async function doPunch(action: 'check_in' | 'check_out') {
    showPunchChoice = false;
    scanLoading = true;
    try {
      const userId = $authStore.user?.id;
      if (!userId) { scanError = 'Not logged in.'; scanLoading = false; return; }

      const { data, error } = await supabase.rpc('fn_attendance_punch', {
        p_token: scannedToken,
        p_user_id: userId,
        p_action: action
      });
      if (error) { scanError = error.message; }
      else if (data?.success) { scanResult = data.message; }
      else { scanError = data?.message || 'Punch failed.'; }
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
  let mobilePage: 'home' | 'jobs' | 'attendance' = 'home';
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
  let attendanceCheckIn: string | null = null;
  let attendanceCheckOut: string | null = null;
  let attendancePunches: { check_in: string | null; check_out: string | null; punch_order: number }[] = [];
  let attendanceTotalHours = '';
  let totalPresent = 0;
  let totalEmployees = 0;
  let mobileLoading = true;

  // ---- Mobile Dashboard Card Permissions ----
  let cardPermissions = new Map<string, boolean>();
  const mobileCardResources = [
    'mobile-dashboard-sales',
    'mobile-dashboard-purchase',
    'mobile-dashboard-expense',
    'mobile-dashboard-cash-balance',
    'mobile-dashboard-bank-balance',
    'mobile-dashboard-sales-balance',
    'mobile-dashboard-purchase-balance'
  ];

  async function loadMobileCardPermissions() {
    const userId = $authStore.user?.id;
    if (!userId) return;

    const permissions = await canUserViewResources(userId, mobileCardResources);
    cardPermissions = permissions;
  }

  function canShowCard(cardResource: string): boolean {
    return cardPermissions.get(cardResource) ?? false;
  }

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

  function formatTime(ts: string | null): string {
    if (!ts) return '--:--';
    const d = new Date(ts);
    return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
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

    // Load attendance for today
    attendanceCheckIn = null;
    attendanceCheckOut = null;
    attendancePunches = [];
    attendanceTotalHours = '';
    const userId = $authStore.user?.id;
    if (userId) {
      const { data: attList } = await supabase
        .from('attendance')
        .select('check_in, check_out, punch_order')
        .eq('user_id', userId)
        .eq('date', mobileDate)
        .order('punch_order', { ascending: true });
      if (attList && attList.length > 0) {
        attendancePunches = attList;
        // First check-in and latest check-out for summary
        attendanceCheckIn = attList[0].check_in;
        const lastCompleted = [...attList].reverse().find(p => p.check_out);
        attendanceCheckOut = lastCompleted?.check_out || null;
        // Calculate total worked hours
        let totalMs = 0;
        for (const p of attList) {
          if (p.check_in && p.check_out) {
            totalMs += new Date(p.check_out).getTime() - new Date(p.check_in).getTime();
          }
        }
        if (totalMs > 0) {
          const hrs = Math.floor(totalMs / 3600000);
          const mins = Math.floor((totalMs % 3600000) / 60000);
          attendanceTotalHours = `${hrs}h ${mins}m`;
        }
      }
    }

    // Load total present employees
    const { count: presentCount } = await supabase
      .from('attendance')
      .select('id', { count: 'exact', head: true })
      .eq('date', mobileDate)
      .not('check_in', 'is', null);
    totalPresent = presentCount || 0;

    const { count: empCount } = await supabase
      .from('users')
      .select('id', { count: 'exact', head: true });
    totalEmployees = empCount || 0;

    mobileLoading = false;
  }

  // ---- Mobile Job Cards ----
  let mobileJobs: any[] = [];
  let mobileJobsLoading = true;
  let mobileJobStatusFilter = '';
  let mobileViewingJob: any = null;
  let mjItems: any[] = [];
  let mjPhotos: any[] = [];
  let mjNotes: any[] = [];
  let mjLogs: any[] = [];
  let mjNewNote = '';
  let mjNoteSaving = false;
  let mjPhotoUploading = false;
  let mjPhotoError = '';
  let mjActionLoading = false;
  let mjActionError = '';
  let mjProducts: any[] = [];
  let mjProductSearch = '';
  let mjFilteredProducts: any[] = [];
  let mjShowProductDropdown = false;
  let mjSelectedProduct: any = null;
  let mjItemQty = 1;
  let mjItemPrice = '';
  let mjItemNotes = '';
  let mjItemSaving = false;
  let mjItemError = '';
  let mjDeletingItemId: string | null = null;

  $: mobileFilteredJobs = mobileJobStatusFilter ? mobileJobs.filter(j => j.status === mobileJobStatusFilter) : mobileJobs;

  async function loadMobileJobs() {
    mobileJobsLoading = true;
    const userId = $authStore.user?.id;
    if (!userId) { mobileJobsLoading = false; return; }
    const { data } = await supabase
      .from('job_cards')
      .select('id, job_card_no, status, priority, description, details, expected_date, created_at, customer_id, customers(name, place, gender), vehicles(model_name, makes(name), variants(name), gearboxes(name), fuel_types(name), body_sides(name))')
      .eq('assigned_user_id', userId)
      .in('status', ['Open', 'In Progress'])
      .order('created_at', { ascending: false });
    
    // Load vehicle numbers for all customers
    const { data: vehicleNumbers } = await supabase
      .from('customer_vehicle_numbers')
      .select('customer_id, vehicle_number');
    
    const vehicleNumbersByCustomer: { [key: string]: string[] } = {};
    (vehicleNumbers || []).forEach((vn: any) => {
      if (!vehicleNumbersByCustomer[vn.customer_id]) {
        vehicleNumbersByCustomer[vn.customer_id] = [];
      }
      vehicleNumbersByCustomer[vn.customer_id].push(vn.vehicle_number);
    });
    
    mobileJobs = (data || []).map((j: any) => {
      const v = j.vehicles;
      const parts = [v?.model_name, v?.makes?.name, v?.variants?.name, v?.fuel_types?.name, v?.gearboxes?.name].filter(Boolean);
      return {
        ...j,
        customer_name: j.customers?.name || '—',
        customer_place: j.customers?.place || '',
        customer_gender: j.customers?.gender || '',
        vehicle_name: parts.join(' • ') || '—',
        vehicle_model: v?.model_name || '—',
        vehicle_make: v?.makes?.name || '',
        vehicle_variant: v?.variants?.name || '',
        vehicle_fuel: v?.fuel_types?.name || '',
        vehicle_gearbox: v?.gearboxes?.name || '',
        vehicle_body: v?.body_sides?.name || '',
        vehicle_numbers: vehicleNumbersByCustomer[j.customer_id] || [],
      };
    });
    mobileJobsLoading = false;
  }

  async function openMobileJobDetail(job: any) {
    mobileViewingJob = job;
    mjActionError = '';
    const [itemsRes, photosRes, notesRes, logsRes] = await Promise.all([
      supabase.from('job_card_items').select('*').eq('job_card_id', job.id).order('created_at'),
      supabase.from('job_card_photos').select('*').eq('job_card_id', job.id).order('created_at'),
      supabase.from('job_card_notes').select('*, users:created_by(email, user_name)').eq('job_card_id', job.id).order('created_at', { ascending: false }),
      supabase.from('job_card_logs').select('*, users:action_by(email, user_name)').eq('job_card_id', job.id).order('created_at', { ascending: false }),
    ]);
    mjItems = itemsRes.data || [];
    mjPhotos = photosRes.data || [];
    mjNotes = (notesRes.data || []).map((n: any) => ({ ...n, by_name: n.users?.user_name || n.users?.email || '—' }));
    mjLogs = (logsRes.data || []).map((l: any) => ({ ...l, by_name: l.users?.user_name || l.users?.email || '—' }));
  }

  function closeMobileJobDetail() {
    mobileViewingJob = null;
    mjItems = []; mjPhotos = []; mjNotes = []; mjLogs = [];
    mjNewNote = '';
  }

  async function mjStartJob() {
    if (!mobileViewingJob || mobileViewingJob.status !== 'Open') return;
    mjActionLoading = true; mjActionError = '';
    const { error } = await supabase.from('job_cards').update({ status: 'In Progress', updated_by: $authStore.user?.id || null, updated_at: new Date().toISOString() }).eq('id', mobileViewingJob.id);
    if (error) { mjActionError = error.message; mjActionLoading = false; return; }
    await supabase.from('job_card_logs').insert({ job_card_id: mobileViewingJob.id, action: 'Started', from_status: 'Open', to_status: 'In Progress', note: 'Job started', action_by: $authStore.user?.id || null, created_by: $authStore.user?.id || null });
    mobileViewingJob = { ...mobileViewingJob, status: 'In Progress' };
    mjActionLoading = false;
    loadMobileJobs();
    await openMobileJobDetail(mobileViewingJob);
  }

  async function mjCloseJob() {
    if (!mobileViewingJob || mobileViewingJob.status !== 'In Progress') return;
    if (!confirm('Close this job card?')) return;
    mjActionLoading = true; mjActionError = '';
    const { error } = await supabase.from('job_cards').update({ status: 'Closed', closed_by: $authStore.user?.id || null, closed_at: new Date().toISOString(), updated_by: $authStore.user?.id || null, updated_at: new Date().toISOString() }).eq('id', mobileViewingJob.id);
    if (error) { mjActionError = error.message; mjActionLoading = false; return; }
    await supabase.from('job_card_logs').insert({ job_card_id: mobileViewingJob.id, action: 'Closed', from_status: 'In Progress', to_status: 'Closed', note: 'Job completed and closed', action_by: $authStore.user?.id || null, created_by: $authStore.user?.id || null });
    mobileViewingJob = { ...mobileViewingJob, status: 'Closed' };
    mjActionLoading = false;
    loadMobileJobs();
    await openMobileJobDetail(mobileViewingJob);
  }

  async function mjAddNote() {
    if (!mjNewNote.trim() || !mobileViewingJob) return;
    mjNoteSaving = true;
    await supabase.from('job_card_notes').insert({ job_card_id: mobileViewingJob.id, note: mjNewNote.trim(), created_by: $authStore.user?.id || null });
    await supabase.from('job_card_logs').insert({ job_card_id: mobileViewingJob.id, action: 'Note Added', note: mjNewNote.trim().substring(0, 100), action_by: $authStore.user?.id || null, created_by: $authStore.user?.id || null });
    mjNewNote = '';
    mjNoteSaving = false;
    await openMobileJobDetail(mobileViewingJob);
  }

  async function mjHandlePhotoUpload(e: Event) {
    const input = e.target as HTMLInputElement;
    const files = input.files;
    if (!files || files.length === 0 || !mobileViewingJob) return;
    mjPhotoUploading = true; mjPhotoError = '';
    for (const file of Array.from(files)) {
      const ext = file.name.split('.').pop() || 'jpg';
      const fileName = `${mobileViewingJob.id}/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;
      const { error: uploadErr } = await supabase.storage.from('job-card-photos').upload(fileName, file);
      if (uploadErr) { mjPhotoError = 'Upload failed: ' + uploadErr.message; continue; }
      const { data: urlData } = supabase.storage.from('job-card-photos').getPublicUrl(fileName);
      if (urlData?.publicUrl) {
        await supabase.from('job_card_photos').insert({ job_card_id: mobileViewingJob.id, file_url: urlData.publicUrl, file_name: file.name, uploaded_by: $authStore.user?.id || null, created_by: $authStore.user?.id || null });
      }
    }
    mjPhotoUploading = false;
    input.value = '';
    await openMobileJobDetail(mobileViewingJob);
  }

  // ---- Load Products (Mobile) ----
  async function loadMobileProducts() {
    const { data } = await supabase
      .from('products')
      .select('id, product_name, product_type, sales_price')
      .order('product_name');
    mjProducts = data || [];
  }

  function handleMobileProductSearch() {
    const q = mjProductSearch.toLowerCase().trim();
    if (!q) { mjFilteredProducts = []; mjShowProductDropdown = false; return; }
    mjFilteredProducts = mjProducts.filter(p =>
      p.product_name.toLowerCase().includes(q) || (p.product_type || '').toLowerCase().includes(q)
    ).slice(0, 8);
    mjShowProductDropdown = mjFilteredProducts.length > 0;
  }

  function selectMobileProduct(p: any) {
    mjSelectedProduct = p;
    mjProductSearch = p.product_name;
    mjItemPrice = (p.sales_price || 0).toString();
    mjShowProductDropdown = false;
  }

  // ---- Add Item to Mobile Job ----
  async function mjAddItem() {
    if (!mobileViewingJob || !mjSelectedProduct || mjItemQty <= 0 || !mjItemPrice) {
      mjItemError = 'Select product and set qty/price';
      return;
    }
    mjItemSaving = true;
    mjItemError = '';

    const qty = Number(mjItemQty);
    const price = Number(mjItemPrice);
    const total = qty * price;

    const { error } = await supabase.from('job_card_items').insert({
      job_card_id: mobileViewingJob.id,
      item_type: mjSelectedProduct.product_type || 'product',
      item_id: mjSelectedProduct.id,
      name: mjSelectedProduct.product_name,
      qty: qty,
      price: price,
      total: total,
      discount: 0,
      notes: mjItemNotes || '',
      created_by: $authStore.user?.id || null,
    });

    if (error) {
      mjItemError = 'Failed to add: ' + error.message;
      mjItemSaving = false;
      return;
    }

    mjSelectedProduct = null;
    mjProductSearch = '';
    mjItemQty = 1;
    mjItemPrice = '';
    mjItemNotes = '';
    mjShowProductDropdown = false;
    mjItemSaving = false;
    await openMobileJobDetail(mobileViewingJob);
  }

  // ---- Remove Item from Mobile Job ----
  async function mjRemoveItem(itemId: string) {
    if (!confirm('Remove this item?')) return;
    mjDeletingItemId = itemId;

    const { error } = await supabase
      .from('job_card_items')
      .delete()
      .eq('id', itemId);

    if (error) {
      alert('Failed: ' + error.message);
      mjDeletingItemId = null;
      return;
    }

    mjDeletingItemId = null;
    await openMobileJobDetail(mobileViewingJob);
  }

  function formatMobileDate(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  }

  function formatMobileDateTime(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    let h = d.getHours(); const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM'; h = h % 12 || 12;
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')} ${h}:${min} ${ampm}`;
  }

  function mjStatusClass(s: string): string {
    return { 'Open': 'mj-open', 'In Progress': 'mj-progress', 'Closed': 'mj-closed' }[s] || '';
  }

  function mjPriClass(p: string): string {
    return { 'Low': 'mj-pri-low', 'Normal': 'mj-pri-normal', 'High': 'mj-pri-high', 'Urgent': 'mj-pri-urgent' }[p] || '';
  }

  onMount(() => {
    if ($interfaceStore === 'mobile') {
      loadMobileCardPermissions();
      loadMobileData();
    }
    if ($interfaceStore === 'desktop') startQRTimer();
  });

  onDestroy(() => { stopQRTimer(); });

  // Reload when switching to mobile
  $: if ($interfaceStore === 'mobile') { 
    loadMobileCardPermissions();
    loadMobileData();
    loadMobileProducts();
    stopQRTimer(); 
  }
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
        {#if mobilePage === 'home'}
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
            {#if canShowCard('mobile-dashboard-sales')}
              <div class="m-card sales">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>
                </div>
                <div class="m-card-label">Sales</div>
                <div class="m-card-amount">{formatMobileAmt(salesToday)}</div>
                <div class="m-card-sub">{salesCount} bill{salesCount !== 1 ? 's' : ''}</div>
              </div>
            {/if}

            <!-- Purchase Card -->
            {#if canShowCard('mobile-dashboard-purchase')}
              <div class="m-card purchase">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>
                </div>
                <div class="m-card-label">Purchase</div>
                <div class="m-card-amount">{formatMobileAmt(purchaseToday)}</div>
                <div class="m-card-sub">{purchaseCount} invoice{purchaseCount !== 1 ? 's' : ''}</div>
              </div>
            {/if}

            <!-- Expense Card -->
            {#if canShowCard('mobile-dashboard-expense')}
              <div class="m-card expense">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" width="22" height="22"><text x="12" y="18" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor" stroke="none">₹</text></svg>
                </div>
                <div class="m-card-label">Expenses</div>
                <div class="m-card-amount">{formatMobileAmt(expenseToday)}</div>
                <div class="m-card-sub">{expenseCount} entr{expenseCount !== 1 ? 'ies' : 'y'}</div>
              </div>
            {/if}

            <!-- Cash Balance Card -->
            {#if canShowCard('mobile-dashboard-cash-balance')}
              <div class="m-card cash">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M12 8v8"/><path d="M8 12h8"/></svg>
                </div>
                <div class="m-card-label">Cash Balance</div>
                <div class="m-card-amount">{formatMobileAmt(cashBalance)}</div>
                <div class="m-card-sub">All cash ledgers</div>
              </div>
            {/if}

            <!-- Bank Balance Card -->
            {#if canShowCard('mobile-dashboard-bank-balance')}
              <div class="m-card bank">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M3 21h18"/><path d="M3 10h18"/><path d="M12 3l9 7H3l9-7z"/><path d="M5 10v11"/><path d="M19 10v11"/><path d="M9 10v11"/><path d="M15 10v11"/></svg>
                </div>
                <div class="m-card-label">Bank Balance</div>
                <div class="m-card-amount">{formatMobileAmt(bankBalance)}</div>
                <div class="m-card-sub">All bank ledgers</div>
              </div>
            {/if}

            <!-- Sales Balance Card -->
            {#if canShowCard('mobile-dashboard-sales-balance')}
              <div class="m-card sales-bal">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                </div>
                <div class="m-card-label">Sales Balance</div>
                <div class="m-card-amount">{formatMobileAmt(salesBalanceTotal)}</div>
                <div class="m-card-sub">Total receivable</div>
              </div>
            {/if}

            <!-- Purchase Balance Card -->
            {#if canShowCard('mobile-dashboard-purchase-balance')}
              <div class="m-card purchase-bal">
                <div class="m-card-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/><line x1="9" y1="12" x2="15" y2="12"/><line x1="9" y1="16" x2="15" y2="16"/></svg>
                </div>
                <div class="m-card-label">Purchase Balance</div>
                <div class="m-card-amount">{formatMobileAmt(purchaseBalanceTotal)}</div>
                <div class="m-card-sub">Total payable</div>
              </div>

              <!-- Attendance Card -->
            <div class="m-card attendance">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><polyline points="9 16 11 18 15 14"/></svg>
              </div>
              <div class="m-card-label">Attendance</div>
              {#if attendancePunches.length > 0}
                <div class="m-card-punches">
                  {#each attendancePunches as p}
                    <div class="punch-row">
                      <span class="attend-in">In: {formatTime(p.check_in)}</span>
                      <span class="attend-out">Out: {p.check_out ? formatTime(p.check_out) : '—'}</span>
                    </div>
                  {/each}
                </div>
                {#if attendanceTotalHours}
                  <div class="m-card-sub total-hrs">Total: {attendanceTotalHours}</div>
                {/if}
              {:else}
                <div class="m-card-attend-row">
                  <span class="attend-in">In: —</span>
                  <span class="attend-out">Out: —</span>
                </div>
              {/if}
              <div class="m-card-sub">
                {#if attendancePunches.length === 0}
                  Not checked in
                {:else if attendancePunches.some(p => p.check_in && !p.check_out)}
                  Working ({attendancePunches.length} punch{attendancePunches.length > 1 ? 'es' : ''})
                {:else}
                  Completed ({attendancePunches.length} punch{attendancePunches.length > 1 ? 'es' : ''})
                {/if}
              </div>
            </div>

            <!-- Staff Present Card -->
            <div class="m-card staff-present">
              <div class="m-card-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
              </div>
              <div class="m-card-label">Staff Present</div>
              <div class="m-card-amount">{totalPresent} / {totalEmployees}</div>
              <div class="m-card-sub">{totalEmployees - totalPresent} absent</div>
            </div>
            {/if}
          </div>
        {/if}
        {:else if mobilePage === 'jobs'}
        <!-- ============================================================
             MOBILE JOB CARDS PAGE
             ============================================================ -->
        {#if !mobileViewingJob}
          <!-- Job List View -->
          <div class="mj-header">
            <button class="mj-back-btn" aria-label="Back to home" on:click={() => mobilePage = 'home'}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><polyline points="15 18 9 12 15 6"/></svg>
            </button>
            <h2 class="mj-title">My Job Cards</h2>
            <select class="mj-filter" bind:value={mobileJobStatusFilter}>
              <option value="">All</option>
              <option value="Open">Open</option>
              <option value="In Progress">In Progress</option>
              <option value="Closed">Closed</option>
            </select>
            <button class="mj-refresh-btn" aria-label="Refresh" on:click={loadMobileJobs}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
            </button>
          </div>

          {#if mobileJobsLoading}
            <div class="m-loading">Loading jobs...</div>
          {:else if mobileFilteredJobs.length === 0}
            <div class="mj-empty">No job cards found.</div>
          {:else}
            <div class="mj-list">
              {#each mobileFilteredJobs as job}
                <button class="mj-card" on:click={() => openMobileJobDetail(job)}>
                  <div class="mj-card-top">
                    <span class="mj-card-no">{job.job_card_no}</span>
                    <span class="mj-badge {mjStatusClass(job.status)}">{job.status}</span>
                  </div>
                  <div class="mj-card-customer">{job.customer_name}</div>
                  {#if job.vehicle_numbers && job.vehicle_numbers.length > 0}
                    <div class="mj-vehicle-numbers">
                      {#each job.vehicle_numbers as vn}
                        <span class="mj-vehicle-number">{vn}</span>
                      {/each}
                    </div>
                  {/if}
                  <div class="mj-card-vehicle">{job.vehicle_name}</div>
                  {#if job.description}
                    <div class="mj-card-desc">{job.description}</div>
                  {/if}
                  <div class="mj-card-bottom">
                    <span class="mj-pri {mjPriClass(job.priority)}">{job.priority}</span>
                    <span class="mj-card-date">{formatMobileDate(job.created_at)}</span>
                  </div>
                </button>
              {/each}
            </div>
          {/if}
        {:else}
          <!-- Job Detail View -->
          <div class="mj-header">
            <button class="mj-back-btn" aria-label="Back to list" on:click={closeMobileJobDetail}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><polyline points="15 18 9 12 15 6"/></svg>
            </button>
            <h2 class="mj-title">{mobileViewingJob.job_card_no}</h2>
            <span class="mj-badge {mjStatusClass(mobileViewingJob.status)}">{mobileViewingJob.status}</span>
          </div>

          <div class="mj-detail-scroll">
            <!-- Info -->
            <div class="mj-info-grid">
              <div class="mj-info-item"><span class="mj-info-label">Customer</span><span class="mj-info-value">{mobileViewingJob.customer_name}</span></div>
              {#if mobileViewingJob.customer_place}
                <div class="mj-info-item"><span class="mj-info-label">Place</span><span class="mj-info-value">{mobileViewingJob.customer_place}</span></div>
              {/if}
              <div class="mj-info-item"><span class="mj-info-label">Priority</span><span class="mj-info-value mj-pri {mjPriClass(mobileViewingJob.priority)}">{mobileViewingJob.priority}</span></div>
              {#if mobileViewingJob.expected_date}
                <div class="mj-info-item"><span class="mj-info-label">Expected</span><span class="mj-info-value">{formatMobileDate(mobileViewingJob.expected_date)}</span></div>
              {/if}
            </div>
            <div class="mj-vehicle-box">
              <span class="mj-info-label">Vehicle</span>
              <div class="mj-vehicle-model">{mobileViewingJob.vehicle_model}</div>
              <div class="mj-vehicle-specs">
                {#if mobileViewingJob.vehicle_make}<span class="mj-vtag">{mobileViewingJob.vehicle_make}</span>{/if}
                {#if mobileViewingJob.vehicle_variant}<span class="mj-vtag">{mobileViewingJob.vehicle_variant}</span>{/if}
                {#if mobileViewingJob.vehicle_fuel}<span class="mj-vtag">{mobileViewingJob.vehicle_fuel}</span>{/if}
                {#if mobileViewingJob.vehicle_gearbox}<span class="mj-vtag">{mobileViewingJob.vehicle_gearbox}</span>{/if}
                {#if mobileViewingJob.vehicle_body}<span class="mj-vtag">{mobileViewingJob.vehicle_body}</span>{/if}
              </div>
            </div>
            {#if mobileViewingJob.description}
              <div class="mj-desc-box">{mobileViewingJob.description}</div>
            {/if}
            {#if mobileViewingJob.details}
              <div class="mj-desc-box mj-details">{mobileViewingJob.details}</div>
            {/if}

            <!-- Actions -->
            {#if mjActionError}
              <div class="mj-error">{mjActionError}</div>
            {/if}
            <div class="mj-actions">
              {#if mobileViewingJob.status === 'Open'}
                <button class="mj-action-btn start" on:click={mjStartJob} disabled={mjActionLoading}>
                  {mjActionLoading ? 'Starting...' : 'Start Job'}
                </button>
              {/if}
              {#if mobileViewingJob.status === 'In Progress'}
                <button class="mj-action-btn close-job" on:click={mjCloseJob} disabled={mjActionLoading}>
                  {mjActionLoading ? 'Closing...' : 'Close Job'}
                </button>
              {/if}
            </div>

            <!-- Items -->
            <div class="mj-section">
              <h3 class="mj-section-title">Items / Services ({mjItems.length})</h3>
              
              {#if mobileViewingJob.status !== 'Closed'}
                <div class="mj-add-item-form">
                  <div class="mj-form-field mj-product-search">
                    <label>Product</label>
                    <input type="text" placeholder="Search..." bind:value={mjProductSearch} on:input={handleMobileProductSearch} on:focus={handleMobileProductSearch} />
                    {#if mjShowProductDropdown}
                      <div class="mj-dropdown">
                        {#each mjFilteredProducts as p}
                          <button class="mj-dd-item" on:click={() => selectMobileProduct(p)}>
                            <span>{p.product_name}</span>
                            <span class="mj-type-tag">{p.product_type}</span>
                          </button>
                        {/each}
                      </div>
                    {/if}
                  </div>
                  <div class="mj-form-row">
                    <div class="mj-form-field">
                      <label>Qty</label>
                      <input type="number" min="1" bind:value={mjItemQty} />
                    </div>
                    <div class="mj-form-field">
                      <label>Price</label>
                      <input type="number" min="0" step="0.01" bind:value={mjItemPrice} />
                    </div>
                    <button class="mj-btn-add-item" on:click={mjAddItem} disabled={mjItemSaving || !mjProductSearch.trim()}>
                      {mjItemSaving ? '...' : '+'}
                    </button>
                  </div>
                  {#if mjItemError}<div class="mj-form-error">{mjItemError}</div>{/if}
                </div>
              {/if}
              
              {#if mjItems.length > 0}
                <div class="mj-items-list">
                  {#each mjItems as item}
                    <div class="mj-item-row">
                      <span class="mj-item-type {item.item_type}">{item.item_type}</span>
                      <span class="mj-item-name">{item.name || '—'}</span>
                      <span class="mj-item-qty">x{item.qty}</span>
                      <span class="mj-item-price">₹{(item.price || 0).toFixed(2)}</span>
                      <span class="mj-item-amt">₹{(item.total || 0).toFixed(2)}</span>
                      {#if mobileViewingJob.status !== 'Closed'}
                        <button class="mj-item-delete" on:click={() => mjRemoveItem(item.id)} disabled={mjDeletingItemId === item.id} title="Remove">✕</button>
                      {/if}
                    </div>
                  {/each}
                  <div class="mj-item-total-row">
                    <span class="mj-item-total-label">Total</span>
                    <span class="mj-item-total-amt">₹{mjItems.reduce((s: number, i: any) => s + (i.total || 0), 0).toFixed(2)}</span>
                  </div>
                </div>
              {/if}
            </div>

            <!-- Photos -->
            <div class="mj-section">
              <h3 class="mj-section-title">Photos</h3>
              {#if mjPhotos.length > 0}
                <div class="mj-photos-grid">
                  {#each mjPhotos as photo}
                    <a href={photo.file_url} target="_blank" rel="noopener" class="mj-photo-thumb">
                      <img src={photo.file_url} alt={photo.file_name || 'Photo'} />
                    </a>
                  {/each}
                </div>
              {:else}
                <p class="mj-empty-text">No photos yet.</p>
              {/if}
              {#if mobileViewingJob.status !== 'Closed'}
                <label class="mj-upload-btn">
                  {mjPhotoUploading ? 'Uploading...' : 'Upload Photo'}
                  <input type="file" accept="image/*" capture="environment" multiple on:change={mjHandlePhotoUpload} hidden disabled={mjPhotoUploading} />
                </label>
                {#if mjPhotoError}<p class="mj-error-text">{mjPhotoError}</p>{/if}
              {/if}
            </div>

            <!-- Notes -->
            <div class="mj-section">
              <h3 class="mj-section-title">Notes</h3>
              {#if mobileViewingJob.status !== 'Closed'}
                <div class="mj-note-form">
                  <textarea class="mj-note-input" bind:value={mjNewNote} placeholder="Add a note..." rows="2"></textarea>
                  <button class="mj-note-send" on:click={mjAddNote} disabled={mjNoteSaving || !mjNewNote.trim()}>
                    {mjNoteSaving ? '...' : 'Send'}
                  </button>
                </div>
              {/if}
              {#if mjNotes.length > 0}
                <div class="mj-notes-list">
                  {#each mjNotes as note}
                    <div class="mj-note-item">
                      <div class="mj-note-meta">{note.by_name} &middot; {formatMobileDateTime(note.created_at)}</div>
                      <div class="mj-note-text">{note.note}</div>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- Activity Log -->
            {#if mjLogs.length > 0}
              <div class="mj-section">
                <h3 class="mj-section-title">Activity Log</h3>
                <div class="mj-logs-list">
                  {#each mjLogs as log}
                    <div class="mj-log-item">
                      <span class="mj-log-action">{log.action}</span>
                      <span class="mj-log-meta">{log.by_name} &middot; {formatMobileDateTime(log.created_at)}</span>
                      {#if log.note}<span class="mj-log-note">{log.note}</span>{/if}
                    </div>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
        {/if}

        {:else if mobilePage === 'attendance'}
        <!-- ============================================================
             MOBILE ATTENDANCE PAGE
             ============================================================ -->
        <div class="ma-header">
          <button class="ma-back-btn" aria-label="Back to home" on:click={() => mobilePage = 'home'}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><polyline points="15 18 9 12 15 6"/></svg>
          </button>
          <h2 class="ma-title">Attendance</h2>
          <div class="ma-spacer"></div>
        </div>

        <div class="ma-content">
          <!-- QR Scanner Card -->
          <div class="ma-card qr-card">
            <div class="ma-card-header">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><circle cx="17.5" cy="17.5" r="3.5"/></svg>
              <h3>QR Scan Check-in/Out</h3>
            </div>
            <p class="ma-card-desc">Scan QR code to mark your attendance</p>
            <button class="ma-btn-primary" on:click={startScanner}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><circle cx="17.5" cy="17.5" r="3.5"/></svg>
              Open Scanner
            </button>
          </div>

          <!-- Today's Attendance Card -->
          <div class="ma-card status-card">
            <div class="ma-card-header">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><polyline points="9 16 11 18 15 14"/></svg>
              <h3>Today's Status</h3>
            </div>
            {#if attendancePunches.length > 0}
              <div class="ma-punches">
                {#each attendancePunches as p}
                  <div class="punch-row">
                    <span class="punch-label">Check-in:</span>
                    <span class="punch-time">{formatTime(p.check_in)}</span>
                    <span class="punch-label">Check-out:</span>
                    <span class="punch-time">{p.check_out ? formatTime(p.check_out) : '—'}</span>
                  </div>
                {/each}
              </div>
              {#if attendanceTotalHours}
                <div class="ma-total-hours">Total: {attendanceTotalHours}</div>
              {/if}
            {:else}
              <div class="ma-no-punches">No check-ins today</div>
            {/if}
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

        <!-- Check-in / Check-out Choice Popup -->
        {#if showPunchChoice}
          <div class="qr-overlay">
            <div class="punch-choice-box">
              <h3 class="punch-title">Mark Attendance</h3>
              <p class="punch-subtitle">QR scanned successfully! Choose your action:</p>
              <div class="punch-buttons">
                <button class="punch-btn checkin" on:click={() => doPunch('check_in')} disabled={scanLoading}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="28" height="28"><polyline points="20 6 9 17 4 12"/></svg>
                  Check In
                </button>
                <button class="punch-btn checkout" on:click={() => doPunch('check_out')} disabled={scanLoading}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="28" height="28"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
                  Check Out
                </button>
              </div>
              {#if scanLoading}<p class="qr-msg">Processing...</p>{/if}
              <button class="punch-cancel" on:click={cancelPunch}>Cancel</button>
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
        <button class="bottom-bar-item" class:active={mobilePage === 'home'} on:click={() => mobilePage = 'home'}>
          <svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>
          <span>Home</span>
        </button>
        <button class="bottom-bar-item" class:active={mobilePage === 'attendance'} on:click={() => mobilePage = 'attendance'}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/><polyline points="9 16 11 18 15 14"/></svg>
          <span>HR</span>
        </button>
        <button class="bottom-bar-item" class:active={mobilePage === 'jobs'} on:click={() => { mobilePage = 'jobs'; loadMobileJobs(); }}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="9" x2="15" y2="9"/><line x1="9" y1="13" x2="15" y2="13"/><line x1="9" y1="17" x2="12" y2="17"/></svg>
          <span>My Jobs</span>
        </button>
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
                  <!-- Finance > Manage > Job Card -->
                  <button class="nav-item" on:click={() => openWindow('finance-job-card', 'Job Card')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="9" x2="15" y2="9"/><line x1="9" y1="13" x2="15" y2="13"/><line x1="9" y1="17" x2="12" y2="17"/></svg>
                    <span>Job Card</span>
                  </button>
                  <!-- Finance > Manage > My Job Cards -->
                  <button class="nav-item" on:click={() => openWindow('finance-my-jobs', 'My Job Cards')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><polyline points="17 11 19 13 23 9"/></svg>
                    <span>My Job Cards</span>
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
                  <!-- Finance > Operations > Sales Return -->
                  <button class="nav-item" on:click={() => openWindow('finance-sales-return', 'Sales Return')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                    <span>Sales Return</span>
                  </button>
                  <!-- Finance > Operations > Purchase -->
                  <button class="nav-item" on:click={() => openWindow('finance-purchase', 'Purchase')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>
                    <span>Purchase</span>
                  </button>
                  <!-- Finance > Operations > Purchase Return -->
                  <button class="nav-item" on:click={() => openWindow('finance-purchase-return', 'Purchase Return')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                    <span>Purchase Return</span>
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
                  <!-- Finance > Reports > Job Cards -->
                  <button class="nav-item" on:click={() => openWindow('finance-job-card-report', 'Job Cards Report')}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="9" x2="15" y2="9"/><line x1="9" y1="13" x2="15" y2="13"/><line x1="9" y1="17" x2="12" y2="17"/></svg>
                    <span>Job Cards</span>
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
                  <div class="nav-item-placeholder">Coming Soon</div>
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
                  <div class="nav-item-placeholder">Coming Soon</div>
                </div>
              {/if}

              <!-- ---- HR > Operations ---- -->
              <button class="nav-sub" class:expanded={expandedSubs['hr-operations']} on:click={() => toggleSub('hr-operations')}>
                <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
                <span>Operations</span>
              </button>
              {#if expandedSubs['hr-operations']}
                <div class="sub-items">
                  <div class="nav-item-placeholder">Coming Soon</div>
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
                  <div class="nav-item-placeholder">Coming Soon</div>
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
          <div class="logo-liquid-container">
            <div class="liquid-wave wave1"></div>
            <div class="liquid-wave wave2"></div>
            <div class="liquid-wave wave3"></div>
            <img src="/logo.jpeg" alt="CarWhizz" class="center-logo" />
          </div>
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
              {:else if win.id === 'finance-sales-return'}
                <!-- Finance > Operations > Sales Return Window -->
                <SalesReturnWindow />
              {:else if win.id === 'finance-purchase-return'}
                <!-- Finance > Operations > Purchase Return Window -->
                <PurchaseReturnWindow />
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
              {:else if win.id === 'finance-job-card'}
                <JobCardWindow />
              {:else if win.id === 'finance-job-card-report'}
                <JobCardReportWindow />
              {:else if win.id === 'finance-my-jobs'}
                <MyJobCardsWindow />
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
    background: #f8fafc; /* Professional light gray */
    position: relative;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  }

  /* ========== LOGOUT BUTTON ========== */
  .logout-btn {
    background: #C41E3A;
    color: white;
    border: none;
    padding: 10px 16px;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.25s;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.35);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .logout-btn:hover {
    background: #9a152b;
    transform: translateY(-1px);
    box-shadow: 0 6px 16px rgba(196, 30, 58, 0.45);
  }

  /* ========== MOBILE LAYOUT ========== */
  .mobile-layout {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  .mobile-top-bar {
    height: 56px;
    background: #C41E3A;
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
    box-shadow: 0 4px 20px rgba(196, 30, 58, 0.3);
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

  /* ---- MOBILE ATTENDANCE PAGE ---- */
  .ma-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background: #ffffff;
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    z-index: 10;
  }
  .ma-back-btn {
    background: none;
    border: none;
    padding: 4px;
    cursor: pointer;
    color: #374151;
    display: flex;
    align-items: center;
  }
  .ma-title {
    font-size: 16px;
    font-weight: 700;
    color: #111827;
    flex: 1;
  }
  .ma-spacer {
    width: 28px;
  }
  .ma-content {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .ma-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 16px;
  }
  .ma-card-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 10px;
  }
  .ma-card-header svg {
    color: #C41E3A;
  }
  .ma-card-header h3 {
    font-size: 14px;
    font-weight: 700;
    color: #111827;
    margin: 0;
  }
  .ma-card-desc {
    font-size: 13px;
    color: #6b7280;
    margin: 0 0 12px;
  }
  .ma-btn-primary {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 12px 16px;
    background: #C41E3A;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
  }
  .ma-btn-primary:hover {
    background: #a71830;
  }
  .ma-punches {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 10px;
  }
  .punch-row {
    display: grid;
    grid-template-columns: 80px 1fr 80px 1fr;
    gap: 8px;
    padding: 8px;
    background: #f9fafb;
    border-radius: 6px;
    font-size: 13px;
  }
  .punch-label {
    font-weight: 600;
    color: #6b7280;
  }
  .punch-time {
    color: #111827;
  }
  .ma-total-hours {
    padding: 10px 12px;
    background: #fbf8f3;
    border-left: 3px solid #C41E3A;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    color: #111827;
  }
  .ma-no-punches {
    padding: 12px;
    background: #f9fafb;
    border-radius: 6px;
    font-size: 13px;
    color: #9ca3af;
    text-align: center;
  }

  .mobile-bottom-bar {
    height: 64px;
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-top: 1px solid rgba(196, 30, 58, 0.15);
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
      border: 1px solid transparent;
    border: none;
    border-radius: 12px;
    transition: all 0.2s;
    -webkit-tap-highlight-color: transparent;
  }

  .bottom-bar-item.active {
    color: #C41E3A;
    background: rgba(196, 30, 58, 0.1);
  }

  .bottom-bar-item svg {
    width: 24px;
    height: 24px;
  }

  .placeholder-icon {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    background: rgba(196, 30, 58, 0.1);
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
    border: 1px solid rgba(196, 30, 58, 0.2);
    border-radius: 10px;
    padding: 6px 10px;
    cursor: pointer;
    color: #C41E3A;
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
  .m-card.attendance { border-left-color: #C41E3A; background: rgba(255, 247, 237, 0.65); }
  .m-card.staff-present { border-left-color: #10b981; background: rgba(236, 253, 245, 0.65); }
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
  .m-card.attendance .m-card-icon { background: linear-gradient(135deg, #C41E3A, #C41E3A); color: white; }
  .m-card.staff-present .m-card-icon { background: linear-gradient(135deg, #10b981, #059669); color: white; }
  .m-card-attend-row {
    display: flex;
    gap: 8px;
    font-size: 13px;
    font-weight: 700;
    color: #111827;
  }
  .attend-in { color: #16a34a; }
  .attend-out { color: #2563eb; }
  .m-card-punches { display: flex; flex-direction: column; gap: 2px; }
  .punch-row { display: flex; gap: 8px; font-size: 12px; font-weight: 600; }
  .total-hrs { font-weight: 700; color: #C41E3A; font-size: 13px; margin-top: 2px; }
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
    width: 260px;
    background: #ffffff; /* Deep professional slate/navy background */
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 24px;
      box-sizing: border-box;
    position: fixed;
    top: 0;
    left: 0;
    bottom: 48px;
    z-index: 100;
    box-shadow: none;
    overflow-y: auto;
  }

  .sidebar-divider {
    width: 100%;
    border: none;
    border-top: 1px solid rgba(0, 0, 0, 0.1);
    margin: 12px 0;
  }

  .sidebar-nav {
    width: 100%;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
  }

  .nav-section {
    width: 100%;
    padding: 12px;
    border-radius: 6px;
    background: transparent;
    border: 1px solid rgba(196, 30, 58, 0.4);
    color: #000000;
    font-weight: 600;
    transition: all 0.2s;
    box-shadow: 0 4px 10px rgba(196, 30, 58, 0.1);
    box-sizing: border-box;
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
    text-align: left;
    margin-bottom: 8px;
  }

  .nav-section:hover {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
    box-shadow: 0 6px 16px rgba(196, 30, 58, 0.3);
  }

  .nav-section.expanded {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
    box-shadow: 0 6px 16px rgba(196, 30, 58, 0.3);
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
    width: 100%;
    /* Use padding for indentation to keep within container */
    padding-left: 12px;
    box-sizing: border-box;
    margin-bottom: 4px;
    margin-left: 0;
  }

  .nav-sub {
    display: flex;
    align-items: center;
    gap: 6px;
    box-sizing: border-box;
    padding: 10px 12px;
    /* Full width of the padded container */
    width: 100%;
    
    background: transparent;
    border-radius: 6px;
    border: 1px solid rgba(196, 30, 58, 0.4);
    color: #000000;
    font-size: 13px;
    font-weight: 600;

    cursor: pointer;
    transition: all 0.2s;
    text-align: left;
    margin-bottom: 6px;
    box-shadow: 0 2px 8px rgba(196, 30, 58, 0.1);
  }

  .nav-sub:hover {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.25);
  }

  .nav-sub.expanded {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.25);
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
    /* Indentation for sub-items */
    padding-left: 12px;
    width: 100%;
    box-sizing: border-box;
    margin-left: 0;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 8px;
    box-sizing: border-box;
    padding: 10px 12px;
    /* Full width of padded container */
    width: 100%;
    
    background: transparent;
    border: 1px solid rgba(196, 30, 58, 0.4);
    border-radius: 6px;
    color: #000000;
    font-size: 13px;
    font-weight: 600;

    cursor: pointer;
    transition: all 0.2s;
    text-align: left;
    margin-bottom: 6px;
    box-shadow: 0 2px 8px rgba(196, 30, 58, 0.1);
  }

  .nav-item:hover {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.25);
  }

  .nav-item-placeholder {
    padding: 10px 12px;
    width: 100%;
    color: #999;
    font-size: 12px;
    font-style: italic;
    text-align: center;
    background: rgba(0, 0, 0, 0.02);
    border-radius: 4px;
    border: 1px dashed #ddd;
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
    border-radius: 6px;
    background: transparent !important;
    border: 1px solid rgba(196, 30, 58, 0.4) !important;
    color: #C41E3A; /* Red text for visibility on white */
    font-weight: 600;
    transition: all 0.2s;
  }

  .sidebar-logout:hover {
    background: #C41E3A !important;
    color: white;
    border-color: #C41E3A !important;
  }

  .desktop-main {
    flex: 1;
    margin-left: 260px;
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    position: relative;
    background: #f8fafc; /* Professional light gray background for the main area */
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
    max-width: 100%;
    width: 480px; /* Increased size significantly */
    height: auto;
    object-fit: contain;
    position: relative;
    z-index: 2;
    display: block;
  }

  .logo-liquid-container {
    position: relative;
    border-radius: 16px;
    overflow: hidden;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.08), 0 1px 3px rgba(0, 0, 0, 0.05);
    padding: 30px 40px;
    margin-bottom: 20px;
  }

  .liquid-wave {
    display: none; /* Remove waves entirely */
  }

  .wave1 {
    background: linear-gradient(180deg, transparent 40%, rgba(196, 30, 58, 0.5) 70%, rgba(196, 30, 58, 0.7) 100%);
    animation: liquidWave1 4s ease-in-out infinite;
  }

  .wave2 {
    background: linear-gradient(180deg, transparent 40%, rgba(251, 146, 60, 0.4) 70%, rgba(196, 30, 58, 0.6) 100%);
    animation: liquidWave2 5s ease-in-out infinite;
    opacity: 0.35;
  }

  .wave3 {
    background: linear-gradient(180deg, transparent 40%, rgba(253, 186, 116, 0.3) 70%, rgba(251, 146, 60, 0.5) 100%);
    animation: liquidWave3 6s ease-in-out infinite;
    opacity: 0.3;
  }

  @keyframes liquidWave1 {
    0%, 100% { transform: translateY(10%) rotate(0deg); }
    25% { transform: translateY(5%) rotate(3deg); }
    50% { transform: translateY(0%) rotate(-2deg); }
    75% { transform: translateY(8%) rotate(2deg); }
  }

  @keyframes liquidWave2 {
    0%, 100% { transform: translateY(5%) rotate(2deg); }
    33% { transform: translateY(12%) rotate(-3deg); }
    66% { transform: translateY(2%) rotate(4deg); }
  }

  @keyframes liquidWave3 {
    0%, 100% { transform: translateY(8%) rotate(-1deg); }
    30% { transform: translateY(0%) rotate(3deg); }
    60% { transform: translateY(15%) rotate(-2deg); }
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
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-top: 1px solid #e2e8f0;
    box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.05);
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
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    color: #334155;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
  }

  .taskbar-item:hover {
    background: #f8fafc;
    border-color: #C41E3A;
    color: #C41E3A;
    transform: translateY(-1px);
    box-shadow: 0 2px 5px rgba(196, 30, 58, 0.1);
  }

  .taskbar-item.minimized {
    opacity: 0.5;
    border-style: dashed;
  }

  /* ========== QR WIDGET (DESKTOP) ========== */
  .qr-widget {
    pointer-events: auto;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    align-items: center;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  }
  .qr-widget-label {
    font-size: 14px;
    font-weight: 700;
    color: #C41E3A;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 12px;
  }
  .qr-img { width: 220px; height: 220px; border-radius: 8px; box-shadow: none; border: 1px solid #f1f5f9; }
  .qr-placeholder { width: 220px; height: 220px; display: flex; align-items: center; justify-content: center; color: #9ca3af; font-size: 14px; }
  .qr-widget-hint { font-size: 11px; color: #9ca3af; margin-top: 8px; }

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
  .qr-scanner-header h3 { font-size: 16px; font-weight: 700; color: #C41E3A; margin: 0; }
  .qr-close-btn {
    background: rgba(196, 30, 58, 0.1);
    border: none;
    font-size: 20px;
    cursor: pointer;
    color: #C41E3A;
    line-height: 1;
    width: 32px;
    height: 32px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
  }
  .qr-close-btn:hover { background: rgba(196, 30, 58, 0.2); }
  .qr-msg { text-align: center; color: #6b7280; font-size: 13px; margin-top: 8px; }

  /* ========== PUNCH CHOICE POPUP ========== */
  .punch-choice-box {
    background: rgba(255, 255, 255, 0.92);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border-radius: 24px;
    padding: 28px 24px;
    width: 320px;
    max-width: 90vw;
    box-shadow: 0 20px 60px rgba(0,0,0,0.25);
    border: 1px solid rgba(255,255,255,0.8);
    text-align: center;
  }
  .punch-title {
    font-size: 20px;
    font-weight: 800;
    color: #111827;
    margin: 0 0 6px 0;
  }
  .punch-subtitle {
    font-size: 13px;
    color: #6b7280;
    margin: 0 0 20px 0;
  }
  .punch-buttons {
    display: flex;
    gap: 12px;
    margin-bottom: 16px;
  }
  .punch-btn {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 20px 12px;
    border: none;
    border-radius: 16px;
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
      border: 1px solid transparent;
    border: none;
    color: #9ca3af;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    padding: 8px 16px;
    border-radius: 8px;
    transition: all 0.2s;
  }
  .punch-cancel:hover {
    color: #6b7280;
    background: rgba(0,0,0,0.04);
  }

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

  /* ========== MOBILE JOB CARDS ========== */
  .mj-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    background: #ffffff;
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    z-index: 10;
  }
  .mj-back-btn {
    background: none;
    border: none;
    padding: 4px;
    cursor: pointer;
    color: #374151;
    display: flex;
    align-items: center;
  }
  .mj-title {
    flex: 1;
    font-size: 16px;
    font-weight: 700;
    color: #111827;
    margin: 0;
  }
  .mj-filter {
    padding: 4px 8px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 12px;
    background: #fff;
    color: #374151;
  }
  .mj-refresh-btn {
    background: none;
    border: none;
    padding: 4px;
    cursor: pointer;
    color: #6b7280;
  }
  .mj-empty {
    text-align: center;
    padding: 40px 16px;
    color: #9ca3af;
    font-size: 14px;
  }
  .mj-list {
    padding: 12px 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-bottom: 80px;
  }
  .mj-card {
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 12px 14px;
    text-align: left;
    cursor: pointer;
    transition: box-shadow 0.2s;
    width: 100%;
  }
  .mj-card:active {
    box-shadow: 0 2px 12px rgba(0,0,0,0.08);
  }
  .mj-card-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
  }
  .mj-card-no {
    font-weight: 700;
    font-size: 14px;
    color: #111827;
  }
  .mj-badge {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 10px;
    white-space: nowrap;
  }
  .mj-badge.mj-open { background: #dbeafe; color: #1e40af; }
  .mj-badge.mj-progress { background: #fef3c7; color: #92400e; }
  .mj-badge.mj-closed { background: #d1fae5; color: #065f46; }
  .mj-card-customer {
    font-size: 13px;
    color: #374151;
    font-weight: 600;
  }
  .mj-vehicle-numbers {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 4px;
    margin-bottom: 4px;
  }
  .mj-vehicle-number {
    display: inline-block;
    padding: 2px 6px;
    background: #fff3cd;
    color: #856404;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 600;
    border: 1px solid #ffc107;
  }
  .mj-card-vehicle {
    font-size: 12px;
    color: #6b7280;
    margin-top: 2px;
  }
  .mj-card-desc {
    font-size: 12px;
    color: #9ca3af;
    margin-top: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .mj-card-bottom {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 8px;
  }
  .mj-pri {
    font-size: 11px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 6px;
  }
  .mj-pri-low { background: #f3f4f6; color: #6b7280; }
  .mj-pri-normal { background: #dbeafe; color: #1d4ed8; }
  .mj-pri-high { background: #fef3c7; color: #d97706; }
  .mj-pri-urgent { background: #fee2e2; color: #dc2626; }
  .mj-card-date {
    font-size: 11px;
    color: #9ca3af;
  }

  /* Detail View */
  .mj-detail-scroll {
    padding: 12px 16px;
    padding-bottom: 80px;
    overflow-y: auto;
  }
  .mj-info-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    margin-bottom: 12px;
  }
  .mj-info-item {
    background: #f9fafb;
    border-radius: 8px;
    padding: 8px 10px;
  }
  .mj-info-label {
    display: block;
    font-size: 11px;
    color: #9ca3af;
    font-weight: 500;
  }
  .mj-info-value {
    display: block;
    font-size: 13px;
    color: #111827;
    font-weight: 600;
    margin-top: 2px;
  }
  .mj-desc-box {
    background: #f9fafb;
    border-radius: 8px;
    padding: 10px 12px;
    font-size: 13px;
    color: #374151;
    margin-bottom: 10px;
    white-space: pre-wrap;
  }
  .mj-vehicle-box {
    background: #f9fafb;
    border-radius: 8px;
    padding: 10px 12px;
    margin-bottom: 10px;
  }
  .mj-vehicle-model {
    font-size: 14px;
    font-weight: 700;
    color: #111827;
    margin-top: 2px;
  }
  .mj-vehicle-specs {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 6px;
  }
  .mj-vtag {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 6px;
    background: #e0e7ff;
    color: #3730a3;
  }
  .mj-details {
    font-size: 12px;
    color: #6b7280;
  }
  .mj-error {
    background: #fee2e2;
    color: #991b1b;
    padding: 8px 12px;
    border-radius: 8px;
    font-size: 13px;
    margin-bottom: 8px;
  }
  .mj-actions {
    display: flex;
    gap: 10px;
    margin-bottom: 16px;
  }
  .mj-action-btn {
    flex: 1;
    padding: 10px;
    border: none;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 700;
    cursor: pointer;
    color: #fff;
    transition: opacity 0.2s;
  }
  .mj-action-btn:disabled { opacity: 0.6; }
  .mj-action-btn.start { background: linear-gradient(135deg, #22c55e, #16a34a); }
  .mj-action-btn.close-job { background: linear-gradient(135deg, #3b82f6, #2563eb); }
  .mj-section {
    margin-bottom: 16px;
  }
  .mj-section-title {
    font-size: 14px;
    font-weight: 700;
    color: #111827;
    margin: 0 0 8px 0;
    padding-bottom: 4px;
    border-bottom: 1px solid #e5e7eb;
  }
  .mj-items-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .mj-item-row {
    display: flex;
    align-items: center;
    gap: 8px;
    background: #f9fafb;
    padding: 8px 10px;
    border-radius: 8px;
    font-size: 13px;
  }
  .mj-item-name {
    flex: 1;
    color: #374151;
  }
  .mj-item-type {
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 4px;
    text-transform: capitalize;
    background: #dbeafe;
    color: #1e40af;
  }
  .mj-item-type.service { background: #ede9fe; color: #6d28d9; }
  .mj-item-type.consumable { background: #d1fae5; color: #065f46; }
  .mj-item-qty {
    color: #6b7280;
    font-weight: 600;
    font-size: 12px;
  }
  .mj-item-price {
    color: #6b7280;
    font-size: 12px;
  }
  .mj-item-amt {
    color: #111827;
    font-weight: 700;
    min-width: 60px;
    text-align: right;
  }
  .mj-item-total-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px;
    border-top: 2px solid #e5e7eb;
    margin-top: 4px;
    font-weight: 700;
  }
  .mj-item-total-label {
    font-size: 14px;
    color: #111827;
  }
  .mj-item-total-amt {
    font-size: 15px;
    color: #111827;
  }
  .mj-item-delete {
    background: none;
    border: none;
    color: #dc2626;
    cursor: pointer;
    font-size: 16px;
    font-weight: 700;
    padding: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .mj-item-delete:hover:not(:disabled) { opacity: 0.7; }
  .mj-item-delete:disabled { opacity: 0.4; cursor: not-allowed; }
  
  /* Add item form */
  .mj-add-item-form {
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 10px;
    margin-bottom: 12px;
  }
  .mj-product-search {
    position: relative;
    margin-bottom: 8px;
  }
  .mj-product-search input {
    width: 100%;
  }
  .mj-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    max-height: 120px;
    overflow-y: auto;
    z-index: 50;
    margin-top: 2px;
  }
  .mj-dd-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 6px 10px;
    border: none;
    background: none;
    cursor: pointer;
    font-size: 12px;
    text-align: left;
  }
  .mj-dd-item:hover { background: #f3f4f6; }
  .mj-type-tag {
    font-size: 10px;
    font-weight: 600;
    background: #dbeafe;
    color: #1d4ed8;
    padding: 2px 6px;
    border-radius: 3px;
  }
  .mj-form-field {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .mj-form-field label {
    font-size: 10px;
    font-weight: 600;
    color: #6b7280;
  }
  .mj-form-field input {
    padding: 5px 6px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 12px;
    outline: none;
  }
  .mj-form-field input:focus {
    border-color: #C41E3A;
    box-shadow: 0 0 0 2px rgba(196, 30, 58, 0.1);
  }
  .mj-form-row {
    display: grid;
    grid-template-columns: 60px 80px 1fr;
    gap: 6px;
    align-items: flex-end;
  }
  .mj-btn-add-item {
    background: #C41E3A;
    color: white;
    border: none;
    border-radius: 4px;
    padding: 5px 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 700;
    height: 28px;
  }
  .mj-btn-add-item:hover:not(:disabled) { background: #a71830; }
  .mj-btn-add-item:disabled { opacity: 0.5; cursor: not-allowed; }
  .mj-form-error {
    background: #fef2f2;
    color: #dc2626;
    padding: 6px;
    border-radius: 4px;
    font-size: 11px;
  }

  .mj-photos-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    margin-bottom: 8px;
  }
  .mj-photo-thumb {
    aspect-ratio: 1;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid #e5e7eb;
  }
  .mj-photo-thumb img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .mj-empty-text {
    color: #9ca3af;
    font-size: 12px;
    margin: 4px 0 8px;
  }
  .mj-upload-btn {
    display: inline-block;
    padding: 8px 16px;
    background: #f3f4f6;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    color: #374151;
    cursor: pointer;
    transition: background 0.2s;
  }
  .mj-upload-btn:active { background: #e5e7eb; }
  .mj-error-text {
    color: #dc2626;
    font-size: 12px;
    margin-top: 4px;
  }
  .mj-note-form {
    display: flex;
    gap: 8px;
    margin-bottom: 10px;
  }
  .mj-note-input {
    flex: 1;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    padding: 8px 10px;
    font-size: 13px;
    resize: none;
    font-family: inherit;
  }
  .mj-note-send {
    padding: 8px 14px;
    background: #111827;
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    align-self: flex-end;
  }
  .mj-note-send:disabled { opacity: 0.5; }
  .mj-notes-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .mj-note-item {
    background: #f9fafb;
    border-radius: 8px;
    padding: 8px 10px;
  }
  .mj-note-meta {
    font-size: 11px;
    color: #9ca3af;
    margin-bottom: 2px;
  }
  .mj-note-text {
    font-size: 13px;
    color: #374151;
    white-space: pre-wrap;
  }
  .mj-logs-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .mj-log-item {
    display: flex;
    flex-wrap: wrap;
    gap: 4px 8px;
    align-items: baseline;
    padding: 6px 0;
    border-bottom: 1px solid #f3f4f6;
    font-size: 12px;
  }
  .mj-log-action {
    font-weight: 700;
    color: #111827;
  }
  .mj-log-meta {
    color: #9ca3af;
    font-size: 11px;
  }
  .mj-log-note {
    color: #6b7280;
    width: 100%;
  }
</style>
