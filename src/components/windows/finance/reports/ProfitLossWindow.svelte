<!-- ============================================================
     FINANCE > REPORTS > PROFIT & LOSS ACCOUNT
     Purpose: Revenue vs Expenses as per Indian Accounting Standards
     Schedule III format (Ind AS / Companies Act 2013)
     Includes: Revenue, Stock Valuation (Opening/Closing Stock),
               Purchases, Expenses, Depreciation, Net Profit
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface PLRow {
    id: string;
    ledger_name: string;
    type_name: string;
    amount: number;
  }

  // Revenue
  let revenueFromOps: PLRow[] = [];
  let otherIncome: PLRow[] = [];

  // Expenses by category
  let purchaseExpenses: PLRow[] = [];
  let directExpenses: PLRow[] = [];
  let operationalExpenses: PLRow[] = [];
  let depreciationExpenses: PLRow[] = [];

  // Stock valuation
  let openingStockValue = 0;
  let closingStockValue = 0;

  let loading = true;
  let fromDate = '';
  let toDate = '';

  // Computed totals
  $: totalRevenueFromOps = revenueFromOps.reduce((s, r) => s + Math.abs(r.amount), 0);
  $: totalOtherIncome = otherIncome.reduce((s, r) => s + Math.abs(r.amount), 0);
  $: totalIncome = totalRevenueFromOps + totalOtherIncome;

  $: totalPurchases = purchaseExpenses.reduce((s, r) => s + r.amount, 0);
  $: changesInInventory = openingStockValue - closingStockValue;
  $: costOfMaterials = totalPurchases + changesInInventory;
  $: totalDirectExp = directExpenses.reduce((s, r) => s + r.amount, 0);
  $: totalOperationalExp = operationalExpenses.reduce((s, r) => s + r.amount, 0);
  $: totalDepreciation = depreciationExpenses.reduce((s, r) => s + r.amount, 0);
  $: totalExpenses = costOfMaterials + totalDirectExp + totalOperationalExp + totalDepreciation;

  $: grossProfit = totalIncome - costOfMaterials;
  $: netProfitLoss = totalIncome - totalExpenses;

  onMount(() => {
    const now = new Date();
    const fy = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    fromDate = `${fy}-04-01`;
    toDate = `${fy + 1}-03-31`;
    loadPL();
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

  async function loadPL() {
    loading = true;

    // 1. Fetch all ledgers with type info
    const { data: ledgers } = await supabase
      .from('ledger')
      .select('id, ledger_name, opening_balance, ledger_types(name, category)')
      .eq('status', 'active')
      .order('ledger_name');

    // 2. Fetch ledger entries within the period
    let entryQuery = supabase.from('ledger_entries').select('ledger_id, debit, credit');
    if (fromDate) entryQuery = entryQuery.gte('entry_date', fromDate);
    if (toDate) entryQuery = entryQuery.lte('entry_date', toDate);
    const { data: entries } = await entryQuery;

    // 3. Fetch stock valuation (closing stock = current inventory value)
    const { data: products } = await supabase
      .from('products')
      .select('id, current_stock, current_cost, unit_qty')
      .neq('product_type', 'service');

    // 4. Fetch stock movements during the period to compute opening stock
    let movQuery = supabase.from('stock_movements').select('product_id, qty');
    if (fromDate) movQuery = movQuery.gte('created_at', fromDate + 'T00:00:00');
    if (toDate) movQuery = movQuery.lte('created_at', toDate + 'T23:59:59');
    const { data: movements } = await movQuery;

    // Build movement totals per product (net qty change during period)
    const movementMap: Record<string, number> = {};
    for (const m of (movements || [])) {
      movementMap[m.product_id] = (movementMap[m.product_id] || 0) + (m.qty || 0);
    }

    // Calculate stock values (per-piece cost = current_cost / unit_qty)
    let closingVal = 0;
    let openingVal = 0;
    for (const p of (products || []) as any[]) {
      const unitQty = p.unit_qty || 1;
      const perPieceCost = (p.current_cost || 0) / unitQty;
      const currentQty = p.current_stock || 0;
      const periodNetQty = movementMap[p.id] || 0;
      const openingQty = currentQty - periodNetQty;

      closingVal += Math.max(0, currentQty) * perPieceCost;
      openingVal += Math.max(0, openingQty) * perPieceCost;
    }
    closingStockValue = Math.round(closingVal * 100) / 100;
    openingStockValue = Math.round(openingVal * 100) / 100;

    // Group entries by ledger_id
    const entryMap: Record<string, { dr: number; cr: number }> = {};
    for (const e of (entries || [])) {
      if (!entryMap[e.ledger_id]) entryMap[e.ledger_id] = { dr: 0, cr: 0 };
      entryMap[e.ledger_id].dr += e.debit || 0;
      entryMap[e.ledger_id].cr += e.credit || 0;
    }

    // Purchase-related ledger names (matched by name pattern)
    const purchaseNames = ['purchase account', 'spare parts purchase', 'accessories purchase',
      'lubricants & oils expense', 'tyre & tube purchase', 'battery purchase',
      'paint & body material', 'electrical parts purchase', 'engine parts purchase',
      'filter purchase', 'brake parts purchase', 'suspension parts purchase',
      'glass & mirror purchase', 'ac parts purchase', 'fuel system parts purchase'];

    // Depreciation-related
    const depreciationNames = ['depreciation account', 'depreciation'];

    // Classify accounts
    const revOps: PLRow[] = [];
    const otherInc: PLRow[] = [];
    const purchases: PLRow[] = [];
    const directExp: PLRow[] = [];
    const opExp: PLRow[] = [];
    const depExp: PLRow[] = [];

    for (const l of (ledgers || []) as any[]) {
      const category = l.ledger_types?.category;
      const typeName = l.ledger_types?.name || '';
      const txnDr = entryMap[l.id]?.dr || 0;
      const txnCr = entryMap[l.id]?.cr || 0;
      if (txnDr === 0 && txnCr === 0) continue;

      const netAmount = txnDr - txnCr;
      const row: PLRow = {
        id: l.id,
        ledger_name: l.ledger_name,
        type_name: typeName,
        amount: netAmount,
      };

      if (category === 'revenue') {
        if (typeName === 'Revenue') {
          revOps.push(row);
        } else {
          otherInc.push(row);
        }
      } else if (category === 'expense') {
        const nameLower = l.ledger_name.toLowerCase();

        if (depreciationNames.some(d => nameLower.includes(d))) {
          depExp.push(row);
        } else if (purchaseNames.some(p => nameLower === p || nameLower.includes('purchase'))) {
          purchases.push(row);
        } else if (typeName === 'Operational Expense') {
          opExp.push(row);
        } else {
          directExp.push(row);
        }
      }
    }

    revenueFromOps = revOps.sort((a, b) => Math.abs(b.amount) - Math.abs(a.amount));
    otherIncome = otherInc.sort((a, b) => Math.abs(b.amount) - Math.abs(a.amount));
    purchaseExpenses = purchases.sort((a, b) => b.amount - a.amount);
    directExpenses = directExp.sort((a, b) => b.amount - a.amount);
    operationalExpenses = opExp.sort((a, b) => b.amount - a.amount);
    depreciationExpenses = depExp.sort((a, b) => b.amount - a.amount);
    loading = false;
  }

  function applyFilters() {
    loadPL();
  }

  function handleBack() {
    windowStore.close('finance-profit-loss');
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div>
        <h2>Profit & Loss Account</h2>
        <span class="subtitle">For the period {formatDate(fromDate)} to {formatDate(toDate)} (Ind AS Schedule III)</span>
      </div>
    </div>
  </div>

  <div class="filters-bar">
    <div class="filter-group">
      <label for="pl-from">From</label>
      <input id="pl-from" type="date" bind:value={fromDate} on:change={applyFilters} />
    </div>
    <div class="filter-group">
      <label for="pl-to">To</label>
      <input id="pl-to" type="date" bind:value={toDate} on:change={applyFilters} />
    </div>
  </div>

  <div class="pl-body">
    {#if loading}
      <div class="status-msg">Loading Profit & Loss Account...</div>
    {:else}

      <!-- ======== INCOME SECTION ======== -->
      <div class="pl-section-block income-block">
        <div class="block-header income-header">
          <h3>INCOME</h3>
        </div>

        <!-- I. Revenue from Operations -->
        <div class="pl-group">
          <div class="group-title">I. Revenue from Operations</div>
          {#if revenueFromOps.length > 0}
            {#each revenueFromOps as row (row.id)}
              <div class="pl-row">
                <span class="pl-name">{row.ledger_name}</span>
                <span class="pl-amt">{formatAmt(row.amount)}</span>
              </div>
            {/each}
          {:else}
            <div class="pl-row empty">No revenue entries</div>
          {/if}
          <div class="group-sub-total">
            <span>Total Revenue from Operations</span>
            <span>{formatAmt(totalRevenueFromOps)}</span>
          </div>
        </div>

        <!-- II. Other Income -->
        {#if otherIncome.length > 0}
          <div class="pl-group">
            <div class="group-title">II. Other Income</div>
            {#each otherIncome as row (row.id)}
              <div class="pl-row">
                <span class="pl-name">{row.ledger_name}</span>
                <span class="pl-amt">{formatAmt(row.amount)}</span>
              </div>
            {/each}
            <div class="group-sub-total">
              <span>Total Other Income</span>
              <span>{formatAmt(totalOtherIncome)}</span>
            </div>
          </div>
        {/if}

        <div class="section-total income-total">
          <span>III. Total Income (I + II)</span>
          <span>{formatAmt(totalIncome)}</span>
        </div>
      </div>

      <!-- ======== EXPENSES SECTION ======== -->
      <div class="pl-section-block expense-block">
        <div class="block-header expense-header">
          <h3>EXPENSES</h3>
        </div>

        <!-- (a) Cost of Materials Consumed -->
        <div class="pl-group">
          <div class="group-title">(a) Cost of Materials Consumed</div>

          <div class="pl-row stock-row">
            <span class="pl-name">Opening Stock</span>
            <span class="pl-amt">{formatAmt(openingStockValue)}</span>
          </div>

          {#each purchaseExpenses as row (row.id)}
            <div class="pl-row">
              <span class="pl-name indent">Add: {row.ledger_name}</span>
              <span class="pl-amt">{formatAmt(row.amount)}</span>
            </div>
          {/each}

          {#if purchaseExpenses.length === 0}
            <div class="pl-row">
              <span class="pl-name indent">Add: Purchases</span>
              <span class="pl-amt">₹0.00</span>
            </div>
          {/if}

          <div class="pl-row stock-row">
            <span class="pl-name">Less: Closing Stock</span>
            <span class="pl-amt neg">({formatAmt(closingStockValue)})</span>
          </div>

          <div class="group-sub-total">
            <span>Cost of Materials Consumed</span>
            <span>{formatAmt(costOfMaterials)}</span>
          </div>
        </div>

        <!-- (b) Changes in Inventories -->
        <div class="pl-group">
          <div class="group-title">(b) Changes in Inventories of Stock-in-Trade</div>
          <div class="pl-row">
            <span class="pl-name">Opening Stock</span>
            <span class="pl-amt">{formatAmt(openingStockValue)}</span>
          </div>
          <div class="pl-row">
            <span class="pl-name">Less: Closing Stock</span>
            <span class="pl-amt neg">({formatAmt(closingStockValue)})</span>
          </div>
          <div class="group-sub-total">
            <span>{changesInInventory >= 0 ? 'Decrease in Inventory' : 'Increase in Inventory'}</span>
            <span class="{changesInInventory >= 0 ? '' : 'neg'}">{changesInInventory >= 0 ? formatAmt(changesInInventory) : '(' + formatAmt(changesInInventory) + ')'}</span>
          </div>
        </div>

        <!-- (c) Direct Expenses -->
        {#if directExpenses.length > 0}
          <div class="pl-group">
            <div class="group-title">(c) Direct Expenses</div>
            {#each directExpenses as row (row.id)}
              <div class="pl-row">
                <span class="pl-name">{row.ledger_name}</span>
                <span class="pl-amt">{formatAmt(row.amount)}</span>
              </div>
            {/each}
            <div class="group-sub-total">
              <span>Total Direct Expenses</span>
              <span>{formatAmt(totalDirectExp)}</span>
            </div>
          </div>
        {/if}

        <!-- Gross Profit -->
        <div class="gross-profit-bar" class:profit={grossProfit >= 0} class:loss={grossProfit < 0}>
          <span>{grossProfit >= 0 ? 'Gross Profit' : 'Gross Loss'}</span>
          <span>{formatAmt(grossProfit)}</span>
        </div>

        <!-- (d) Depreciation -->
        {#if depreciationExpenses.length > 0}
          <div class="pl-group">
            <div class="group-title">(d) Depreciation & Amortization</div>
            {#each depreciationExpenses as row (row.id)}
              <div class="pl-row">
                <span class="pl-name">{row.ledger_name}</span>
                <span class="pl-amt">{formatAmt(row.amount)}</span>
              </div>
            {/each}
            <div class="group-sub-total">
              <span>Total Depreciation</span>
              <span>{formatAmt(totalDepreciation)}</span>
            </div>
          </div>
        {/if}

        <!-- (e) Operating / Indirect Expenses -->
        {#if operationalExpenses.length > 0}
          <div class="pl-group">
            <div class="group-title">(e) Other Expenses (Operating)</div>
            {#each operationalExpenses as row (row.id)}
              <div class="pl-row">
                <span class="pl-name">{row.ledger_name}</span>
                <span class="pl-amt">{formatAmt(row.amount)}</span>
              </div>
            {/each}
            <div class="group-sub-total">
              <span>Total Operating Expenses</span>
              <span>{formatAmt(totalOperationalExp)}</span>
            </div>
          </div>
        {/if}

        <div class="section-total expense-total">
          <span>IV. Total Expenses</span>
          <span>{formatAmt(totalExpenses)}</span>
        </div>
      </div>

      <!-- ======== NET PROFIT / LOSS ======== -->
      <div class="net-result" class:profit={netProfitLoss >= 0} class:loss={netProfitLoss < 0}>
        <div class="net-label">
          V. {netProfitLoss >= 0 ? 'Profit Before Tax (III - IV)' : 'Loss Before Tax (III - IV)'}
        </div>
        <div class="net-amount">{formatAmt(netProfitLoss)}</div>
      </div>

      <!-- Stock Valuation Note -->
      <div class="stock-note">
        <strong>Stock Valuation:</strong>
        Opening Stock: {formatAmt(openingStockValue)} |
        Closing Stock: {formatAmt(closingStockValue)} |
        Change: {changesInInventory >= 0 ? '+' : ''}{formatAmt(changesInInventory)}
        <span class="note-info">(Valued at cost price as per Ind AS 2)</span>
      </div>
    {/if}
  </div>
</div>

<style>
  .report-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .subtitle { font-size:11px; color:#9ca3af; }

  .filters-bar { display:flex; align-items:flex-end; gap:12px; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .filter-group { display:flex; flex-direction:column; gap:3px; }
  .filter-group label { font-size:11px; font-weight:600; color:#6b7280; }
  .filter-group input { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus { border-color:#f59e0b; }

  .pl-body { flex:1; overflow:auto; padding:16px 18px; }

  .pl-section-block { background:white; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; margin-bottom:16px; }
  .block-header { padding:10px 16px; }
  .block-header h3 { margin:0; font-size:13px; font-weight:700; letter-spacing:1px; }
  .income-header { background:#f0fdf4; color:#16a34a; border-bottom:2px solid #bbf7d0; }
  .expense-header { background:#fef2f2; color:#dc2626; border-bottom:2px solid #fecaca; }

  .pl-group { padding:0 16px 8px; }
  .group-title { font-size:12px; font-weight:700; color:#374151; padding:10px 0 4px; border-bottom:1px solid #f3f4f6; text-transform:uppercase; letter-spacing:0.3px; }
  .pl-row { display:flex; justify-content:space-between; padding:5px 0; font-size:13px; border-bottom:1px solid #f9fafb; }
  .pl-row.empty { color:#9ca3af; font-style:italic; }
  .pl-name { color:#374151; }
  .pl-name.indent { padding-left:16px; }
  .pl-amt { font-family:'Courier New',monospace; color:#111827; font-weight:500; white-space:nowrap; }
  .pl-amt.neg { color:#dc2626; }
  .stock-row { background:#fffbeb; }
  .stock-row .pl-name { font-weight:600; color:#92400e; }
  .stock-row .pl-amt { color:#92400e; font-weight:600; }

  .group-sub-total { display:flex; justify-content:space-between; padding:8px 0; font-weight:600; font-size:12px; color:#374151; border-top:1px dashed #d1d5db; margin-top:4px; }

  .section-total { display:flex; justify-content:space-between; padding:12px 16px; font-weight:700; font-size:14px; border-top:3px double #374151; }
  .income-total { background:#f0fdf4; color:#15803d; }
  .expense-total { background:#fef2f2; color:#b91c1c; }

  .gross-profit-bar { display:flex; justify-content:space-between; padding:10px 16px; font-weight:700; font-size:13px; margin:4px 0; border-radius:4px; }
  .gross-profit-bar.profit { background:#dcfce7; color:#16a34a; border:1px solid #bbf7d0; }
  .gross-profit-bar.loss { background:#fee2e2; color:#dc2626; border:1px solid #fecaca; }

  .net-result { text-align:center; padding:20px; border-radius:8px; margin-top:4px; }
  .net-result.profit { background:#dcfce7; border:2px solid #bbf7d0; }
  .net-result.loss { background:#fee2e2; border:2px solid #fecaca; }
  .net-label { font-size:15px; font-weight:700; margin-bottom:6px; }
  .net-result.profit .net-label { color:#16a34a; }
  .net-result.loss .net-label { color:#dc2626; }
  .net-amount { font-size:26px; font-weight:700; font-family:'Courier New',monospace; }
  .net-result.profit .net-amount { color:#15803d; }
  .net-result.loss .net-amount { color:#b91c1c; }

  .stock-note { margin-top:16px; padding:10px 16px; background:#fffbeb; border:1px solid #fde68a; border-radius:6px; font-size:12px; color:#92400e; }
  .note-info { font-style:italic; color:#a16207; }

  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }
</style>
