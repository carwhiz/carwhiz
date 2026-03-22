<script lang="ts">
  import { authStore } from '../../stores/authStore';
  import { windowStore } from '../../stores/windowStore';
  import { interfaceStore } from '../../stores/interfaceStore';
  import { logout } from '../../lib/services/authService';
  import AppWindow from '../../components/AppWindow.svelte';
  import Taskbar from '../../components/desktop/Taskbar.svelte';
  
  // Finance Windows
  import SalesWindow from '../../components/windows/finance/operations/SalesWindow.svelte';
  import PurchaseWindow from '../../components/windows/finance/operations/PurchaseWindow.svelte';
  import SalesReturnWindow from '../../components/windows/finance/operations/SalesReturnWindow.svelte';
  import PurchaseReturnWindow from '../../components/windows/finance/operations/PurchaseReturnWindow.svelte';
  import CustomersWindow from '../../components/windows/finance/manage/CustomersWindow.svelte';
  import VendorsWindow from '../../components/windows/finance/manage/VendorsWindow.svelte';
  import LedgerWindow from '../../components/windows/finance/manage/LedgerWindow.svelte';
  import AssetsWindow from '../../components/windows/finance/manage/AssetsWindow.svelte';
  import JobCardWindow from '../../components/windows/finance/manage/JobCardWindow.svelte';
  import MyJobCardsWindow from '../../components/windows/finance/manage/MyJobCardsWindow.svelte';
  import SalesReportWindow from '../../components/windows/finance/reports/SalesReportWindow.svelte';
  import PurchaseReportWindow from '../../components/windows/finance/reports/PurchaseReportWindow.svelte';
  import LedgerBalanceWindow from '../../components/windows/finance/reports/LedgerBalanceWindow.svelte';
  import DayBookWindow from '../../components/windows/finance/reports/DayBookWindow.svelte';
  import TrialBalanceWindow from '../../components/windows/finance/reports/TrialBalanceWindow.svelte';
  import ProfitLossWindow from '../../components/windows/finance/reports/ProfitLossWindow.svelte';
  import BalanceSheetWindow from '../../components/windows/finance/reports/BalanceSheetWindow.svelte';
  import JobCardReportWindow from '../../components/windows/finance/reports/JobCardReportWindow.svelte';
  
  // Product Windows
  import ProductsWindow from '../../components/windows/products/manage/ProductsWindow.svelte';
  import VehiclesWindow from '../../components/windows/products/manage/VehiclesWindow.svelte';
  import StockManagementWindow from '../../components/windows/products/manage/StockManagementWindow.svelte';
  import StockReportWindow from '../../components/windows/products/reports/StockReportWindow.svelte';
  
  // Admin Windows
  import UsersWindow from '../../components/windows/appcontrol/manage/UsersWindow.svelte';
  import PermissionsWindow from '../../components/windows/appcontrol/manage/PermissionsWindow.svelte';
  import AuditLogWindow from '../../components/windows/appcontrol/reports/AuditLogWindow.svelte';
  
  // HR Windows
  import AttendanceReportWindow from '../../components/windows/hr/reports/AttendanceReportWindow.svelte';

  let expandedSections: Record<string, boolean> = { finance: false, products: false, appcontrol: false, hr: false };
  let expandedSubs: Record<string, boolean> = {
    'finance-manage': false,
    'finance-operations': false,
    'finance-reports': false,
    'products-manage': false,
    'products-operations': false,
    'products-reports': false,
    'hr-manage': false,
    'hr-operations': false,
    'hr-reports': false,
    'appcontrol-manage': false,
    'appcontrol-operations': false,
    'appcontrol-reports': false,
  };

  // Map window IDs to their content components
  const windowComponentMap: Record<string, any> = {
    // Finance > Manage
    'finance-customers': CustomersWindow,
    'finance-vendors': VendorsWindow,
    'finance-ledger': LedgerWindow,
    'finance-assets': AssetsWindow,
    'finance-job-card': JobCardWindow,
    'finance-my-jobs': MyJobCardsWindow,
    // Finance > Operations
    'finance-sales': SalesWindow,
    'finance-purchase': PurchaseWindow,
    'finance-sales-return': SalesReturnWindow,
    'finance-purchase-return': PurchaseReturnWindow,
    // Finance > Reports
    'finance-sales-report': SalesReportWindow,
    'finance-purchase-report': PurchaseReportWindow,
    'finance-ledger-balance': LedgerBalanceWindow,
    'finance-day-book': DayBookWindow,
    'finance-trial-balance': TrialBalanceWindow,
    'finance-profit-loss': ProfitLossWindow,
    'finance-balance-sheet': BalanceSheetWindow,
    'finance-job-card-report': JobCardReportWindow,
    // Products > Manage
    'products-vehicles': VehiclesWindow,
    'products-products': ProductsWindow,
    'products-stock-management': StockManagementWindow,
    // Products > Reports
    'products-stock-report': StockReportWindow,
    // HR > Reports
    'hr-attendance-report': AttendanceReportWindow,
    // App Control
    'appcontrol-permissions': PermissionsWindow,
    'appcontrol-users': UsersWindow,
    'appcontrol-auditlog': AuditLogWindow,
  };

  function getWindowComponent(windowId: string) {
    return windowComponentMap[windowId];
  }

  async function handleLogout() {
    await logout();
    interfaceStore.logout();
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
</script>

<div class="desktop-layout">
  <!-- Sidebar -->
  <nav class="sidebar">
    <div class="sidebar-header">
      <img src="/src/assets/CARWHIZ.jpeg" alt="CarWhizz Logo" class="sidebar-logo" />
      <h1>CarWhizz</h1>
    </div>

    <div class="sidebar-content">
      <!-- ====== FINANCE ====== -->
      <button class="nav-section" class:expanded={expandedSections.finance} on:click={() => toggleSection('finance')}>
        <svg viewBox="0 0 24 24"><text x="12" y="18" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor" stroke="none">₹</text></svg>
        <span>Finance</span>
        <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
      </button>

      {#if expandedSections.finance}
        <div class="sub-sections">
          <!-- Finance > Manage -->
          <button class="nav-sub" class:expanded={expandedSubs['finance-manage']} on:click={() => toggleSub('finance-manage')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Manage</span>
          </button>
          {#if expandedSubs['finance-manage']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('finance-customers', 'Customers')}>Customers</button>
              <button class="nav-item" on:click={() => openWindow('finance-vendors', 'Vendors')}>Vendors</button>
              <button class="nav-item" on:click={() => openWindow('finance-ledger', 'Ledger')}>Ledger</button>
              <button class="nav-item" on:click={() => openWindow('finance-assets', 'Fixed Assets')}>Fixed Assets</button>
              <button class="nav-item" on:click={() => openWindow('finance-job-card', 'Job Card')}>Job Card</button>
              <button class="nav-item" on:click={() => openWindow('finance-my-jobs', 'My Job Cards')}>My Job Cards</button>
            </div>
          {/if}

          <!-- Finance > Operations -->
          <button class="nav-sub" class:expanded={expandedSubs['finance-operations']} on:click={() => toggleSub('finance-operations')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Operations</span>
          </button>
          {#if expandedSubs['finance-operations']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('finance-sales', 'Sales')}>Sales</button>
              <button class="nav-item" on:click={() => openWindow('finance-sales-return', 'Sales Return')}>Sales Return</button>
              <button class="nav-item" on:click={() => openWindow('finance-purchase', 'Purchase')}>Purchase</button>
              <button class="nav-item" on:click={() => openWindow('finance-purchase-return', 'Purchase Return')}>Purchase Return</button>
            </div>
          {/if}

          <!-- Finance > Reports -->
          <button class="nav-sub" class:expanded={expandedSubs['finance-reports']} on:click={() => toggleSub('finance-reports')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Reports</span>
          </button>
          {#if expandedSubs['finance-reports']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('finance-sales-report', 'Sales Report')}>Sales Report</button>
              <button class="nav-item" on:click={() => openWindow('finance-purchase-report', 'Purchase Report')}>Purchase Report</button>
              <button class="nav-item" on:click={() => openWindow('finance-ledger-balance', 'Ledger Balance')}>Ledger Balance</button>
              <button class="nav-item" on:click={() => openWindow('finance-day-book', 'Day Book')}>Day Book</button>
              <button class="nav-item" on:click={() => openWindow('finance-trial-balance', 'Trial Balance')}>Trial Balance</button>
              <button class="nav-item" on:click={() => openWindow('finance-profit-loss', 'Profit & Loss')}>Profit & Loss</button>
              <button class="nav-item" on:click={() => openWindow('finance-balance-sheet', 'Balance Sheet')}>Balance Sheet</button>
              <button class="nav-item" on:click={() => openWindow('finance-job-card-report', 'Job Cards Report')}>Job Cards</button>
            </div>
          {/if}
        </div>
      {/if}

      <!-- ====== PRODUCTS ====== -->
      <button class="nav-section" class:expanded={expandedSections.products} on:click={() => toggleSection('products')}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
        <span>Products</span>
        <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
      </button>

      {#if expandedSections.products}
        <div class="sub-sections">
          <!-- Products > Manage -->
          <button class="nav-sub" class:expanded={expandedSubs['products-manage']} on:click={() => toggleSub('products-manage')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Manage</span>
          </button>
          {#if expandedSubs['products-manage']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('products-vehicles', 'Vehicles')}>Vehicles</button>
              <button class="nav-item" on:click={() => openWindow('products-products', 'Products')}>Products</button>
              <button class="nav-item" on:click={() => openWindow('products-stock-management', 'Stock Management')}>Stock Management</button>
            </div>
          {/if}

          <!-- Products > Operations -->
          <button class="nav-sub" class:expanded={expandedSubs['products-operations']} on:click={() => toggleSub('products-operations')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Operations</span>
          </button>
          {#if expandedSubs['products-operations']}
            <div class="sub-items">
              <div style="padding: 8px 12px; color: #999; font-size: 12px; font-style: italic; text-align: center;">Coming Soon</div>
            </div>
          {/if}

          <!-- Products > Reports -->
          <button class="nav-sub" class:expanded={expandedSubs['products-reports']} on:click={() => toggleSub('products-reports')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Reports</span>
          </button>
          {#if expandedSubs['products-reports']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('products-stock-report', 'Stock Report')}>Stock Report</button>
            </div>
          {/if}
        </div>
      {/if}

      <!-- ====== HR ====== -->
      <button class="nav-section" class:expanded={expandedSections.hr} on:click={() => toggleSection('hr')}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        <span>HR</span>
        <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
      </button>

      {#if expandedSections.hr}
        <div class="sub-sections">
          <!-- HR > Manage -->
          <button class="nav-sub" class:expanded={expandedSubs['hr-manage']} on:click={() => toggleSub('hr-manage')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Manage</span>
          </button>
          {#if expandedSubs['hr-manage']}
            <div class="sub-items">
              <div style="padding: 8px 12px; color: #999; font-size: 12px; font-style: italic; text-align: center;">Coming Soon</div>
            </div>
          {/if}

          <!-- HR > Operations -->
          <button class="nav-sub" class:expanded={expandedSubs['hr-operations']} on:click={() => toggleSub('hr-operations')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Operations</span>
          </button>
          {#if expandedSubs['hr-operations']}
            <div class="sub-items">
              <div style="padding: 8px 12px; color: #999; font-size: 12px; font-style: italic; text-align: center;">Coming Soon</div>
            </div>
          {/if}

          <!-- HR > Reports -->
          <button class="nav-sub" class:expanded={expandedSubs['hr-reports']} on:click={() => toggleSub('hr-reports')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Reports</span>
          </button>
          {#if expandedSubs['hr-reports']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('hr-attendance-report', 'Attendance Report')}>Attendance Report</button>
            </div>
          {/if}
        </div>
      {/if}

      <!-- ====== APP CONTROL ====== -->
      <button class="nav-section" class:expanded={expandedSections.appcontrol} on:click={() => toggleSection('appcontrol')}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
        <span>App Control</span>
        <svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
      </button>

      {#if expandedSections.appcontrol}
        <div class="sub-sections">
          <!-- App Control > Manage -->
          <button class="nav-sub" class:expanded={expandedSubs['appcontrol-manage']} on:click={() => toggleSub('appcontrol-manage')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Manage</span>
          </button>
          {#if expandedSubs['appcontrol-manage']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('appcontrol-users', 'Users')}>Users</button>
              <button class="nav-item" on:click={() => openWindow('appcontrol-permissions', 'Permissions')}>Permissions</button>
            </div>
          {/if}

          <!-- App Control > Operations -->
          <button class="nav-sub" class:expanded={expandedSubs['appcontrol-operations']} on:click={() => toggleSub('appcontrol-operations')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Operations</span>
          </button>
          {#if expandedSubs['appcontrol-operations']}
            <div class="sub-items">
              <div style="padding: 8px 12px; color: #999; font-size: 12px; font-style: italic; text-align: center;">Coming Soon</div>
            </div>
          {/if}

          <!-- App Control > Reports -->
          <button class="nav-sub" class:expanded={expandedSubs['appcontrol-reports']} on:click={() => toggleSub('appcontrol-reports')}>
            <svg class="chevron-sm" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
            <span>Reports</span>
          </button>
          {#if expandedSubs['appcontrol-reports']}
            <div class="sub-items">
              <button class="nav-item" on:click={() => openWindow('appcontrol-auditlog', 'Audit Log')}>Audit Log</button>
            </div>
          {/if}
        </div>
      {/if}
    </div>

    <!-- Sidebar Footer -->
    <div class="sidebar-footer">
      <button class="logout-btn" on:click={handleLogout} title="Logout">🚪 Logout</button>
    </div>
  </nav>

  <!-- Main Content -->
  <div class="desktop-main">
    <!-- Windows Container -->
    <div class="windows-container">
      {#each $windowStore as window (window.id)}
        <AppWindow win={window}>
          {#if getWindowComponent(window.id)}
            <svelte:component this={getWindowComponent(window.id)} />
          {:else}
            <div style="padding: 20px; color: #999;">
              <p>Window content not found for: {window.id}</p>
            </div>
          {/if}
        </AppWindow>
      {/each}
    </div>

    <!-- Empty State -->
    {#if $windowStore.length === 0}
      <div class="empty-state">
        <h2>Welcome to CarWhizz Desktop</h2>
        <p>Open a module from the sidebar to get started</p>
      </div>
    {/if}
  </div>

  <!-- Taskbar Component at Bottom (outside main to span full width) -->
  <Taskbar />
</div>

<style>
  .desktop-layout {
    display: flex;
    min-height: 100vh;
  }

  .sidebar {
    width: 260px;
    background: #ffffff;
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

  .sidebar-header {
    width: 100%;
    text-align: center;
    margin-bottom: 24px;
    padding-bottom: 12px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
  }

  .sidebar-logo {
    width: 50px;
    height: 50px;
    border-radius: 8px;
    object-fit: contain;
  }

  .sidebar-header h1 {
    margin: 0;
    font-size: 20px;
    font-weight: 700;
    color: #000000;
  }

  .sidebar-content {
    width: 100%;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    flex: 1;
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

  .nav-item svg {
    width: 15px;
    height: 15px;
    flex-shrink: 0;
  }

  .sidebar-footer {
    width: 100%;
    padding-top: 12px;
    border-top: 1px solid rgba(0, 0, 0, 0.1);
  }

  .logout-btn {
    width: 100%;
    padding: 12px;
    border-radius: 6px;
    background: transparent;
    border: 1px solid rgba(196, 30, 58, 0.4);
    color: #C41E3A;
    font-weight: 600;
    transition: all 0.2s;
    cursor: pointer;
    box-shadow: 0 2px 8px rgba(196, 30, 58, 0.1);
  }

  .logout-btn:hover {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
    box-shadow: 0 4px 12px rgba(196, 30, 58, 0.25);
  }

  .desktop-main {
    flex: 1;
    margin-left: 260px;
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    position: relative;
    background: #f8fafc;
    padding-bottom: 48px;
  }

  .windows-container {
    flex: 1;
    overflow: auto;
    padding: 24px;
    position: relative;
    background: #f8fafc;
  }

  .empty-state {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    color: #9ca3af;
  }

  .empty-state h2 {
    margin: 0 0 8px 0;
    font-size: 18px;
    font-weight: 700;
    color: #4b5563;
  }

  .empty-state p {
    margin: 0;
    font-size: 14px;
    color: #9ca3af;
  }
</style>
