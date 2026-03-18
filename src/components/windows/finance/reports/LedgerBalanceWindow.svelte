<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  let ledgers: any[] = [];
  let loading = true;

  // Filters
  let searchQuery = '';
  let typeFilter = '';
  let ledgerTypes: any[] = [];

  // Indian accounting: show Dr/Cr suffix
  function formatBal(val: number): string {
    if (val === 0) return '₹0.00';
    return val > 0 ? `₹${val.toFixed(2)} Dr` : `₹${Math.abs(val).toFixed(2)} Cr`;
  }

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

  // Selected ledger for detail view
  let selectedLedger: any = null;
  let ledgerTransactions: any[] = [];
  let loadingDetail = false;

  $: filteredLedgers = applyFilters(ledgers, searchQuery, typeFilter);

  onMount(async () => {
    await Promise.all([loadLedgers(), loadLedgerTypes()]);
  });

  async function loadLedgerTypes() {
    const { data } = await supabase.from('ledger_types').select('id, name').order('name');
    ledgerTypes = data || [];
  }

  async function loadLedgers() {
    loading = true;
    const { data } = await supabase
      .from('ledger')
      .select('id, ledger_name, opening_balance, ledger_type_id, status, ledger_types(name)')
      .order('ledger_name');

    const rows = (data || []).map((l: any) => ({
      ...l,
      type_name: l.ledger_types?.name || '—',
      balance: l.opening_balance || 0,
    }));

    // Fetch all ledger entries to compute balances
    const { data: entries } = await supabase
      .from('ledger_entries')
      .select('ledger_id, debit, credit');

    const balMap: Record<string, number> = {};
    for (const e of (entries || [])) {
      if (e.ledger_id) {
        balMap[e.ledger_id] = (balMap[e.ledger_id] || 0) + (e.debit || 0) - (e.credit || 0);
      }
    }

    for (const row of rows) {
      row.balance = (row.opening_balance || 0) + (balMap[row.id] || 0);
    }

    ledgers = rows;
    loading = false;
  }

  function applyFilters(list: any[], search: string, type: string) {
    let result = list;
    if (type) result = result.filter(r => r.ledger_type_id === type);
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      result = result.filter(r => r.ledger_name.toLowerCase().includes(q));
    }
    return result;
  }

  async function viewLedgerDetail(ledger: any) {
    selectedLedger = ledger;
    loadingDetail = true;
    ledgerTransactions = [];

    // Fetch all ledger entries for this ledger
    const { data: entries } = await supabase
      .from('ledger_entries')
      .select('id, entry_date, created_at, debit, credit, narration, reference_type, reference_id')
      .eq('ledger_id', ledger.id)
      .order('entry_date', { ascending: true })
      .order('id', { ascending: true });

    let runBal = ledger.opening_balance || 0;
    const txns = (entries || []).map((e: any) => {
      let type = 'Entry';
      if (e.reference_type === 'sales') type = 'Sale';
      else if (e.reference_type === 'purchases') type = 'Purchase';
      else if (e.reference_type === 'receipts') type = 'Receipt';
      else if (e.reference_type === 'payments') type = 'Payment';

      runBal += (e.debit || 0) - (e.credit || 0);

      return {
        date: e.created_at || e.entry_date,
        ref: e.narration || '—',
        type,
        debit: e.debit || 0,
        credit: e.credit || 0,
        balance: runBal,
      };
    });

    ledgerTransactions = txns;
    loadingDetail = false;
  }

  function closeDetail() {
    selectedLedger = null;
    ledgerTransactions = [];
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      {#if selectedLedger}
        <button class="back-btn" on:click={closeDetail} title="Back to list">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>{selectedLedger.ledger_name}</h2>
        <span class="type-tag">{selectedLedger.type_name}</span>
      {:else}
        <button class="back-btn" on:click={() => windowStore.close('finance-ledger-balance')} title="Close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>Ledger Balance</h2>
      {/if}
    </div>
    {#if !selectedLedger}
      <button class="btn-refresh" on:click={loadLedgers}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
        Refresh
      </button>
    {/if}
  </div>

  {#if selectedLedger}
    <!-- ===== DETAIL VIEW: Transaction list ===== -->
    <div class="detail-summary">
      <div class="ds-item">
        <span class="ds-label">Opening Balance</span>
        <span class="ds-val">{formatBal(selectedLedger.opening_balance || 0)}</span>
      </div>
      <div class="ds-item">
        <span class="ds-label">Current Balance</span>
        <span class="ds-val" class:positive={selectedLedger.balance >= 0} class:negative={selectedLedger.balance < 0}>{formatBal(selectedLedger.balance || 0)}</span>
      </div>
      <div class="ds-item">
        <span class="ds-label">Transactions</span>
        <span class="ds-val">{ledgerTransactions.length}</span>
      </div>
    </div>

    <div class="table-wrap">
      {#if loadingDetail}
        <div class="loading-msg">Loading transactions...</div>
      {:else if ledgerTransactions.length === 0}
        <div class="empty-msg">No transactions found for this ledger.</div>
      {:else}
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Date & Time</th>
              <th>Reference</th>
              <th>Type</th>
              <th class="num">Debit</th>
              <th class="num">Credit</th>
              <th class="num">Balance</th>
            </tr>
          </thead>
          <tbody>
            <tr class="opening-row">
              <td></td>
              <td></td>
              <td class="mono">Opening Balance</td>
              <td></td>
              <td class="num">—</td>
              <td class="num">—</td>
              <td class="num" class:positive={(selectedLedger.opening_balance||0)>0} class:negative={(selectedLedger.opening_balance||0)<0}>{formatBal(selectedLedger.opening_balance || 0)}</td>
            </tr>
            {#each ledgerTransactions as txn, idx (idx)}
              <tr>
                <td>{idx + 1}</td>
                <td>{formatDateTime(txn.date)}</td>
                <td class="mono">{txn.ref}</td>
                <td><span class="txn-type" class:sale={txn.type==='Sale'} class:purchase={txn.type==='Purchase'} class:receipt={txn.type==='Receipt'} class:payment={txn.type==='Payment'}>{txn.type}</span></td>
                <td class="num">{txn.debit ? '₹' + txn.debit.toFixed(2) : '—'}</td>
                <td class="num">{txn.credit ? '₹' + txn.credit.toFixed(2) : '—'}</td>
                <td class="num" class:positive={txn.balance > 0} class:negative={txn.balance < 0}>{formatBal(txn.balance)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

  {:else}
    <!-- ===== LIST VIEW: All ledgers with balances ===== -->
    <div class="filters-bar">
      <div class="filter-group">
        <label for="lb-type">Type</label>
        <select id="lb-type" bind:value={typeFilter}>
          <option value="">All Types</option>
          {#each ledgerTypes as lt (lt.id)}
            <option value={lt.id}>{lt.name}</option>
          {/each}
        </select>
      </div>
      <div class="filter-group search-group">
        <label for="lb-search">Search</label>
        <input id="lb-search" type="text" placeholder="Search ledger name..." bind:value={searchQuery} />
      </div>
    </div>

    <div class="table-wrap">
      {#if loading}
        <div class="loading-msg">Loading ledgers...</div>
      {:else if filteredLedgers.length === 0}
        <div class="empty-msg">No ledgers found.</div>
      {:else}
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Ledger Name</th>
              <th>Type</th>
              <th class="num">Opening</th>
              <th class="num">Balance</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {#each filteredLedgers as ledger, idx (ledger.id)}
              <tr>
                <td>{idx + 1}</td>
                <td class="ledger-name">{ledger.ledger_name}</td>
                <td><span class="type-badge">{ledger.type_name}</span></td>
                <td class="num">{formatBal(ledger.opening_balance || 0)}</td>
                <td class="num" class:positive={ledger.balance > 0} class:negative={ledger.balance < 0}>{formatBal(ledger.balance)}</td>
                <td><button class="view-btn" on:click={() => viewLedgerDetail(ledger)}>View</button></td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  {/if}
</div>

<style>
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#C41E3A; color:#C41E3A; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .type-tag { font-size:11px; font-weight:600; padding:3px 8px; background:#eef2ff; color:#4f46e5; border-radius:6px; border:1px solid #c7d2fe; }
  .btn-refresh { display:flex; align-items:center; gap:5px; padding:6px 14px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; font-size:12px; font-weight:600; color:#374151; cursor:pointer; }
  .btn-refresh:hover { background:#e5e7eb; }

  .filters-bar { display:flex; align-items:flex-end; gap:12px; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; }
  .filter-group { display:flex; flex-direction:column; gap:3px; }
  .search-group { flex:1; min-width:180px; }
  .filter-group label { font-size:11px; font-weight:600; color:#6b7280; }
  .filter-group input, .filter-group select { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus, .filter-group select:focus { border-color:#C41E3A; }

  .detail-summary { display:flex; gap:16px; padding:16px 18px; flex-shrink:0; }
  .ds-item { flex:1; background:white; border:1px solid #e5e7eb; border-radius:8px; padding:14px 18px; display:flex; flex-direction:column; gap:4px; }
  .ds-label { font-size:11px; font-weight:600; color:#6b7280; text-transform:uppercase; }
  .ds-val { font-size:18px; font-weight:700; color:#111827; font-family:'Courier New',monospace; }
  .ds-val.positive { color:#16a34a; }
  .ds-val.negative { color:#dc2626; }

  .table-wrap { flex:1; overflow:auto; padding:0 18px 18px; width:100%; box-sizing:border-box; }
  table { width:100%; border-collapse:collapse; font-size:13px; background:white; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; }
  thead { position:sticky; top:0; z-index:2; }
  th { padding:9px 10px; background:#f9fafb; font-weight:600; color:#6b7280; text-align:left; border-bottom:1px solid #e5e7eb; border-right:1px solid #e5e7eb; font-size:11px; text-transform:uppercase; }
  td { padding:8px 10px; border-bottom:1px solid #f3f4f6; border-right:1px solid #e5e7eb; color:#374151; }
  .num { text-align:right; font-family:'Courier New',monospace; font-weight:600; }
  th.num { text-align:right; }
  .mono { font-family:'Courier New',monospace; font-weight:600; color:#C41E3A; }
  .positive { color:#16a34a; }
  .negative { color:#dc2626; }
  .ledger-name { font-weight:500; }
  .type-badge { padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; background:#f3f4f6; color:#6b7280; }
  .txn-type { padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; }
  .txn-type.sale { background:#fff7ed; color:#C41E3A; }
  .txn-type.purchase { background:#eef2ff; color:#4f46e5; }
  .txn-type.receipt { background:#f0fdf4; color:#16a34a; }
  .txn-type.payment { background:#fef2f2; color:#dc2626; }
  .view-btn { padding:4px 12px; background:#fff7ed; border:1px solid #fed7aa; border-radius:5px; font-size:12px; font-weight:600; color:#C41E3A; cursor:pointer; }
  .opening-row td { background:#f9fafb; font-style:italic; color:#6b7280; }
  .view-btn:hover { background:#fed7aa; }
  .loading-msg, .empty-msg { text-align:center; color:#9ca3af; padding:40px 0; font-size:14px; }
</style>
