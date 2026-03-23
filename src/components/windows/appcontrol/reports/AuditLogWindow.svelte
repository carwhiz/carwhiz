<!-- ============================================================
     APP CONTROL > REPORTS > AUDIT LOG WINDOW
     Purpose: View all audit log entries in a filterable table
     Window ID: appcontrol-audit-log
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  let logs: any[] = [];
  let loading = true;

  // Filters
  let tableFilter = '';
  let actionFilter = '';
  let fromDate = '';
  let toDate = '';
  let userSearch = '';

  // Pagination
  let page = 0;
  let pageSize = 50;
  let hasMore = true;

  // Distinct table names for filter dropdown
  let tableNames: string[] = [];

  $: filteredLogs = applyFilters(logs, tableFilter, actionFilter, userSearch);

  onMount(() => {
    loadLogs();
    loadTableNames();
  });

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

  async function loadTableNames() {
    const { data } = await supabase
      .from('audit_log')
      .select('table_name')
      .order('table_name');
    if (data) {
      const unique = [...new Set(data.map((r: any) => r.table_name))];
      tableNames = unique.sort();
    }
  }

  async function loadLogs() {
    loading = true;
    let query = supabase
      .from('audit_log')
      .select('id, table_name, record_id, action, old_data, new_data, changed_by, changed_at, users:changed_by(email)')
      .order('changed_at', { ascending: false })
      .range(page * pageSize, (page + 1) * pageSize - 1);

    if (fromDate) query = query.gte('changed_at', fromDate + 'T00:00:00');
    if (toDate) query = query.lte('changed_at', toDate + 'T23:59:59');
    if (tableFilter) query = query.eq('table_name', tableFilter);
    if (actionFilter) query = query.eq('action', actionFilter);

    const { data } = await query;
    logs = (data || []).map((l: any) => ({
      ...l,
      user_email: l.users?.email || '—',
    }));
    hasMore = (data || []).length === pageSize;
    loading = false;
  }

  function applyFilters(list: any[], table: string, action: string, search: string) {
    let result = list;
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      result = result.filter(r => r.user_email.toLowerCase().includes(q));
    }
    return result;
  }

  function clearFilters() {
    tableFilter = '';
    actionFilter = '';
    fromDate = '';
    toDate = '';
    userSearch = '';
    page = 0;
    loadLogs();
  }

  function applyServerFilters() {
    page = 0;
    loadLogs();
  }

  function prevPage() {
    if (page > 0) { page--; loadLogs(); }
  }

  function nextPage() {
    if (hasMore) { page++; loadLogs(); }
  }

  // Expand/collapse detail
  let expandedId: string | null = null;
  function toggleDetail(id: string) {
    expandedId = expandedId === id ? null : id;
  }

  function formatJson(obj: any): string {
    if (!obj) return '—';
    try {
      return JSON.stringify(obj, null, 2);
    } catch {
      return String(obj);
    }
  }

  // Fields to hide from detail view (internal/UUID fields)
  const hiddenFields = new Set(['id', 'created_by', 'updated_by', 'changed_by', 'created_at', 'updated_at', 'changed_at']);
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  // Friendly field labels
  function friendlyLabel(field: string): string {
    return field
      .replace(/_id$/, '')
      .replace(/_/g, ' ')
      .replace(/\b\w/g, c => c.toUpperCase());
  }

  // Friendly value display — hide UUIDs, format dates/booleans
  function friendlyValue(val: any, field: string): string {
    if (val === null || val === undefined) return '—';
    if (typeof val === 'boolean') return val ? 'Yes' : 'No';
    if (typeof val === 'string' && uuidPattern.test(val)) return '(ref)';
    if (typeof val === 'number') return val.toLocaleString('en-IN');
    if (typeof val === 'object') return JSON.stringify(val);
    // Date-like strings
    if (typeof val === 'string' && /^\d{4}-\d{2}-\d{2}/.test(val)) {
      try {
        const d = new Date(val);
        return `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}/${d.getFullYear()}`;
      } catch { return val; }
    }
    return String(val);
  }

  // Get display-worthy fields from a data object
  function getDisplayFields(data: any): Array<{ label: string; value: string; field: string }> {
    if (!data) return [];
    return Object.entries(data)
      .filter(([key]) => !hiddenFields.has(key) && !key.endsWith('_id'))
      .map(([key, val]) => ({
        field: key,
        label: friendlyLabel(key),
        value: friendlyValue(val, key),
      }));
  }

  // Get the record name from data for summary description
  function getRecordName(data: any): string {
    if (!data) return '';
    return data.product_name || data.ledger_name || data.asset_name || data.name
      || data.customer_name || data.vendor_name || data.model_name || data.email
      || data.invoice_no || data.bill_no || data.asset_code || '';
  }

  // Friendly table name
  function friendlyTableName(t: string): string {
    const map: Record<string, string> = {
      products: 'Product', ledger: 'Ledger', ledger_entries: 'Ledger Entry',
      customers: 'Customer', vendors: 'Vendor', vehicles: 'Vehicle',
      purchases: 'Purchase', purchase_items: 'Purchase Item',
      sales: 'Sale', sale_items: 'Sale Item',
      assets: 'Asset', asset_categories: 'Asset Category',
      asset_depreciation: 'Depreciation', stock_movements: 'Stock Movement',
      payment_modes: 'Payment Mode', units: 'Unit', brands: 'Brand',
      users: 'User', audit_log: 'Audit Log',
      permissions: 'Permission',
      product_components: 'Service Component',
      attendance: 'Attendance',
      job_cards: 'Job Card',
      job_card_items: 'Job Card Item',
      job_card_photos: 'Job Card Photo',
      job_card_notes: 'Job Card Note',
      job_card_logs: 'Job Card Log',
    };
    return map[t] || friendlyLabel(t);
  }

  // Build human-readable description
  function getDescription(row: any): string {
    const table = friendlyTableName(row.table_name);
    const data = row.new_data || row.old_data;
    const name = getRecordName(data);
    const nameStr = name ? ` "${name}"` : '';

    if (row.action === 'INSERT') return `Created ${table}${nameStr}`;
    if (row.action === 'DELETE') return `Deleted ${table}${nameStr}`;
    if (row.action === 'UPDATE') {
      const changed = getChangedFields(row.old_data, row.new_data);
      const fieldNames = changed.filter(f => !hiddenFields.has(f) && !f.endsWith('_id')).map(friendlyLabel);
      if (fieldNames.length > 0) {
        return `Updated ${table}${nameStr} — ${fieldNames.join(', ')}`;
      }
      return `Updated ${table}${nameStr}`;
    }
    return `${row.action} on ${table}`;
  }

  function getChangedFields(oldData: any, newData: any): string[] {
    if (!oldData || !newData) return [];
    const changed: string[] = [];
    for (const key of Object.keys(newData)) {
      if (JSON.stringify(oldData[key]) !== JSON.stringify(newData[key])) {
        changed.push(key);
      }
    }
    return changed;
  }

  function handleBack() {
    windowStore.close('appcontrol-audit-log');
  }
