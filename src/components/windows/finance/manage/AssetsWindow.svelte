<!-- ============================================================
     FINANCE > MANAGE > ASSETS WINDOW
     Purpose: List, view, filter and manage fixed assets
     Includes: depreciation status, WDV, disposal actions
     Window ID: finance-assets
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface Asset {
    id: string;
    asset_code: string;
    asset_name: string;
    category_name: string;
    purchase_date: string;
    total_cost: number;
    depreciation_method: string;
    depreciation_rate: number;
    accumulated_depreciation: number;
    written_down_value: number;
    useful_life_years: number;
    status: string;
    location: string;
    vendor_name: string;
    invoice_no: string;
  }

  let assets: Asset[] = [];
  let filteredAssets: Asset[] = [];
  let loading = true;
  let search = '';
  let statusFilter = 'all';
  let categoryFilter = 'all';
  let categories: { id: string; name: string }[] = [];

  // Depreciation run state
  let showDepreciationModal = false;
  let depFY = '';
  let depRunning = false;
  let depResult = '';

  onMount(() => {
    const now = new Date();
    const fy = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    depFY = `${fy}-${fy + 1}`;
    loadCategories();
    loadAssets();
  });

  async function loadCategories() {
    const { data } = await supabase.from('asset_categories').select('id, name').order('sort_order');
    categories = data || [];
  }

  async function loadAssets() {
    loading = true;
    const { data } = await supabase
      .from('assets')
      .select('id, asset_code, asset_name, purchase_date, total_cost, depreciation_method, depreciation_rate, accumulated_depreciation, written_down_value, useful_life_years, status, location, invoice_no, asset_category_id, vendor_id, asset_categories(name), vendors(name)')
      .order('created_at', { ascending: false });

    assets = (data || []).map((a: any) => ({
      id: a.id,
      asset_code: a.asset_code,
      asset_name: a.asset_name,
      category_name: a.asset_categories?.name || '-',
      purchase_date: a.purchase_date,
      total_cost: a.total_cost || 0,
      depreciation_method: a.depreciation_method || 'SLM',
      depreciation_rate: a.depreciation_rate || 0,
      accumulated_depreciation: a.accumulated_depreciation || 0,
      written_down_value: a.written_down_value || 0,
      useful_life_years: a.useful_life_years || 0,
      status: a.status || 'active',
      location: a.location || '',
      vendor_name: a.vendors?.name || '-',
      invoice_no: a.invoice_no || '-',
    }));
    applyFilters();
    loading = false;
  }

  function applyFilters() {
    let list = assets;
    if (statusFilter !== 'all') list = list.filter(a => a.status === statusFilter);
    if (categoryFilter !== 'all') list = list.filter(a => a.category_name === categoryFilter);
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      list = list.filter(a =>
        a.asset_name.toLowerCase().includes(q) ||
        a.asset_code.toLowerCase().includes(q) ||
        a.vendor_name.toLowerCase().includes(q) ||
        a.location.toLowerCase().includes(q)
      );
    }
    filteredAssets = list;
  }

  $: search, statusFilter, categoryFilter, applyFilters();

  function formatAmt(val: number): string {
    return '₹' + val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function formatDate(dt: string): string {
    if (!dt) return '-';
    const d = new Date(dt + 'T00:00:00');
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  }

  function statusBadge(s: string): string {
    switch (s) {
      case 'active': return 'badge-active';
      case 'disposed': return 'badge-disposed';
      case 'written_off': return 'badge-written-off';
      case 'under_maintenance': return 'badge-maintenance';
      default: return '';
    }
  }

  function statusLabel(s: string): string {
    switch (s) {
      case 'active': return 'Active';
      case 'disposed': return 'Disposed';
      case 'written_off': return 'Written Off';
      case 'under_maintenance': return 'Under Maintenance';
      default: return s;
    }
  }

  function openCreateAsset() {
    windowStore.open('finance-create-asset', 'Add Asset');
  }

  function handleBack() {
    windowStore.close('finance-assets');
  }

  // ---- Run Depreciation for FY ----
  async function runDepreciation() {
    depRunning = true;
    depResult = '';

    // Parse FY
    const parts = depFY.split('-');
    if (parts.length !== 2) { depResult = 'Invalid FY format. Use YYYY-YYYY'; depRunning = false; return; }
    const fyStart = `${parts[0]}-04-01`;
    const fyEnd = `${parseInt(parts[1])}-03-31`;

    // Get active assets purchased on or before FY end
    const activeAssets = assets.filter(a => a.status === 'active' && a.purchase_date <= fyEnd);
    if (activeAssets.length === 0) { depResult = 'No active assets found for this FY.'; depRunning = false; return; }

    // Fetch depreciation & accumulated depreciation ledger IDs
    const { data: depLedger } = await supabase.from('ledger').select('id').eq('ledger_name', 'Depreciation Account').maybeSingle();
    const { data: accDepLedger } = await supabase.from('ledger').select('id').eq('ledger_name', 'Accumulated Depreciation').maybeSingle();
    if (!depLedger || !accDepLedger) { depResult = 'Depreciation / Accumulated Depreciation ledger not found. Run migration 015 first.'; depRunning = false; return; }

    let successCount = 0;
    let skipCount = 0;

    for (const asset of activeAssets) {
      // Check if already calculated for this FY
      const { data: existing } = await supabase.from('asset_depreciation').select('id').eq('asset_id', asset.id).eq('financial_year', depFY);
      if (existing && existing.length > 0) { skipCount++; continue; }

      // Calculate days used in this FY
      const assetStart = asset.purchase_date > fyStart ? asset.purchase_date : fyStart;
      const startDate = new Date(assetStart + 'T00:00:00');
      const endDate = new Date(fyEnd + 'T00:00:00');
      const daysInFY = Math.round((endDate.getTime() - new Date(fyStart + 'T00:00:00').getTime()) / 86400000) + 1;
      const daysUsed = Math.max(0, Math.round((endDate.getTime() - startDate.getTime()) / 86400000) + 1);

      const openingWDV = asset.written_down_value > 0 ? asset.written_down_value : asset.total_cost;
      let depAmount = 0;

      if (asset.depreciation_method === 'SLM') {
        // SLM: (Cost - Residual) / Useful Life × (days / total days in FY)
        const annualDep = (asset.total_cost * asset.depreciation_rate) / 100;
        depAmount = (annualDep * daysUsed) / daysInFY;
      } else {
        // WDV: Rate × WDV × (days / total days)
        depAmount = (openingWDV * asset.depreciation_rate / 100) * (daysUsed / daysInFY);
      }

      depAmount = Math.round(depAmount * 100) / 100;
      if (depAmount <= 0) { skipCount++; continue; }

      const closingWDV = Math.max(0, openingWDV - depAmount);

      // Insert depreciation record
      const { error: depErr } = await supabase.from('asset_depreciation').insert({
        asset_id: asset.id,
        financial_year: depFY,
        period_from: assetStart,
        period_to: fyEnd,
        opening_wdv: openingWDV,
        depreciation_amount: depAmount,
        closing_wdv: closingWDV,
        method: asset.depreciation_method,
        rate: asset.depreciation_rate,
        days_used: daysUsed,
        posted: true,
      });

      if (!depErr) {
        // Update asset record
        await supabase.from('assets').update({
          accumulated_depreciation: asset.accumulated_depreciation + depAmount,
          written_down_value: closingWDV,
        }).eq('id', asset.id);

        // Post ledger entries (Dr Depreciation, Cr Accumulated Depreciation)
        await supabase.from('ledger_entries').insert([
          {
            entry_date: fyEnd,
            ledger_id: depLedger.id,
            debit: depAmount,
            credit: 0,
            narration: `Depreciation - ${asset.asset_name} (${asset.asset_code}) FY ${depFY}`,
            reference_type: 'asset_depreciation',
            reference_id: asset.id,
          },
          {
            entry_date: fyEnd,
            ledger_id: accDepLedger.id,
            debit: 0,
            credit: depAmount,
            narration: `Accumulated Depreciation - ${asset.asset_name} (${asset.asset_code}) FY ${depFY}`,
            reference_type: 'asset_depreciation',
            reference_id: asset.id,
          },
        ]);

        successCount++;
      }
    }

    depResult = `Depreciation run complete. ${successCount} assets processed, ${skipCount} skipped (already done or zero dep).`;
    depRunning = false;
    await loadAssets();
  }

  // Totals
  $: totalCost = filteredAssets.reduce((s, a) => s + a.total_cost, 0);
  $: totalAccDep = filteredAssets.reduce((s, a) => s + a.accumulated_depreciation, 0);
  $: totalWDV = filteredAssets.reduce((s, a) => s + a.written_down_value, 0);
</script>

<div class="list-window">
  <div class="list-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Fixed Assets Register</h2>
    </div>
    <div class="header-right">
      <button class="dep-btn" on:click={() => showDepreciationModal = true} title="Run Depreciation">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>
        Run Depreciation
      </button>
      <button class="add-btn" on:click={openCreateAsset}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Add Asset
      </button>
    </div>
  </div>

  <!-- Filters -->
  <div class="filter-bar">
    <input type="text" placeholder="Search asset name, code, vendor, location..." bind:value={search} class="search-input" />
    <select bind:value={statusFilter}>
      <option value="all">All Status</option>
      <option value="active">Active</option>
      <option value="disposed">Disposed</option>
      <option value="written_off">Written Off</option>
      <option value="under_maintenance">Under Maintenance</option>
    </select>
    <select bind:value={categoryFilter}>
      <option value="all">All Categories</option>
      {#each categories as cat (cat.id)}
        <option value={cat.name}>{cat.name}</option>
      {/each}
    </select>
  </div>

  <!-- Summary Cards -->
  <div class="summary-cards">
    <div class="s-card"><span class="s-label">Total Assets</span><span class="s-value">{filteredAssets.length}</span></div>
    <div class="s-card"><span class="s-label">Total Cost</span><span class="s-value amt">{formatAmt(totalCost)}</span></div>
    <div class="s-card"><span class="s-label">Accumulated Dep.</span><span class="s-value amt dep">{formatAmt(totalAccDep)}</span></div>
    <div class="s-card"><span class="s-label">Net Book Value (WDV)</span><span class="s-value amt wdv">{formatAmt(totalWDV)}</span></div>
  </div>

  <div class="list-body">
    {#if loading}
      <div class="status-msg">Loading assets...</div>
    {:else if filteredAssets.length === 0}
      <div class="status-msg">No assets found. Click "Add Asset" to register a new fixed asset.</div>
    {:else}
      <table class="data-table">
        <thead>
          <tr>
            <th>Code</th>
            <th>Asset Name</th>
            <th>Category</th>
            <th>Purchase Date</th>
            <th>Total Cost</th>
            <th>Method</th>
            <th>Rate %</th>
            <th>Acc. Dep.</th>
            <th>WDV</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredAssets as a (a.id)}
            <tr>
              <td class="code-col">{a.asset_code}</td>
              <td>
                <div class="asset-name">{a.asset_name}</div>
                {#if a.location}<div class="asset-sub">{a.location}</div>{/if}
              </td>
              <td><span class="cat-badge">{a.category_name}</span></td>
              <td>{formatDate(a.purchase_date)}</td>
              <td class="amt-col">{formatAmt(a.total_cost)}</td>
              <td class="center">{a.depreciation_method}</td>
              <td class="center">{a.depreciation_rate}%</td>
              <td class="amt-col dep-col">{formatAmt(a.accumulated_depreciation)}</td>
              <td class="amt-col wdv-col">{formatAmt(a.written_down_value)}</td>
              <td><span class="status-badge {statusBadge(a.status)}">{statusLabel(a.status)}</span></td>
            </tr>
          {/each}
        </tbody>
        <tfoot>
          <tr class="totals-row">
            <td colspan="4"><strong>Totals ({filteredAssets.length} assets)</strong></td>
            <td class="amt-col"><strong>{formatAmt(totalCost)}</strong></td>
            <td></td>
            <td></td>
            <td class="amt-col dep-col"><strong>{formatAmt(totalAccDep)}</strong></td>
            <td class="amt-col wdv-col"><strong>{formatAmt(totalWDV)}</strong></td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    {/if}
  </div>
</div>

<!-- Depreciation Modal -->
{#if showDepreciationModal}
  <!-- svelte-ignore a11y_no_static_element_interactions a11y_click_events_have_key_events -->
  <div class="modal-overlay" on:click|self={() => { showDepreciationModal = false; depResult = ''; }}>
    <div class="modal-box">
      <h3>Run Depreciation</h3>
      <p class="modal-desc">Calculate and post depreciation for all active assets for the selected financial year (Indian FY: April - March).</p>
      <div class="modal-field">
        <label for="dep-fy">Financial Year</label>
        <input id="dep-fy" type="text" bind:value={depFY} placeholder="YYYY-YYYY e.g. 2025-2026" />
      </div>
      {#if depResult}
        <div class="dep-result">{depResult}</div>
      {/if}
      <div class="modal-actions">
        <button class="btn-cancel" on:click={() => { showDepreciationModal = false; depResult = ''; }}>Close</button>
        <button class="btn-run" on:click={runDepreciation} disabled={depRunning}>
          {depRunning ? 'Running...' : 'Calculate & Post'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .list-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }
  .list-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .header-right { display:flex; align-items:center; gap:8px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }

  .add-btn { display:flex; align-items:center; gap:6px; padding:8px 14px; background:#2563eb; color:white; border:none; border-radius:6px; font-size:13px; font-weight:600; cursor:pointer; transition:all .15s; }
  .add-btn:hover { background:#1d4ed8; }
  .dep-btn { display:flex; align-items:center; gap:6px; padding:8px 14px; background:#f59e0b; color:white; border:none; border-radius:6px; font-size:13px; font-weight:600; cursor:pointer; transition:all .15s; }
  .dep-btn:hover { background:#d97706; }

  .filter-bar { display:flex; gap:8px; padding:10px 18px; background:white; border-bottom:1px solid #f3f4f6; }
  .search-input { flex:1; padding:7px 12px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; }
  .filter-bar select { padding:7px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; }

  .summary-cards { display:flex; gap:12px; padding:12px 18px; }
  .s-card { flex:1; background:white; border:1px solid #e5e7eb; border-radius:8px; padding:12px 16px; text-align:center; }
  .s-label { display:block; font-size:11px; color:#9ca3af; font-weight:600; text-transform:uppercase; letter-spacing:0.5px; }
  .s-value { display:block; font-size:18px; font-weight:700; color:#111827; margin-top:2px; }
  .s-value.dep { color:#dc2626; }
  .s-value.wdv { color:#16a34a; }

  .list-body { flex:1; overflow:auto; padding:0 18px 18px; }
  .data-table { width:100%; border-collapse:collapse; background:white; border:1px solid #e5e7eb; border-radius:8px; overflow:hidden; font-size:13px; }
  .data-table thead th { background:#f9fafb; padding:10px 12px; text-align:left; font-weight:600; color:#374151; border-bottom:2px solid #e5e7eb; font-size:12px; white-space:nowrap; }
  .data-table tbody td { padding:10px 12px; border-bottom:1px solid #f3f4f6; vertical-align:top; }
  .data-table tbody tr:hover { background:#f0f9ff; }
  .code-col { font-family:'Courier New',monospace; font-weight:600; color:#2563eb; font-size:12px; }
  .asset-name { font-weight:600; color:#111827; }
  .asset-sub { font-size:11px; color:#9ca3af; }
  .amt-col { text-align:right; font-family:'Courier New',monospace; white-space:nowrap; }
  .dep-col { color:#dc2626; }
  .wdv-col { color:#16a34a; }
  .center { text-align:center; }

  .cat-badge { background:#dbeafe; color:#1d4ed8; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:600; white-space:nowrap; }
  .status-badge { padding:2px 8px; border-radius:4px; font-size:11px; font-weight:600; white-space:nowrap; }
  .badge-active { background:#dcfce7; color:#16a34a; }
  .badge-disposed { background:#fee2e2; color:#dc2626; }
  .badge-written-off { background:#fef3c7; color:#d97706; }
  .badge-maintenance { background:#e0e7ff; color:#4f46e5; }

  .totals-row { background:#f9fafb; border-top:2px solid #e5e7eb; }
  .totals-row td { padding:10px 12px; }

  .status-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }

  /* Modal */
  .modal-overlay { position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,.4); display:flex; align-items:center; justify-content:center; z-index:1000; }
  .modal-box { background:white; border-radius:12px; padding:24px; width:420px; max-width:90vw; box-shadow:0 10px 40px rgba(0,0,0,.2); }
  .modal-box h3 { margin:0 0 8px; font-size:16px; font-weight:700; color:#111827; }
  .modal-desc { font-size:13px; color:#6b7280; margin:0 0 16px; }
  .modal-field { margin-bottom:16px; }
  .modal-field label { display:block; font-size:12px; font-weight:600; color:#374151; margin-bottom:4px; }
  .modal-field input { width:100%; padding:8px 12px; border:1px solid #d1d5db; border-radius:6px; font-size:14px; box-sizing:border-box; }
  .dep-result { padding:10px; margin-bottom:12px; background:#f0f9ff; border:1px solid #93c5fd; border-radius:6px; font-size:13px; color:#1d4ed8; }
  .modal-actions { display:flex; gap:8px; justify-content:flex-end; }
  .btn-cancel { padding:8px 16px; background:#f3f4f6; border:1px solid #d1d5db; border-radius:6px; cursor:pointer; font-size:13px; }
  .btn-run { padding:8px 20px; background:#f59e0b; color:white; border:none; border-radius:6px; cursor:pointer; font-size:13px; font-weight:600; }
  .btn-run:hover { background:#d97706; }
  .btn-run:disabled { opacity:.5; cursor:not-allowed; }
</style>
