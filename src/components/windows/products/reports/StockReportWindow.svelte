<!-- ============================================================
     PRODUCTS > REPORTS > STOCK REPORT
     Purpose: Show current stock with valuation based on
              Last Cost (current_cost) or Average Purchase Cost
     Window ID: products-stock-report
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface StockRow {
    id: string;
    product_name: string;
    product_type: string;
    current_stock: number;
    current_cost: number;
    sales_price: number;
    avg_cost: number;
    last_cost_value: number;
    avg_cost_value: number;
    brand_name: string;
    unit_name: string;
  }

  let rows: StockRow[] = [];
  let loading = true;
  let searchQuery = '';
  let valuationMethod: 'last' | 'average' = 'last';

  $: filteredRows = searchQuery
    ? rows.filter(r =>
        r.product_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.brand_name.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : rows;

  $: totalStockValue = filteredRows.reduce((s, r) =>
    s + (valuationMethod === 'last' ? r.last_cost_value : r.avg_cost_value), 0);

  $: totalSalesValue = filteredRows.reduce((s, r) =>
    s + r.current_stock * r.sales_price, 0);

  $: totalQty = filteredRows.reduce((s, r) => s + r.current_stock, 0);

  onMount(() => { loadStock(); });

  function formatAmt(val: number): string {
    if (val === 0) return '₹0.00';
    const sign = val < 0 ? '-' : '';
    return sign + '₹' + Math.abs(val).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  async function loadStock() {
    loading = true;

    const { data: products } = await supabase
      .from('products')
      .select('id, product_name, product_type, current_stock, current_cost, sales_price, unit_qty, brands(name), units(name)')
      .neq('product_type', 'service')
      .order('product_name');

    // Get average cost from purchase_items
    const { data: purchaseItems } = await supabase
      .from('purchase_items')
      .select('product_id, qty, rate');

    const costAgg: Record<string, { totalVal: number; totalQty: number }> = {};
    for (const pi of (purchaseItems || [])) {
      if (!pi.product_id) continue;
      if (!costAgg[pi.product_id]) costAgg[pi.product_id] = { totalVal: 0, totalQty: 0 };
      costAgg[pi.product_id].totalVal += (pi.rate || 0) * (pi.qty || 0);
      costAgg[pi.product_id].totalQty += (pi.qty || 0);
    }

    const result: StockRow[] = [];
    for (const p of (products || []) as any[]) {
      const stock = p.current_stock || 0;
      const unitQty = p.unit_qty || 1;
      const lastCost = (p.current_cost || 0) / unitQty;
      const salesPrice = (p.sales_price || 0) / unitQty;
      const agg = costAgg[p.id];
      const avgCost = agg && agg.totalQty > 0
        ? Math.round((agg.totalVal / agg.totalQty / unitQty) * 100) / 100
        : lastCost;

      result.push({
        id: p.id,
        product_name: p.product_name,
        product_type: p.product_type,
        current_stock: stock,
        current_cost: lastCost,
        sales_price: salesPrice,
        avg_cost: avgCost,
        last_cost_value: stock * lastCost,
        avg_cost_value: stock * avgCost,
        brand_name: p.brands?.name || '—',
        unit_name: p.units?.name || '—',
      });
    }

    rows = result;
    loading = false;
  }

  function handleBack() {
    windowStore.close('products-stock-report');
  }
</script>

<div class="report-window">
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <div>
        <h2>Stock Report</h2>
        <span class="subtitle">Current stock with valuation</span>
      </div>
    </div>
  </div>

  <div class="filters-bar">
    <div class="filter-group">
      <label for="sr-search">Search</label>
      <input id="sr-search" type="text" bind:value={searchQuery} placeholder="Product or brand..." />
    </div>
    <div class="filter-group">
      <label for="sr-valuation">Valuation Method</label>
      <select id="sr-valuation" bind:value={valuationMethod}>
        <option value="last">Last Cost (Current Cost)</option>
        <option value="average">Average Purchase Cost</option>
      </select>
    </div>
    <button class="btn-refresh" on:click={loadStock}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
      Refresh
    </button>
  </div>

  <!-- Summary Cards -->
  <div class="summary-bar">
    <div class="summary-card">
      <span class="card-label">Total Items</span>
      <span class="card-value">{filteredRows.length}</span>
    </div>
    <div class="summary-card">
      <span class="card-label">Total Qty</span>
      <span class="card-value">{totalQty.toLocaleString('en-IN')}</span>
    </div>
    <div class="summary-card stock-val">
      <span class="card-label">Stock Value ({valuationMethod === 'last' ? 'Last Cost' : 'Avg Cost'})</span>
      <span class="card-value">{formatAmt(totalStockValue)}</span>
    </div>
    <div class="summary-card sales-val">
      <span class="card-label">Stock Value (Sales Price)</span>
      <span class="card-value">{formatAmt(totalSalesValue)}</span>
    </div>
  </div>

  <div class="table-container">
    {#if loading}
      <div class="status-msg">Loading stock data...</div>
    {:else if filteredRows.length === 0}
      <div class="status-msg">{searchQuery ? 'No products match your search' : 'No products found'}</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Product Name</th>
            <th>Type</th>
            <th>Brand</th>
            <th>Unit</th>
            <th class="r">Stock Qty</th>
            <th class="r">Last Cost</th>
            <th class="r">Avg Cost</th>
            <th class="r">Sales Price</th>
            <th class="r">Stock Value</th>
            <th class="r">Sales Value</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredRows as row, i (row.id)}
            <tr class:zero-stock={row.current_stock <= 0}>
              <td class="num">{i + 1}</td>
              <td class="name">{row.product_name}</td>
              <td><span class="type-badge {row.product_type}">{row.product_type.charAt(0).toUpperCase() + row.product_type.slice(1)}</span></td>
              <td>{row.brand_name}</td>
              <td>{row.unit_name}</td>
              <td class="r" class:low={row.current_stock < 0}>{row.current_stock}</td>
              <td class="r">{formatAmt(row.current_cost)}</td>
              <td class="r">{formatAmt(row.avg_cost)}</td>
              <td class="r">{formatAmt(row.sales_price)}</td>
              <td class="r val">{formatAmt(valuationMethod === 'last' ? row.last_cost_value : row.avg_cost_value)}</td>
              <td class="r">{formatAmt(row.current_stock * row.sales_price)}</td>
            </tr>
          {/each}
        </tbody>
        <tfoot>
          <tr>
            <td colspan="5" class="foot-label">TOTAL</td>
            <td class="r foot-val">{totalQty.toLocaleString('en-IN')}</td>
            <td></td>
            <td></td>
            <td></td>
            <td class="r foot-val">{formatAmt(totalStockValue)}</td>
            <td class="r foot-val">{formatAmt(totalSalesValue)}</td>
          </tr>
        </tfoot>
      </table>
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
  .filter-group input, .filter-group select { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus, .filter-group select:focus { border-color:#f59e0b; }
  .btn-refresh { display:flex; align-items:center; gap:5px; padding:7px 14px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; font-size:12px; font-weight:600; color:#374151; cursor:pointer; transition:all .15s; }
  .btn-refresh:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }

  .summary-bar { display:flex; gap:12px; padding:12px 18px; background:#f9fafb; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; }
  .summary-card { background:white; border:1px solid #e5e7eb; border-radius:8px; padding:10px 16px; display:flex; flex-direction:column; gap:2px; min-width:140px; }
  .card-label { font-size:11px; font-weight:600; color:#6b7280; text-transform:uppercase; letter-spacing:0.3px; }
  .card-value { font-size:16px; font-weight:700; color:#111827; font-family:'Courier New',monospace; }
  .stock-val { border-left:3px solid #f59e0b; }
  .stock-val .card-value { color:#d97706; }
  .sales-val { border-left:3px solid #3b82f6; }
  .sales-val .card-value { color:#1d4ed8; }

  .table-container { flex:1; overflow:auto; }
  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }

  table { width:100%; border-collapse:collapse; font-size:13px; }
  thead { position:sticky; top:0; z-index:2; }
  th { background:#f9fafb; padding:10px 10px; text-align:left; font-weight:600; color:#6b7280; font-size:11px; text-transform:uppercase; letter-spacing:0.03em; border-bottom:1px solid #e5e7eb; white-space:nowrap; }
  th.r { text-align:right; }
  td { padding:9px 10px; color:#374151; border-bottom:1px solid #f3f4f6; white-space:nowrap; }
  td.r { text-align:right; font-family:'Courier New',monospace; }
  td.val { font-weight:600; color:#d97706; }
  tr:hover td { background:#fffbf5; }
  .num { color:#9ca3af; width:36px; }
  .name { font-weight:600; color:#111827; }
  .zero-stock td { opacity:0.5; }
  .low { color:#dc2626; font-weight:700; }

  .type-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.03em; }
  .type-badge.product { background:#dbeafe; color:#1d4ed8; }
  .type-badge.service { background:#f3e8ff; color:#7c3aed; }
  .type-badge.consumable { background:#dcfce7; color:#16a34a; }

  tfoot td { background:#f9fafb; border-top:2px solid #e5e7eb; padding:10px; }
  .foot-label { font-weight:700; color:#374151; text-transform:uppercase; font-size:12px; }
  .foot-val { font-weight:700; color:#111827; font-family:'Courier New',monospace; font-size:14px; }
</style>
