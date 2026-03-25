<!-- Payment History Modal Component -->
<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { supabase } from '../../../lib/supabaseClient';

  export let employee: any;

  const dispatch = createEventDispatcher();

  interface PaymentRecord {
    id: string;
    payment_date: string;
    payment_time: string;
    total_salary: number;
    amount_paid: number;
    payment_method: string;
    description: string;
  }

  let payments: PaymentRecord[] = [];
  let loading = true;
  let filter = 'all'; // all, current_month, last_month
  let totalPaid = 0;

  const paymentMethodLabels: { [key: string]: string } = {
    bank_transfer: 'Bank Transfer',
    cash: 'Cash',
    check: 'Check',
    upi: 'UPI',
  };

  onMount(() => {
    loadPaymentHistory();
  });

  async function loadPaymentHistory() {
    loading = true;
    let query = supabase
      .from('salary_payments')
      .select('*')
      .eq('user_id', employee.id)
      .order('payment_date', { ascending: false })
      .order('payment_time', { ascending: false });

    if (filter === 'current_month') {
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0];
      query = query.gte('payment_date', monthStart).lte('payment_date', monthEnd);
    } else if (filter === 'last_month') {
      const now = new Date();
      const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString().split('T')[0];
      const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0).toISOString().split('T')[0];
      query = query.gte('payment_date', lastMonthStart).lte('payment_date', lastMonthEnd);
    }

    const { data, error } = await query;
    if (error) {
      console.error('Error loading payments:', error);
    } else {
      payments = data || [];
      totalPaid = payments.reduce((sum, p) => sum + p.amount_paid, 0);
    }
    loading = false;
  }

  function formatDate(dateStr: string): string {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
  }

  function formatDateTime(dateStr: string, timeStr: string): string {
    if (!timeStr) return formatDate(dateStr);
    const [hours, minutes] = timeStr.split(':');
    const h = parseInt(hours);
    const m = parseInt(minutes);
    const ampm = h >= 12 ? 'PM' : 'AM';
    const displayH = h % 12 || 12;
    return `${formatDate(dateStr)} ${String(displayH).padStart(2, '0')}:${String(m).padStart(2, '0')} ${ampm}`;
  }

  function formatCurrency(val: number): string {
    return val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  $: if (filter) loadPaymentHistory();
</script>

<div class="modal-overlay" on:click={() => dispatch('close')}>
  <div class="modal" on:click|stopPropagation>
    <div class="modal-header">
      <h3>📋 Payment History</h3>
      <button class="close-btn" on:click={() => dispatch('close')}>×</button>
    </div>

    <div class="modal-controls">
      <div class="employee-name">{employee.user_name || employee.email}</div>
      <div class="filter-tabs">
        <button
          class="tab"
          class:active={filter === 'all'}
          on:click={() => (filter = 'all')}
        >
          All
        </button>
        <button
          class="tab"
          class:active={filter === 'current_month'}
          on:click={() => (filter = 'current_month')}
        >
          Current Month
        </button>
        <button
          class="tab"
          class:active={filter === 'last_month'}
          on:click={() => (filter = 'last_month')}
        >
          Last Month
        </button>
      </div>
    </div>

    <div class="modal-body">
      {#if loading}
        <div class="status-msg">Loading payment history...</div>
      {:else if payments.length === 0}
        <div class="status-msg">No payments found.</div>
      {:else}
        <div class="summary-info">
          <div class="summary-item">
            <span class="label">Total Payments</span>
            <span class="value">{payments.length}</span>
          </div>
          <div class="summary-item">
            <span class="label">Total Paid</span>
            <span class="value amount">₹{formatCurrency(totalPaid)}</span>
          </div>
        </div>

        <table class="payments-table">
          <thead>
            <tr>
              <th>Date & Time</th>
              <th>Total Salary</th>
              <th>Amount Paid</th>
              <th>Method</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody>
            {#each payments as payment (payment.id)}
              <tr>
                <td class="date-time">
                  {formatDateTime(payment.payment_date, payment.payment_time)}
                </td>
                <td class="amt">₹{formatCurrency(payment.total_salary)}</td>
                <td class="amt paid">₹{formatCurrency(payment.amount_paid)}</td>
                <td class="method">
                  <span class="badge">{paymentMethodLabels[payment.payment_method] || payment.payment_method}</span>
                </td>
                <td class="description">{payment.description || '—'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <div class="modal-footer">
      <button class="btn-close" on:click={() => dispatch('close')}>Close</button>
    </div>
  </div>
</div>

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .modal {
    background: white;
    border-radius: 8px;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
    width: 90%;
    max-width: 800px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
  }

  .modal-header {
    padding: 16px 20px;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 24px;
    cursor: pointer;
    color: #6b7280;
    padding: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    color: #111827;
  }

  .modal-controls {
    padding: 12px 20px;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .employee-name {
    font-size: 13px;
    color: #6b7280;
    margin-bottom: 8px;
  }

  .filter-tabs {
    display: flex;
    gap: 4px;
  }

  .tab {
    padding: 6px 12px;
    background: #f3f4f6;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 500;
    color: #6b7280;
    transition: all 0.15s;
  }

  .tab:hover {
    background: #e5e7eb;
  }

  .tab.active {
    background: #f59e0b;
    border-color: #f59e0b;
    color: white;
  }

  .modal-body {
    padding: 16px 20px;
    overflow-y: auto;
    flex: 1;
  }

  .status-msg {
    padding: 20px;
    text-align: center;
    color: #9ca3af;
    font-size: 13px;
  }

  .summary-info {
    display: flex;
    gap: 20px;
    margin-bottom: 16px;
    padding: 12px;
    background: #f9fafb;
    border-radius: 6px;
  }

  .summary-item {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .summary-item .label {
    font-size: 11px;
    color: #6b7280;
    font-weight: 600;
  }

  .summary-item .value {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
  }

  .summary-item .value.amount {
    color: #16a34a;
    font-family: 'Courier New', monospace;
  }

  .payments-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
    background: white;
  }

  thead th {
    background: #f9fafb;
    padding: 8px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 2px solid #e5e7eb;
    white-space: nowrap;
  }

  tbody td {
    padding: 8px;
    border-bottom: 1px solid #f3f4f6;
    color: #111827;
  }

  tbody tr:hover {
    background: #fffbeb;
  }

  .date-time {
    font-family: 'Courier New', monospace;
    font-size: 11px;
    color: #6b7280;
  }

  .amt {
    text-align: right;
    font-family: 'Courier New', monospace;
    font-weight: 500;
  }

  .amt.paid {
    color: #16a34a;
  }

  .method {
    text-align: center;
  }

  .badge {
    display: inline-block;
    padding: 2px 6px;
    background: #eff6ff;
    border: 1px solid #bfdbfe;
    border-radius: 3px;
    font-size: 10px;
    color: #1e40af;
    font-weight: 500;
  }

  .description {
    font-size: 11px;
    color: #6b7280;
    max-width: 200px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .modal-footer {
    padding: 12px 20px;
    border-top: 1px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    flex-shrink: 0;
  }

  .btn-close {
    padding: 8px 16px;
    background: #f59e0b;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    transition: all 0.15s;
  }

  .btn-close:hover {
    background: #d97706;
  }
</style>
