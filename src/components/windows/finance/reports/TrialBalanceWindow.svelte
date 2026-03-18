<!-- ============================================================
     FINANCE > REPORTS > TRIAL BALANCE
     Purpose: List all ledger accounts with Dr/Cr totals
     As per Indian Accounting Standards
     Must show: Opening, Transactions, Closing balances
     Total Debit MUST equal Total Credit
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface TBRow {
    id: string;
    ledger_name: string;
    category: string;
    type_name: string;
    opening_balance: number;
    total_debit: number;
    total_credit: number;
    closing_balance: number;
  }

  let rows: TBRow[] = [];
  let loading = true;
  let asOnDate = '';

  $: totalDr = rows.reduce((s, r) => s + (r.closing_balance > 0 ? r.closing_balance : 0), 0);
  $: totalCr = rows.reduce((s, r) => s + (r.closing_balance < 0 ? Math.abs(r.closing_balance) : 0), 0);
  $: totalOpenDr = rows.reduce((s, r) => s + (r.opening_balance > 0 ? r.opening_balance : 0), 0);
  $: totalOpenCr = rows.reduce((s, r) => s + (r.opening_balance < 0 ? Math.abs(r.opening_balance) : 0), 0);
  $: totalTxnDr = rows.reduce((s, r) => s + r.total_debit, 0);
  $: totalTxnCr = rows.reduce((s, r) => s + r.total_credit, 0);

  onMount(() => {
    const now = new Date();
    asOnDate = now.toISOString().split('T')[0];
    loadTrialBalance();
  });

  function formatAmt(val: number): string {
    if (val === 0) return '';
    return '₹' + Math.abs(val).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function formatBal(val: number): string {
    if (val === 0) return '₹0.00';
    return val > 0
      ? '₹' + val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' Dr'
      : '₹' + Math.abs(val).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' Cr';
  }

  async function loadTrialBalance() {
    loading = true;

    // Fetch all ledgers with their type info
    const { data: ledgers } = await supabase
      .from('ledger')
      .select('id, ledger_name, opening_balance, ledger_types(name, category)')
      .eq('status', 'active')
      .order('ledger_name');

    // Fetch all ledger entries up to asOnDate
    let entryQuery = supabase
      .from('ledger_entries')
      .select('ledger_id, debit, credit');
    if (asOnDate) entryQuery = entryQuery.lte('entry_date', asOnDate);
    const { data: entries } = await entryQuery;

    // Group entries by ledger_id
    const entryMap: Record<string, { dr: number; cr: number }> = {};
    for (const e of (entries || [])) {
      if (!entryMap[e.ledger_id]) entryMap[e.ledger_id] = { dr: 0, cr: 0 };
      entryMap[e.ledger_id].dr += e.debit || 0;
      entryMap[e.ledger_id].cr += e.credit || 0;
    }

    // Build rows
    rows = ((ledgers || []) as any[]).map((l: any) => {
      const opening = l.opening_balance || 0;
      const txnDr = entryMap[l.id]?.dr || 0;
      const txnCr = entryMap[l.id]?.cr || 0;
      const closing = opening + txnDr - txnCr;
      return {
        id: l.id,
        ledger_name: l.ledger_name,
        category: l.ledger_types?.category || '—',
        type_name: l.ledger_types?.name || '—',
        opening_balance: opening,
        total_debit: txnDr,
        total_credit: txnCr,
        closing_balance: closing,
      };
    }).filter((r: TBRow) => r.opening_balance !== 0 || r.total_debit !== 0 || r.total_credit !== 0);

    loading = false;
  }

  function handleDateChange() {
    loadTrialBalance();
  }

  function handleBack() {
    windowStore.close('finance-trial-balance');
  }

  function formatDate(dt: string): string {
    if (!dt) return '';
    const d = new Date(dt + 'T00:00:00');
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div>
        <h2>Trial Balance</h2>
        <span class="subtitle">As on {formatDate(asOnDate)}</span>
      </div>
    </div>
    <div class="header-right">
      <label for="tb-date">As on Date</label>
      <input id="tb-date" type="date" bind:value={asOnDate} on:change={handleDateChange} />
    </div>
  </div>

  <div class="table-wrap">
    {#if loading}
      <div class="status-msg">Loading trial balance...</div>
    {:else if rows.length === 0}
      <div class="status-msg">No ledger accounts with transactions found.</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Ledger Account</th>
            <th>Group</th>
            <th class="amt">Opening Dr</th>
            <th class="amt">Opening Cr</th>
            <th class="amt">Transaction Dr</th>
            <th class="amt">Transaction Cr</th>
            <th class="amt">Closing Dr</th>
            <th class="amt">Closing Cr</th>
          </tr>
        </thead>
        <tbody>
          {#each rows as row, i (row.id)}
            <tr>
              <td class="num">{i + 1}</td>
              <td class="ledger-name">{row.ledger_name}</td>
              <td><span class="cat-badge cat-{row.category}">{row.type_name}</span></td>
              <td class="amt">{row.opening_balance > 0 ? formatAmt(row.opening_balance) : ''}</td>
              <td class="amt">{row.opening_balance < 0 ? formatAmt(row.opening_balance) : ''}</td>
              <td class="amt">{row.total_debit > 0 ? formatAmt(row.total_debit) : ''}</td>
              <td class="amt">{row.total_credit > 0 ? formatAmt(row.total_credit) : ''}</td>
              <td class="amt dr">{row.closing_balance > 0 ? formatAmt(row.closing_balance) : ''}</td>
              <td class="amt cr">{row.closing_balance < 0 ? formatAmt(row.closing_balance) : ''}</td>
            </tr>
          {/each}
        </tbody>
        <tfoot>
          <tr class="total-row">
            <td></td>
            <td class="total-label">Total</td>
            <td></td>
            <td class="amt">{formatAmt(totalOpenDr)}</td>
            <td class="amt">{formatAmt(totalOpenCr)}</td>
            <td class="amt">{formatAmt(totalTxnDr)}</td>
            <td class="amt">{formatAmt(totalTxnCr)}</td>
            <td class="amt dr">{formatAmt(totalDr)}</td>
            <td class="amt cr">{formatAmt(totalCr)}</td>
          </tr>
        </tfoot>
      </table>

      <div class="balance-check">
        {#if Math.abs(totalDr - totalCr) < 0.01}
          <span class="balanced">✓ Trial Balance is Balanced (Dr = Cr)</span>
        {:else}
          <span class="unbalanced">✗ Difference: {formatAmt(Math.abs(totalDr - totalCr))}</span>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .header-right { display:flex; align-items:center; gap:8px; }
  .header-right label { font-size:12px; font-weight:600; color:#6b7280; }
  .header-right input { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .subtitle { font-size:11px; color:#9ca3af; }

  .table-wrap { flex:1; overflow:auto; padding:12px 18px; width:100%; box-sizing:border-box; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  thead th { background:#f9fafb; padding:10px 12px; text-align:left; font-weight:600; color:#374151; border-bottom:2px solid #e5e7eb; border-right:1px solid #e5e7eb; position:sticky; top:0; z-index:1; }
  tbody td { padding:8px 12px; border-bottom:1px solid #f3f4f6; border-right:1px solid #e5e7eb; color:#111827; }
  tbody tr:hover { background:#fffbeb; }
  tfoot td { padding:10px 12px; font-weight:700; border-top:2px solid #374151; }
  .num { width:30px; color:#9ca3af; }
  .ledger-name { font-weight:600; }
  .amt { text-align:right; font-family:'Courier New',monospace; white-space:nowrap; }
  .dr { color:#dc2626; }
  .cr { color:#16a34a; }
  .total-label { font-weight:700; font-size:14px; }
  .total-row td { background:#f9fafb; }

  .cat-badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:500; }
  .cat-asset { background:#dbeafe; color:#1d4ed8; }
  .cat-liability { background:#fce7f3; color:#be185d; }
  .cat-equity { background:#ede9fe; color:#7c3aed; }
  .cat-revenue { background:#dcfce7; color:#16a34a; }
  .cat-expense { background:#fee2e2; color:#dc2626; }

  .balance-check { text-align:center; padding:16px; }
  .balanced { font-size:14px; font-weight:700; color:#16a34a; background:#dcfce7; padding:8px 20px; border-radius:6px; }
  .unbalanced { font-size:14px; font-weight:700; color:#dc2626; background:#fee2e2; padding:8px 20px; border-radius:6px; }

  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }
</style>
