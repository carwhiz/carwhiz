<script lang="ts">
  import { authStore } from '../stores/authStore';
  import { logout } from '../lib/services/authService';
  import { interfaceStore } from '../stores/interfaceStore';
  import { windowStore } from '../stores/windowStore';
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
  import CustomersWindow from './windows/finance/manage/CustomersWindow.svelte';
  import CreateCustomerWindow from './windows/finance/manage/CreateCustomerWindow.svelte';
  import VendorsWindow from './windows/finance/manage/VendorsWindow.svelte';
  import CreateVendorWindow from './windows/finance/manage/CreateVendorWindow.svelte';
  import LedgerWindow from './windows/finance/manage/LedgerWindow.svelte';
  import CreateLedgerWindow from './windows/finance/manage/CreateLedgerWindow.svelte';
  import CreateEmployeeWindow from './windows/finance/manage/CreateEmployeeWindow.svelte';
  import SalesReportWindow from './windows/finance/reports/SalesReportWindow.svelte';
  import PurchaseReportWindow from './windows/finance/reports/PurchaseReportWindow.svelte';
  import LedgerBalanceWindow from './windows/finance/reports/LedgerBalanceWindow.svelte';
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  // Sidebar section collapse state
  let expandedSections: Record<string, boolean> = { finance: false, products: false };
  let expandedSubs: Record<string, boolean> = {};

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
        <!-- Blank content area for now -->
      </div>

      <div class="mobile-bottom-bar">
        <div class="bottom-bar-item active">
          <svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>
          <span>Home</span>
        </div>
        <div class="bottom-bar-item">
          <span class="placeholder-icon"></span>
          <span>&nbsp;</span>
        </div>
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
        <img src="/logo.jpeg" alt="CarWhizz" class="sidebar-logo" />
        <hr class="sidebar-divider" />

        <nav class="sidebar-nav">
          <!-- ====================================================
               MAIN SECTION: FINANCE
               Sub-sections: Manage | Operations | Reports
               ==================================================== -->
          <button class="nav-section" class:expanded={expandedSections.finance} on:click={() => toggleSection('finance')}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
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
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                    <span>Ledger Balance</span>
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
                  <!-- Products > Reports items go here -->
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
              {:else if win.id === 'finance-create-employee'}
                <!-- Finance > Manage > Create Employee Window -->
                <CreateEmployeeWindow />
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
    background: #f5f5f5;
    position: relative;
  }

  /* ========== LOGOUT BUTTON ========== */
  .logout-btn {
    background: #EA580C;
    color: white;
    border: none;
    padding: 6px 16px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .logout-btn:hover {
    background: #C2410C;
  }

  /* ========== MOBILE LAYOUT ========== */
  .mobile-layout {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  .mobile-top-bar {
    height: 56px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 16px;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  }

  .top-bar-logo {
    height: 36px;
    width: auto;
    object-fit: contain;
  }

  .mobile-content {
    flex: 1;
    margin-top: 56px;
    margin-bottom: 64px;
    padding: 16px;
  }

  .mobile-bottom-bar {
    height: 64px;
    background: white;
    border-top: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: space-around;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 100;
    box-shadow: 0 -1px 4px rgba(0, 0, 0, 0.06);
  }

  .bottom-bar-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    font-size: 11px;
    color: #9ca3af;
    cursor: pointer;
    padding: 4px 12px;
  }

  .bottom-bar-item.active {
    color: #EA580C;
  }

  .bottom-bar-item svg {
    width: 24px;
    height: 24px;
  }

  .placeholder-icon {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    background: #e5e7eb;
  }

  /* ========== DESKTOP LAYOUT ========== */
  .desktop-layout {
    display: flex;
    min-height: 100vh;
  }

  .desktop-sidebar {
    width: 240px;
    background: white;
    border-right: 1px solid #e5e7eb;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 20px 16px;
    position: fixed;
    top: 0;
    left: 0;
    bottom: 48px;
    z-index: 100;
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.04);
  }

  .sidebar-logo {
    width: 100%;
    max-width: 180px;
    height: auto;
    object-fit: contain;
    border: 2px solid #F97316;
    border-radius: 12px;
    margin-bottom: 0;
  }

  .sidebar-divider {
    width: 100%;
    border: none;
    border-top: 1px solid #e5e7eb;
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
    padding: 10px 12px;
    background: none;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 600;
    color: #374151;
    transition: background 0.15s;
    text-align: left;
  }

  .nav-section:hover {
    background: #f3f4f6;
  }

  .nav-section.expanded {
    background: #fff7ed;
    color: #EA580C;
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
    padding-left: 12px;
  }

  .nav-sub {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 8px 10px;
    background: none;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    color: #6b7280;
    transition: background 0.15s;
    text-align: left;
  }

  .nav-sub:hover {
    background: #f9fafb;
    color: #374151;
  }

  .nav-sub.expanded {
    color: #EA580C;
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
    padding-left: 20px;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 7px 10px;
    background: none;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    color: #6b7280;
    transition: all 0.15s;
    text-align: left;
  }

  .nav-item:hover {
    background: #fff7ed;
    color: #EA580C;
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
    padding: 10px;
    border-radius: 10px;
  }

  .desktop-main {
    flex: 1;
    margin-left: 240px;
    display: flex;
    flex-direction: column;
    min-height: 100vh;
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
    background: white;
    border-top: 1px solid #e5e7eb;
    box-shadow: 0 -1px 4px rgba(0, 0, 0, 0.04);
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
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    color: #374151;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s;
  }

  .taskbar-item:hover {
    background: #fff7ed;
    border-color: #F97316;
    color: #EA580C;
  }

  .taskbar-item.minimized {
    opacity: 0.6;
    border-style: dashed;
  }
</style>
