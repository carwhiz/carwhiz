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

    // For each ledger, compute running balance from sales/purchases/receipts/payments
    const rows = (data || []).map((l: any) => ({
      ...l,
      type_name: l.ledger_types?.name || '—',
      balance: l.opening_balance || 0,
    }));

    // Fetch all financial movements to compute balances
    const [salesRes, purchasesRes, receiptsRes, paymentsRes] = await Promise.all([
      supabase.from('sales').select('ledger_id, net_total, paid_amount'),
      supabase.from('purchases').select('ledger_id, net_total, paid_amount'),
      supabase.from('receipts').select('ledger_id, cash_bank_ledger_id, amount'),
      supabase.from('payments').select('ledger_id, cash_bank_ledger_id, amount'),
    ]);

    const salesData = salesRes.data || [];
    const purchasesData = purchasesRes.data || [];
    const receiptsData = receiptsRes.data || [];
    const paymentsData = paymentsRes.data || [];

    // Build balance map: ledger_id -> net movement
    const balMap: Record<string, number> = {};
    const addBal = (id: string, amt: number) => { if (id) { balMap[id] = (balMap[id] || 0) + amt; } };

    // Sales: customer ledger gets debited (balance_due increases receivable)
    for (const s of salesData) { addBal(s.ledger_id, s.net_total || 0); }
    // Purchases: vendor ledger gets credited (balance_due increases payable)
    for (const p of purchasesData) { addBal(p.ledger_id, p.net_total || 0); }
    // Receipts: reduces customer receivable, increases cash/bank
    for (const r of receiptsData) {
      addBal(r.ledger_id, -(r.amount || 0));
      addBal(r.cash_bank_ledger_id, r.amount || 0);
    }
    // Payments: reduces vendor payable, decreases cash/bank
    for (const p of paymentsData) {
      addBal(p.ledger_id, -(p.amount || 0));
      addBal(p.cash_bank_ledger_id, -(p.amount || 0));
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

    // Gather all transactions for this ledger
    const txns: any[] = [];

    // Sales where this is the customer ledger
    const { data: salesData } = await supabase
      .from('sales')
      .select('id, bill_no, bill_date, net_total, paid_amount, balance_due')
      .eq('ledger_id', ledger.id)
      .order('bill_date', { ascending: false });
    for (const s of (salesData || [])) {
      txns.push({ date: s.bill_date, ref: s.bill_no, type: 'Sale', debit: s.net_total || 0, credit: 0 });
    }

    // Purchases where this is the vendor ledger
    const { data: purchData } = await supabase
      .from('purchases')
      .select('id, invoice_no, invoice_date, net_total, paid_amount, balance_due')
      .eq('ledger_id', ledger.id)
      .order('invoice_date', { ascending: false });
    for (const p of (purchData || [])) {
      txns.push({ date: p.invoice_date, ref: p.invoice_no, type: 'Purchase', debit: 0, credit: p.net_total || 0 });
    }

    // Receipts where this is the customer ledger (credit) or cash/bank ledger (debit)
    const { data: recData } = await supabase
      .from('receipts')
      .select('id, receipt_no, receipt_date, amount, ledger_id, cash_bank_ledger_id')
      .or(`ledger_id.eq.${ledger.id},cash_bank_ledger_id.eq.${ledger.id}`)
      .order('receipt_date', { ascending: false });
    for (const r of (recData || [])) {
      if (r.ledger_id === ledger.id) {
        txns.push({ date: r.receipt_date, ref: r.receipt_no, type: 'Receipt', debit: 0, credit: r.amount || 0 });
      }
      if (r.cash_bank_ledger_id === ledger.id) {
        txns.push({ date: r.receipt_date, ref: r.receipt_no, type: 'Receipt', debit: r.amount || 0, credit: 0 });
      }
    }

    // Payments where this is the vendor ledger (debit) or cash/bank ledger (credit)
    const { data: payData } = await supabase
      .from('payments')
      .select('id, payment_no, payment_date, amount, ledger_id, cash_bank_ledger_id')
      .or(`ledger_id.eq.${ledger.id},cash_bank_ledger_id.eq.${ledger.id}`)
      .order('payment_date', { ascending: false });
    for (const p of (payData || [])) {
      if (p.ledger_id === ledger.id) {
        txns.push({ date: p.payment_date, ref: p.payment_no, type: 'Payment', debit: p.amount || 0, credit: 0 });
      }
      if (p.cash_bank_ledger_id === ledger.id) {
        txns.push({ date: p.payment_date, ref: p.payment_no, type: 'Payment', debit: 0, credit: p.amount || 0 });
      }
    }

    // Sort by date desc
    txns.sort((a, b) => (b.date || '').localeCompare(a.date || ''));

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
        <span class="ds-val">₹{(selectedLedger.opening_balance || 0).toFixed(2)}</span>
      </div>
      <div class="ds-item">
        <span class="ds-label">Current Balance</span>
        <span class="ds-val" class:positive={selectedLedger.balance >= 0} class:negative={selectedLedger.balance < 0}>₹{(selectedLedger.balance || 0).toFixed(2)}</span>
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
              <th>Date</th>
              <th>Reference</th>
              <th>Type</th>
              <th class="num">Debit</th>
              <th class="num">Credit</th>
            </tr>
          </thead>
          <tbody>
            {#each ledgerTransactions as txn, idx (idx)}
              <tr>
                <td>{idx + 1}</td>
                <td>{txn.date}</td>
                <td class="mono">{txn.ref}</td>
                <td><span class="txn-type" class:sale={txn.type==='Sale'} class:purchase={txn.type==='Purchase'} class:receipt={txn.type==='Receipt'} class:payment={txn.type==='Payment'}>{txn.type}</span></td>
                <td class="num">{txn.debit ? '₹' + txn.debit.toFixed(2) : '—'}</td>
                <td class="num">{txn.credit ? '₹' + txn.credit.toFixed(2) : '—'}</td>
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
                <td class="num">₹{(ledger.opening_balance || 0).toFixed(2)}</td>
                <td class="num" class:positive={ledger.balance > 0} class:negative={ledger.balance < 0}>₹{(ledger.balance || 0).toFixed(2)}</td>
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
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fff7ed; border-color:#F97316; color:#EA580C; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .type-tag { font-size:11px; font-weight:600; padding:3px 8px; background:#eef2ff; color:#4f46e5; border-radius:6px; border:1px solid #c7d2fe; }
  .btn-refresh { display:flex; align-items:center; gap:5px; padding:6px 14px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; font-size:12px; font-weight:600; color:#374151; cursor:pointer; }
  .btn-refresh:hover { background:#e5e7eb; }

  .filters-bar { display:flex; align-items:flex-end; gap:12px; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; }
  .filter-group { display:flex; flex-direction:column; gap:3px; }
  .search-group { flex:1; min-width:180px; }
  .filter-group label { font-size:11px; font-weight:600; color:#6b7280; }
  .filter-group input, .filter-group select { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus, .filter-group select:focus { border-color:#F97316; }

  .detail-summary { display:flex; gap:16px; padding:16px 18px; flex-shrink:0; }
  .ds-item { flex:1; background:white; border:1px solid #e5e7eb; border-radius:8px; padding:14px 18px; display:flex; flex-direction:column; gap:4px; }
  .ds-label { font-size:11px; font-weight:600; color:#6b7280; text-transform:uppercase; }
  .ds-val { font-size:18px; font-weight:700; color:#111827; font-family:'Courier New',monospace; }
  .ds-val.positive { color:#16a34a; }
  .ds-val.negative { color:#dc2626; }

  .table-wrap { flex:1; overflow:auto; padding:0 18px 18px; }
  table { width:100%; border-collapse:collapse; font-size:13px; background:white; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; }
  thead { position:sticky; top:0; z-index:2; }
  th { padding:9px 10px; background:#f9fafb; font-weight:600; color:#6b7280; text-align:left; border-bottom:1px solid #e5e7eb; font-size:11px; text-transform:uppercase; }
  td { padding:8px 10px; border-bottom:1px solid #f3f4f6; color:#374151; }
  .num { text-align:right; font-family:'Courier New',monospace; font-weight:600; }
  th.num { text-align:right; }
  .mono { font-family:'Courier New',monospace; font-weight:600; color:#F97316; }
  .positive { color:#16a34a; }
  .negative { color:#dc2626; }
  .ledger-name { font-weight:500; }
  .type-badge { padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; background:#f3f4f6; color:#6b7280; }
  .txn-type { padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; }
  .txn-type.sale { background:#fff7ed; color:#EA580C; }
  .txn-type.purchase { background:#eef2ff; color:#4f46e5; }
  .txn-type.receipt { background:#f0fdf4; color:#16a34a; }
  .txn-type.payment { background:#fef2f2; color:#dc2626; }
  .view-btn { padding:4px 12px; background:#fff7ed; border:1px solid #fed7aa; border-radius:5px; font-size:12px; font-weight:600; color:#EA580C; cursor:pointer; }
  .view-btn:hover { background:#fed7aa; }
  .loading-msg, .empty-msg { text-align:center; color:#9ca3af; padding:40px 0; font-size:14px; }
</style>