</script>

<div class="audit-window">
  <!-- Header -->
  <div class="report-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleBack}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
      </button>
      <h2>Audit Logs</h2>
    </div>
    <button class="btn-refresh" on:click={() => { page = 0; loadLogs(); }}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
      Refresh
    </button>
  </div>

  <!-- Filters -->
  <div class="filters-bar">
    <div class="filter-group">
      <label>Table</label>
      <select bind:value={tableFilter} on:change={applyServerFilters}>
        <option value="">All Tables</option>
        {#each tableNames as tn}
          <option value={tn}>{tn}</option>
        {/each}
      </select>
    </div>
    <div class="filter-group">
      <label>Action</label>
      <select bind:value={actionFilter} on:change={applyServerFilters}>
        <option value="">All</option>
        <option value="INSERT">INSERT</option>
        <option value="UPDATE">UPDATE</option>
        <option value="DELETE">DELETE</option>
      </select>
    </div>
    <div class="filter-group">
      <label>From</label>
      <input type="date" bind:value={fromDate} on:change={applyServerFilters} />
    </div>
    <div class="filter-group">
      <label>To</label>
      <input type="date" bind:value={toDate} on:change={applyServerFilters} />
    </div>
    <div class="filter-group search-group">
      <label>User</label>
      <input type="text" placeholder="Search by email..." bind:value={userSearch} />
    </div>
    <button class="btn-clear" on:click={clearFilters}>Clear</button>
  </div>

  <!-- Table -->
  <div class="table-wrap">
    {#if loading}
      <div class="loading-msg">Loading audit logs...</div>
    {:else if filteredLogs.length === 0}
      <div class="empty-msg">No audit logs found.</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Date & Time</th>
            <th>Table</th>
            <th>Action</th>
            <th>Description</th>
            <th>Changed By</th>
            <th>Details</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredLogs as row, idx (row.id)}
            <tr class:insert-row={row.action === 'INSERT'} class:update-row={row.action === 'UPDATE'} class:delete-row={row.action === 'DELETE'}>
              <td>{page * pageSize + idx + 1}</td>
              <td class="nowrap">{formatDateTime(row.changed_at)}</td>
              <td><span class="table-badge">{friendlyTableName(row.table_name)}</span></td>
              <td>
                <span class="action-badge" class:action-insert={row.action === 'INSERT'} class:action-update={row.action === 'UPDATE'} class:action-delete={row.action === 'DELETE'}>
                  {row.action}
                </span>
              </td>
              <td class="desc-cell">{getDescription(row)}</td>
              <td>{row.user_email}</td>
              <td>
                <button class="btn-detail" on:click={() => toggleDetail(row.id)}>
                  {expandedId === row.id ? 'Hide' : 'View'}
                </button>
              </td>
            </tr>
            {#if expandedId === row.id}
              <tr class="detail-row">
                <td colspan="7">
                  <div class="detail-content">
                    {#if row.action === 'UPDATE'}
                      <div class="detail-changes">
                        <h4>What Changed</h4>
                        <table class="changes-table">
                          <thead>
                            <tr><th>Field</th><th>Before</th><th>After</th></tr>
                          </thead>
                          <tbody>
                            {#each getChangedFields(row.old_data, row.new_data).filter(f => !hiddenFields.has(f) && !f.endsWith('_id')) as field}
                              <tr>
                                <td class="field-name">{friendlyLabel(field)}</td>
                                <td class="old-val">{friendlyValue(row.old_data?.[field], field)}</td>
                                <td class="new-val">{friendlyValue(row.new_data?.[field], field)}</td>
                              </tr>
                            {/each}
                          </tbody>
                        </table>
                      </div>
                    {:else if row.action === 'INSERT'}
                      <div class="detail-fields">
                        <h4>New Record Details</h4>
                        <div class="field-grid">
                          {#each getDisplayFields(row.new_data) as f}
                            <div class="field-item">
                              <span class="field-label">{f.label}</span>
                              <span class="field-value">{f.value}</span>
                            </div>
                          {/each}
                        </div>
                      </div>
                    {:else}
                      <div class="detail-fields">
                        <h4>Deleted Record</h4>
                        <div class="field-grid">
                          {#each getDisplayFields(row.old_data) as f}
                            <div class="field-item">
                              <span class="field-label">{f.label}</span>
                              <span class="field-value">{f.value}</span>
                            </div>
                          {/each}
                        </div>
                      </div>
                    {/if}
                  </div>
                </td>
              </tr>
            {/if}
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <!-- Pagination -->
  <div class="pagination">
    <button class="btn-page" disabled={page === 0} on:click={prevPage}>← Previous</button>
    <span class="page-info">Page {page + 1}</span>
    <button class="btn-page" disabled={!hasMore} on:click={nextPage}>Next →</button>
  </div>
</div>

<style>
  .audit-window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .report-header { display:flex; align-items:center; justify-content:space-between; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .header-left { display:flex; align-items:center; gap:10px; }
  .back-btn { display:flex; align-items:center; justify-content:center; width:32px; height:32px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; cursor:pointer; color:#374151; transition:all .15s; }
  .back-btn:hover { background:#fef3c7; border-color:#f59e0b; color:#d97706; }
  .report-header h2 { margin:0; font-size:17px; font-weight:700; color:#111827; }
  .btn-refresh { display:flex; align-items:center; gap:5px; padding:6px 14px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; font-size:12px; font-weight:600; color:#374151; cursor:pointer; }
  .btn-refresh:hover { background:#e5e7eb; }

  .filters-bar { display:flex; align-items:flex-end; gap:12px; padding:12px 18px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; }
  .filter-group { display:flex; flex-direction:column; gap:3px; }
  .search-group { flex:1; min-width:150px; }
  .filter-group label { font-size:11px; font-weight:600; color:#6b7280; }
  .filter-group input, .filter-group select { padding:6px 10px; border:1px solid #d1d5db; border-radius:6px; font-size:13px; outline:none; }
  .filter-group input:focus, .filter-group select:focus { border-color:#f59e0b; }
  .btn-clear { padding:6px 14px; background:#fee2e2; border:1px solid #fecaca; border-radius:6px; font-size:12px; font-weight:600; color:#dc2626; cursor:pointer; align-self:flex-end; }
  .btn-clear:hover { background:#fecaca; }

  .table-wrap { flex:1; overflow:auto; padding:0 18px 12px; width:100%; box-sizing:border-box; }
  table { width:100%; border-collapse:collapse; font-size:13px; margin-top:12px; }
  thead th { background:#f9fafb; padding:10px 12px; text-align:left; font-weight:600; color:#374151; border-bottom:2px solid #e5e7eb; border-right:1px solid #e5e7eb; position:sticky; top:0; z-index:1; }
  tbody td { padding:8px 12px; border-bottom:1px solid #f3f4f6; border-right:1px solid #e5e7eb; color:#111827; vertical-align:top; }
  tbody tr:hover { background:#fffbeb; }
  .nowrap { white-space:nowrap; }

  .table-badge { display:inline-block; padding:2px 8px; background:#f3f4f6; border-radius:4px; font-size:12px; font-weight:500; color:#374151; font-family:monospace; }
  .action-badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:700; text-transform:uppercase; }
  .action-insert { background:#dcfce7; color:#15803d; }
  .action-update { background:#dbeafe; color:#1d4ed8; }
  .action-delete { background:#fee2e2; color:#dc2626; }

  .changed-fields { font-size:12px; color:#6b7280; font-style:italic; }
  .desc-cell { font-size:12px; color:#374151; max-width:320px; }

  .btn-detail { padding:3px 10px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:4px; font-size:11px; font-weight:600; color:#374151; cursor:pointer; }
  .btn-detail:hover { background:#fef3c7; border-color:#f59e0b; }

  .detail-row td { background:#fffbeb; padding:0; }
  .detail-content { padding:12px 16px; }
  .detail-changes h4, .detail-fields h4 { margin:0 0 8px; font-size:12px; font-weight:700; color:#374151; }

  .changes-table { width:100%; border-collapse:collapse; font-size:12px; margin-bottom:8px; }
  .changes-table th { background:#f9fafb; padding:6px 10px; text-align:left; font-weight:600; color:#6b7280; border-bottom:1px solid #e5e7eb; font-size:11px; }
  .changes-table td { padding:5px 10px; border-bottom:1px solid #f3f4f6; }
  .changes-table .field-name { font-weight:600; color:#374151; }
  .changes-table .old-val { color:#dc2626; background:#fef2f2; }
  .changes-table .new-val { color:#16a34a; background:#f0fdf4; }

  .field-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(220px, 1fr)); gap:8px; }
  .field-item { display:flex; flex-direction:column; padding:6px 10px; background:#f9fafb; border:1px solid #f3f4f6; border-radius:4px; }
  .field-label { font-size:10px; font-weight:600; color:#6b7280; text-transform:uppercase; letter-spacing:0.3px; }
  .field-value { font-size:13px; color:#111827; font-weight:500; word-break:break-word; }

  .pagination { display:flex; align-items:center; justify-content:center; gap:16px; padding:12px 18px; background:white; border-top:1px solid #e5e7eb; flex-shrink:0; }
  .btn-page { padding:6px 16px; background:#f3f4f6; border:1px solid #e5e7eb; border-radius:6px; font-size:12px; font-weight:600; color:#374151; cursor:pointer; }
  .btn-page:hover:not(:disabled) { background:#fef3c7; border-color:#f59e0b; }
  .btn-page:disabled { opacity:0.4; cursor:not-allowed; }
  .page-info { font-size:13px; font-weight:600; color:#6b7280; }

  .loading-msg, .empty-msg { text-align:center; padding:40px 20px; color:#9ca3af; font-size:14px; }
</style>
