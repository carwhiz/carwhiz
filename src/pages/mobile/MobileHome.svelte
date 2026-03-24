<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../../stores/authStore';
  import { supabase } from '../../lib/supabaseClient';
  import { canUserViewResources } from '../../lib/services/permissionService';

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
  let attendancePunches: { check_in: string | null; check_out: string | null; punch_order: number }[] = [];
  let attendanceTotalHours = '';
  let mobileLoading = true;
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

  async function loadMobileCardPermissions() {
    const userId = $authStore.user?.id;
    if (!userId) {
      // If no userId, grant all permissions as fallback
      const fallbackPerms = new Map<string, boolean>();
      mobileCardResources.forEach(resource => {
        fallbackPerms.set(resource, true);
      });
      cardPermissions = fallbackPerms;
      return;
    }

    try {
      const permissions = await canUserViewResources(userId, mobileCardResources);
      cardPermissions = permissions;
    } catch (error) {
      // If permission check fails, grant all as fallback
      console.warn('Permission check failed, showing all cards:', error);
      const fallbackPerms = new Map<string, boolean>();
      mobileCardResources.forEach(resource => {
        fallbackPerms.set(resource, true);
      });
      cardPermissions = fallbackPerms;
    }
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

    // Load attendance for the selected date
    attendancePunches = [];
    attendanceTotalHours = '';
    const userId = $authStore.user?.id;
    if (userId) {
      try {
        // Use RPC function to fetch attendance records
        const { data: attList, error } = await supabase.rpc('fn_get_attendance_by_date', {
          p_user_id: userId,
          p_date: mobileDate
        });
        
        if (!error && attList && attList.length > 0) {
          attendancePunches = attList.map((item: any) => ({
            check_in: item.check_in || null,
            check_out: item.check_out || null,
            punch_order: item.punch_order || 1
          }));
          
          // Calculate total worked hours
          let totalMs = 0;
          for (const p of attendancePunches) {
            if (p.check_in && p.check_out) {
              totalMs += new Date(p.check_out).getTime() - new Date(p.check_in).getTime();
            }
          }
          if (totalMs > 0) {
            const hrs = Math.floor(totalMs / 3600000);
            const mins = Math.floor((totalMs % 3600000) / 60000);
            attendanceTotalHours = `${hrs}h ${mins}m`;
          }
        } else if (error) {
          console.warn('Error loading attendance:', error.message || error);
          // Silently fail - attendance is optional on home page
        }
      } catch (error) {
        console.error('Error loading attendance:', error);
      }
    }

    mobileLoading = false;
  }

  onMount(() => {
    loadMobileCardPermissions();
    loadMobileData();
  });
</script>

<div class="mobile-home">
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
      {/if}

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
          <div class="m-card-sub">No punches</div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .mobile-home {
    padding: 1rem;
    overflow-y: auto;
    height: 100%;
    background: var(--neutral-50);
  }

  .m-date-nav {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    margin-bottom: 1.5rem;
    padding: 1rem;
    background: white;
    border-radius: 10px;
    box-shadow: var(--shadow-sm);
    border: 1px solid var(--neutral-200);
  }

  .m-date-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--neutral-500);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0.5rem;
    transition: all 0.2s ease;
    border-radius: 6px;
  }

  .m-date-btn:hover {
    color: var(--brand-primary);
    background: rgba(249, 115, 22, 0.1);
  }

  .m-date-btn:active {
    color: var(--brand-primary);
  }

  .m-date-label {
    font-size: 1rem;
    font-weight: 600;
    color: var(--neutral-900);
    min-width: 120px;
    text-align: center;
  }

  .m-loading {
    text-align: center;
    padding: 2rem;
    color: var(--neutral-500);
    font-size: 1rem;
  }

  .m-cards {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1rem;
  }

  .m-card {
    background: white;
    border-radius: 12px;
    padding: 1.25rem 1rem;
    box-shadow: var(--shadow-sm);
    border: 1px solid var(--neutral-200);
    display: flex;
    flex-direction: column;
    transition: all 0.3s ease;
  }

  .m-card:hover {
    box-shadow: var(--shadow-md);
    transform: translateY(-2px);
    border-color: var(--brand-primary);
  }

  .m-card-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 10px;
    margin-bottom: 0.75rem;
    color: white;
    font-weight: 600;
  }

  .m-card.sales .m-card-icon {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  }

  .m-card.purchase .m-card-icon {
    background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
  }

  .m-card.expense .m-card-icon {
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  }

  .m-card.cash .m-card-icon {
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  }

  .m-card.bank .m-card-icon {
    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
  }

  .m-card.sales-bal .m-card-icon {
    background: linear-gradient(135deg, #06b6d4 0%, #0891b2 100%);
  }

  .m-card.purchase-bal .m-card-icon {
    background: linear-gradient(135deg, #ec4899 0%, #db2777 100%);
  }

  .m-card.attendance .m-card-icon {
    background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
  }

  .m-card-label {
    font-size: 0.75rem;
    color: var(--neutral-500);
    text-transform: uppercase;
    font-weight: 600;
    letter-spacing: 0.5px;
    margin-bottom: 0.5rem;
  }

  .m-card-amount {
    font-size: 1.4rem;
    font-weight: 700;
    color: var(--neutral-900);
    margin-bottom: 0.5rem;
  }

  .m-card-sub {
    font-size: 0.8rem;
    color: var(--neutral-500);
    font-weight: 500;
  }

  .m-card-punches {
    font-size: 0.8rem;
    margin-bottom: 0.5rem;
  }

  .punch-row {
    display: flex;
    justify-content: space-between;
    gap: 0.5rem;
    margin-bottom: 0.375rem;
    font-weight: 500;
  }

  .attend-in {
    color: var(--status-success);
  }

  .attend-out {
    color: var(--status-error);
  }

  .m-card-attend-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.8rem;
    margin-bottom: 0.5rem;
    font-weight: 500;
    color: var(--neutral-600);
  }

  .total-hrs {
    font-weight: 600;
    color: var(--neutral-700);
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border-width: 0;
  }

  @media (max-width: 480px) {
    .m-date-label {
      font-size: 0.9rem;
    }

    .m-card-amount {
      font-size: 1.2rem;
    }
  }
</style>
