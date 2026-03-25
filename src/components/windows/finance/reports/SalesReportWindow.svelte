<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  let sales: any[] = [];
  let loading = true;

  // Filters
  let fromDate = '';
  let toDate = '';
  let statusFilter = '';
  let customerSearch = '';

  // Totals
  $: filteredSales = applyFilters(sales, fromDate, toDate, statusFilter, customerSearch);
  $: totalNet = filteredSales.reduce((s: number, r: any) => s + (r.net_total || 0), 0);
  $: totalPaid = filteredSales.reduce((s: number, r: any) => s + (r.paid_amount || 0), 0);
  $: totalDue = filteredSales.reduce((s: number, r: any) => s + (r.balance_due || 0), 0);

  onMount(() => loadSales());

  function formatDateTime(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const yyyy = d.getFullYear();
    let h = d.getHours();
    const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12 || 12;
    return `${dd}/${mm}/${yyyy} ${h}:${min} ${ampm}`;
  }

  async function loadSales() {
    loading = true;
    const { data } = await supabase
      .from('sales')
      .select('id, bill_no, bill_date, created_at, customer_id, net_total, paid_amount, balance_due, status, created_by, customers(name), users:created_by(user_name, email)')
      .order('created_at', { ascending: false });
    sales = (data || []).map((s: any) => ({ ...s, customer_name: s.customers?.name || '—', created_by_email: s.users?.user_name || s.users?.email || '—' }));
    loading = false;
  }

  function applyFilters(list: any[], from: string, to: string, status: string, search: string) {
    let result = list;
    if (from) result = result.filter(r => r.bill_date >= from);
    if (to) result = result.filter(r => r.bill_date <= to);
    if (status) result = result.filter(r => r.status === status);
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      result = result.filter(r =>
        r.customer_name.toLowerCase().includes(q) ||
        (r.bill_no || '').toLowerCase().includes(q)
      );
    }
    return result;
  }

  function clearFilters() {
    fromDate = '';
    toDate = '';
    statusFilter = '';
    customerSearch = '';
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={() => windowStore.close('finance-sales-report')} title="Close">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Sales Report</h2>
    </div>
    <button class="btn-refresh" on:click={loadSales}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
      Refresh
    </button>
  </div>

  <!-- Filters -->
  <div class="filters-bar">
    <div class="filter-group">
      <label for="sr-from">From</label>
      <input id="sr-from" type="date" bind:value={fromDate} />
    </div>
    <div class="filter-group">
      <label for="sr-to">To</label>
      <input id="sr-to" type="date" bind:value={toDate} />
    </div>
    <div class="filter-group">
      <label for="sr-status">Status</label>
      <select id="sr-status" bind:value={statusFilter}>
        <option value="">All</option>
        <option value="posted">Posted</option>
        <option value="paid">Paid</option>
      </select>
    </div>
    <div class="filter-group search-group">
      <label for="sr-search">Search</label>
      <input id="sr-search" type="text" placeholder="Customer / Bill #" bind:value={customerSearch} />
    </div>
    <button class="btn-clear" on:click={clearFilters}>Clear</button>
  </div>

  <!-- Summary cards -->
  <div class="summary-cards">
    <div class="s-card"><span class="s-label">Bills</span><span class="s-val">{filteredSales.length}</span></div>
    <div class="s-card"><span class="s-label">Total</span><span class="s-val">₹{totalNet.toFixed(2)}</span></div>
    <div class="s-card green"><span class="s-label">Paid</span><span class="s-val">₹{totalPaid.toFixed(2)}</span></div>
    <div class="s-card red"><span class="s-label">Due</span><span class="s-val">₹{totalDue.toFixed(2)}</span></div>
  </div>

  <!-- Table -->
  <div class="table-wrap">
    {#if loading}
      <div class="loading-msg">Loading sales...</div>
    {:else if filteredSales.length === 0}
      <div class="empty-msg">No sales found.</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Bill No</th>
            <th>Date & Time</th>
            <th>Customer</th>
            <th class="num">Net Total</th>
            <th class="num">Paid</th>
            <th class="num">Balance</th>
            <th>Status</th>
            <th>Created By</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredSales as row, idx (row.id)}
            <tr>
              <td>{idx + 1}</td>
              <td class="mono">{row.bill_no}</td>
              <td>{formatDateTime(row.created_at)}</td>
              <td>{row.customer_name}</td>
              <td class="num">₹{(row.net_total || 0).toFixed(2)}</td>
              <td class="num green-text">₹{(row.paid_amount || 0).toFixed(2)}</td>
              <td class="num" class:red-text={row.balance_due > 0}>₹{(row.balance_due || 0).toFixed(2)}</td>
              <td><span class="status-badge" class:paid={row.status === 'paid'} class:posted={row.status === 'posted'}>{row.status}</span></td>
              <td>{row.created_by_email}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>

<style>
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#C41E3A; color:#C41E3A; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .btn-refresh { display:flex; align-items:center; gap:5px; padding:6px 14px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; font-size:12px; font-weight:600; color:#374151; cursor:pointer; }
  .btn-refresh:hover { background:#e5e7eb; }

  .filters-bar { display:flex; align-items:flex-end; gap:12px; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; }
  .filter-group { display:flex; flex-direction:column; gap:3px; }
  .search-group { flex:1; min-width:150px; }
  .filter-group label { font-size:11px; font-weight:600; color:#6b7280; }
  .filter-group input, .filter-group select { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus, .filter-group select:focus { border-color:#C41E3A; }
  .btn-clear { padding:7px 14px; background:#fef2f2; border:1px solid #fecaca; border-radius:6px; font-size:12px; font-weight:600; color:#dc2626; cursor:pointer; align-self:flex-end; }
  .btn-clear:hover { background:#fee2e2; }

  .summary-cards { display:flex; gap:12px; padding:14px 18px; flex-shrink:0; }
  .s-card { flex:1; background:white; border:1px solid #e5e7eb; border-radius:8px; padding:12px 16px; display:flex; flex-direction:column; gap:2px; }
  .s-card.green { border-color:#86efac; background:#f0fdf4; }
  .s-card.red { border-color:#fecaca; background:#fef2f2; }
  .s-label { font-size:11px; font-weight:600; color:#6b7280; text-transform:uppercase; }
  .s-val { font-size:16px; font-weight:700; color:#111827; font-family:'Courier New',monospace; }
  .s-card.green .s-val { color:#16a34a; }
  .s-card.red .s-val { color:#dc2626; }

  .table-wrap { flex:1; overflow:auto; padding:0 18px 18px; width:100%; box-sizing:border-box; }
  table { width:100%; border-collapse:collapse; font-size:13px; background:white; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; }
  thead { position:sticky; top:0; z-index:2; }
  th { padding:9px 10px; background:#f9fafb; font-weight:600; color:#6b7280; text-align:left; border-bottom:1px solid #e5e7eb; border-right:1px solid #e5e7eb; font-size:11px; text-transform:uppercase; }
  td { padding:8px 10px; border-bottom:1px solid #f3f4f6; border-right:1px solid #e5e7eb; color:#374151; }
  .num { text-align:right; font-family:'Courier New',monospace; font-weight:600; }
  th.num { text-align:right; }
  .mono { font-family:'Courier New',monospace; font-weight:600; color:#C41E3A; }
  .green-text { color:#16a34a; }
  .red-text { color:#dc2626; }
  .status-badge { padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; text-transform:capitalize; }
  .status-badge.paid { background:#dcfce7; color:#16a34a; }
  .status-badge.posted { background:#fff7ed; color:#C41E3A; }
  .loading-msg, .empty-msg { text-align:center; color:#9ca3af; padding:40px 0; font-size:14px; }
</style>
