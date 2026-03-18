<!-- ============================================================
     FINANCE > REPORTS > BALANCE SHEET
     Purpose: Assets, Liabilities & Equity as per Indian Standards
     Schedule III format (Ind AS / Companies Act 2013)
     Equation: Assets = Liabilities + Equity + Net Profit/Loss
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface BSRow {
    id: string;
    ledger_name: string;
    type_name: string;
    category: string;
    balance: number; // positive = Dr, negative = Cr
  }

  let assetRows: BSRow[] = [];
  let liabilityRows: BSRow[] = [];
  let equityRows: BSRow[] = [];
  let netProfitLoss = 0;
  let loading = true;
  let asOnDate = '';

  // Financial year start for P&L calculation
  let fyStartDate = '';

  $: totalAssets = assetRows.reduce((s, r) => s + r.balance, 0);
  $: totalLiabilities = liabilityRows.reduce((s, r) => s + Math.abs(r.balance), 0);
  $: totalEquity = equityRows.reduce((s, r) => s + Math.abs(r.balance), 0);
  $: totalLiabEquity = totalLiabilities + totalEquity + (netProfitLoss > 0 ? netProfitLoss : 0);
  $: totalAssetsAdj = totalAssets + (netProfitLoss < 0 ? Math.abs(netProfitLoss) : 0);

  onMount(() => {
    const now = new Date();
    asOnDate = now.toISOString().split('T')[0];
    const fy = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    fyStartDate = `${fy}-04-01`;
    loadBalanceSheet();
  });

  function formatAmt(val: number): string {
    if (val === 0) return '₹0.00';
    return '₹' + Math.abs(val).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function formatDate(dt: string): string {
    if (!dt) return '';
    const d = new Date(dt + 'T00:00:00');
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  }

  async function loadBalanceSheet() {
    loading = true;

    // Fetch all ledgers
    const { data: ledgers } = await supabase
      .from('ledger')
      .select('id, ledger_name, opening_balance, ledger_types(name, category)')
      .eq('status', 'active')
      .order('ledger_name');

    // Fetch ALL ledger entries up to asOnDate (for balance sheet)
    let entryQuery = supabase.from('ledger_entries').select('ledger_id, debit, credit, entry_date');
    if (asOnDate) entryQuery = entryQuery.lte('entry_date', asOnDate);
    const { data: entries } = await entryQuery;

    // Group entries by ledger_id
    const entryMap: Record<string, { dr: number; cr: number }> = {};
    // Also track P&L period entries separately
    const plEntryMap: Record<string, { dr: number; cr: number }> = {};

    for (const e of (entries || [])) {
      if (!entryMap[e.ledger_id]) entryMap[e.ledger_id] = { dr: 0, cr: 0 };
      entryMap[e.ledger_id].dr += e.debit || 0;
      entryMap[e.ledger_id].cr += e.credit || 0;

      // P&L entries (current FY only)
      if (e.entry_date >= fyStartDate) {
        if (!plEntryMap[e.ledger_id]) plEntryMap[e.ledger_id] = { dr: 0, cr: 0 };
        plEntryMap[e.ledger_id].dr += e.debit || 0;
        plEntryMap[e.ledger_id].cr += e.credit || 0;
      }
    }

    // Classify accounts
    const assets: BSRow[] = [];
    const liabilities: BSRow[] = [];
    const equity: BSRow[] = [];
    let totalRevenue = 0;
    let totalExpense = 0;

    for (const l of (ledgers || []) as any[]) {
      const category = l.ledger_types?.category;
      const opening = l.opening_balance || 0;
      const txnDr = entryMap[l.id]?.dr || 0;
      const txnCr = entryMap[l.id]?.cr || 0;
      const balance = opening + txnDr - txnCr;

      const row: BSRow = {
        id: l.id,
        ledger_name: l.ledger_name,
        type_name: l.ledger_types?.name || '',
        category: category || '',
        balance,
      };

      if (category === 'asset') {
        if (balance !== 0) assets.push(row);
      } else if (category === 'liability') {
        if (balance !== 0) liabilities.push(row);
      } else if (category === 'equity') {
        if (balance !== 0) equity.push(row);
      } else if (category === 'revenue') {
        // Revenue for P&L (current FY)
        const plDr = plEntryMap[l.id]?.dr || 0;
        const plCr = plEntryMap[l.id]?.cr || 0;
        totalRevenue += (plCr - plDr); // Credit side is revenue
      } else if (category === 'expense') {
        // Expense for P&L (current FY)
        const plDr = plEntryMap[l.id]?.dr || 0;
        const plCr = plEntryMap[l.id]?.cr || 0;
        totalExpense += (plDr - plCr); // Debit side is expense
      }
    }

    assetRows = assets.sort((a, b) => b.balance - a.balance);
    liabilityRows = liabilities.sort((a, b) => a.balance - b.balance);
    equityRows = equity.sort((a, b) => a.balance - b.balance);
    netProfitLoss = totalRevenue - totalExpense;
    loading = false;
  }

  function handleDateChange() {
    const d = new Date(asOnDate + 'T00:00:00');
    const fy = d.getMonth() >= 3 ? d.getFullYear() : d.getFullYear() - 1;
    fyStartDate = `${fy}-04-01`;
    loadBalanceSheet();
  }

  function handleBack() {
    windowStore.close('finance-balance-sheet');
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div>
        <h2>Balance Sheet</h2>
        <span class="subtitle">As on {formatDate(asOnDate)}</span>
      </div>
    </div>
    <div class="header-right">
      <label for="bs-date">As on Date</label>
      <input id="bs-date" type="date" bind:value={asOnDate} on:change={handleDateChange} />
    </div>
  </div>

  <div class="bs-body">
    {#if loading}
      <div class="status-msg">Loading Balance Sheet...</div>
    {:else}
      <div class="bs-layout">
        <!-- LEFT: Liabilities & Equity -->
        <div class="bs-side">
          <div class="bs-side-header cr-header">
            <h3>Liabilities & Equity</h3>
          </div>

          <!-- Equity / Capital -->
          {#if equityRows.length > 0}
            <div class="bs-section">
              <div class="section-title">I. Shareholders' Funds / Capital</div>
              {#each equityRows as row (row.id)}
                <div class="bs-row">
                  <span class="bs-name">{row.ledger_name}</span>
                  <span class="bs-amt">{formatAmt(row.balance)}</span>
                </div>
              {/each}
              <div class="section-sub-total">
                <span>Sub Total</span>
                <span>{formatAmt(totalEquity)}</span>
              </div>
            </div>
          {/if}

          <!-- Current Year P&L -->
          <div class="bs-section">
            <div class="section-title">II. Profit & Loss (Current Year)</div>
            <div class="bs-row" class:profit-row={netProfitLoss >= 0} class:loss-row={netProfitLoss < 0}>
              <span class="bs-name">{netProfitLoss >= 0 ? 'Net Profit' : 'Net Loss'}</span>
              <span class="bs-amt">{formatAmt(netProfitLoss)}</span>
            </div>
          </div>

          <!-- Non-Current Liabilities -->
          {#if liabilityRows.some(r => ['Vehicle Loan', 'Equipment Loan', 'Business Loan'].includes(r.ledger_name))}
            <div class="bs-section">
              <div class="section-title">III. Non-Current Liabilities</div>
              {#each liabilityRows.filter(r => ['Vehicle Loan', 'Equipment Loan', 'Business Loan'].includes(r.ledger_name)) as row (row.id)}
                <div class="bs-row">
                  <span class="bs-name">{row.ledger_name}</span>
                  <span class="bs-amt">{formatAmt(row.balance)}</span>
                </div>
              {/each}
            </div>
          {/if}

          <!-- Current Liabilities -->
          {#if liabilityRows.some(r => !['Vehicle Loan', 'Equipment Loan', 'Business Loan'].includes(r.ledger_name))}
            <div class="bs-section">
              <div class="section-title">IV. Current Liabilities</div>
              {#each liabilityRows.filter(r => !['Vehicle Loan', 'Equipment Loan', 'Business Loan'].includes(r.ledger_name)) as row (row.id)}
                <div class="bs-row">
                  <span class="bs-name">{row.ledger_name}</span>
                  <span class="bs-amt">{formatAmt(row.balance)}</span>
                </div>
              {/each}
            </div>
          {/if}

          <div class="bs-grand">
            <span>Total Liabilities & Equity</span>
            <span>{formatAmt(totalLiabilities + totalEquity + (netProfitLoss > 0 ? netProfitLoss : 0))}</span>
          </div>
        </div>

        <!-- RIGHT: Assets -->
        <div class="bs-side">
          <div class="bs-side-header dr-header">
            <h3>Assets</h3>
          </div>

          <!-- Non-Current Assets (Fixed Assets) -->
          {#if assetRows.some(r => ['Workshop Equipment', 'Furniture & Fixtures', 'Vehicles (Company Owned)', 'Computer & Electronics', 'Goodwill'].includes(r.ledger_name))}
            <div class="bs-section">
              <div class="section-title">I. Non-Current Assets</div>
              {#each assetRows.filter(r => ['Workshop Equipment', 'Furniture & Fixtures', 'Vehicles (Company Owned)', 'Computer & Electronics', 'Goodwill'].includes(r.ledger_name)) as row (row.id)}
                <div class="bs-row">
                  <span class="bs-name">{row.ledger_name}</span>
                  <span class="bs-amt">{formatAmt(row.balance)}</span>
                </div>
              {/each}
            </div>
          {/if}

          <!-- Current Assets -->
          {#if assetRows.some(r => !['Workshop Equipment', 'Furniture & Fixtures', 'Vehicles (Company Owned)', 'Computer & Electronics', 'Goodwill'].includes(r.ledger_name))}
            <div class="bs-section">
              <div class="section-title">II. Current Assets</div>
              {#each assetRows.filter(r => !['Workshop Equipment', 'Furniture & Fixtures', 'Vehicles (Company Owned)', 'Computer & Electronics', 'Goodwill'].includes(r.ledger_name)) as row (row.id)}
                <div class="bs-row">
                  <span class="bs-name">{row.ledger_name}</span>
                  <span class="bs-amt">{formatAmt(row.balance)}</span>
                </div>
              {/each}
            </div>
          {/if}

          <!-- Net Loss shown on asset side -->
          {#if netProfitLoss < 0}
            <div class="bs-section">
              <div class="section-title">III. Profit & Loss (Debit Balance)</div>
              <div class="bs-row loss-row">
                <span class="bs-name">Net Loss</span>
                <span class="bs-amt">{formatAmt(netProfitLoss)}</span>
              </div>
            </div>
          {/if}

          <div class="bs-grand">
            <span>Total Assets</span>
            <span>{formatAmt(totalAssets + (netProfitLoss < 0 ? Math.abs(netProfitLoss) : 0))}</span>
          </div>
        </div>
      </div>

      <!-- Balance Check -->
      <div class="balance-check">
        {#if Math.abs((totalLiabilities + totalEquity + (netProfitLoss > 0 ? netProfitLoss : 0)) - (totalAssets + (netProfitLoss < 0 ? Math.abs(netProfitLoss) : 0))) < 0.01}
          <span class="balanced">✓ Balance Sheet is Balanced (Assets = Liabilities + Equity)</span>
        {:else}
          <span class="unbalanced">✗ Difference: {formatAmt(Math.abs((totalLiabilities + totalEquity + (netProfitLoss > 0 ? netProfitLoss : 0)) - (totalAssets + (netProfitLoss < 0 ? Math.abs(netProfitLoss) : 0))))}</span>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .header-right { display:flex; align-items:center; gap:8px; }
  .header-right label { font-size:12px; font-weight:600; color:#6b7280; }
  .header-right input { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .subtitle { font-size:11px; color:#9ca3af; }

  .bs-body { flex:1; overflow:auto; padding:16px 18px; }
  .bs-layout { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
  .bs-side { background:white; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; }
  .bs-side-header { padding:12px 16px; }
  .bs-side-header h3 { margin:0; font-size:14px; font-weight:700; }
  .cr-header { background:#f0fdf4; color:#16a34a; border-bottom:2px solid #bbf7d0; }
  .dr-header { background:#dbeafe; color:#1d4ed8; border-bottom:2px solid #93c5fd; }

  .bs-section { padding:0 16px; }
  .section-title { font-size:12px; font-weight:700; color:#374151; padding:10px 0 4px; border-bottom:1px solid #f3f4f6; text-transform:uppercase; letter-spacing:0.5px; }
  .bs-row { display:flex; justify-content:space-between; padding:6px 0; font-size:13px; border-bottom:1px solid #f9fafb; }
  .bs-name { color:#374151; }
  .bs-amt { font-family:'Courier New',monospace; color:#111827; font-weight:500; }
  .profit-row { color:#16a34a; }
  .profit-row .bs-name, .profit-row .bs-amt { color:#16a34a; font-weight:600; }
  .loss-row { color:#dc2626; }
  .loss-row .bs-name, .loss-row .bs-amt { color:#dc2626; font-weight:600; }
  .section-sub-total { display:flex; justify-content:space-between; padding:6px 0; font-weight:600; font-size:12px; color:#6b7280; border-top:1px dashed #e5e7eb; }

  .bs-grand { display:flex; justify-content:space-between; padding:12px 16px; font-weight:700; font-size:14px; background:#f9fafb; border-top:3px double #374151; }

  .balance-check { text-align:center; padding:16px; margin-top:16px; }
  .balanced { font-size:14px; font-weight:700; color:#16a34a; background:#dcfce7; padding:8px 20px; border-radius:6px; }
  .unbalanced { font-size:14px; font-weight:700; color:#dc2626; background:#fee2e2; padding:8px 20px; border-radius:6px; }

  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }
</style>
