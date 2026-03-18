<!-- ============================================================
     FINANCE > MANAGE > LEDGER WINDOW
     Purpose: Ledger listing with category filter, search,
              Create Ledger + Create Employee buttons
     Window ID: finance-ledger
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface LedgerRow {
    id: string;
    ledger_name: string;
    opening_balance: number | null;
    bank_account_number: string | null;
    status: string | null;
    reference_type: string | null;
    created_at: string;
    ledger_types: { name: string } | null;
    ledger_categories: { name: string } | null;
    expense_categories: { name: string } | null;
  }

  interface CategoryOption {
    id: string;
    name: string;
  }

  let ledgers: LedgerRow[] = [];
  let categories: CategoryOption[] = [];
  let loading = true;
  let error = '';
  let searchQuery = '';
  let selectedCategory = '';

  $: filtered = ledgers.filter(l => {
    const matchSearch = !searchQuery ||
      l.ledger_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (l.ledger_types?.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (l.reference_type || '').toLowerCase().includes(searchQuery.toLowerCase());
    const matchCategory = !selectedCategory ||
      l.ledger_categories?.name === selectedCategory;
    return matchSearch && matchCategory;
  });

  onMount(() => {
    loadCategories();
    loadLedgers();
  });

  async function loadCategories() {
    const { data } = await supabase.from('ledger_categories').select('id, name').order('sort_order');
    categories = (data as CategoryOption[]) || [];
  }

  async function loadLedgers() {
    loading = true;
    error = '';
    const { data, error: dbErr } = await supabase
      .from('ledger')
      .select(`
        id, ledger_name, opening_balance, bank_account_number,
        status, reference_type, created_at,
        ledger_types ( name ),
        ledger_categories ( name ),
        expense_categories ( name )
      `)
      .order('created_at', { ascending: false });

    loading = false;
    if (dbErr) { error = dbErr.message; return; }
    ledgers = (data as unknown as LedgerRow[]) || [];
  }

  function openCreateLedger() {
    windowStore.open('finance-create-ledger', 'Create Ledger');
  }

  function openCreateEmployee() {
    windowStore.open('finance-create-employee', 'Create Employee');
  }

  function openEditLedger(id: string) {
    windowStore.open('finance-edit-ledger-' + id, 'Edit Ledger');
  }

  function formatBalance(val: number | null) {
    if (val === null || val === undefined) return '0.00';
    return val.toFixed(2);
  }

  export { loadLedgers };
</script>

<div class="window">
  <div class="top-controls">
    <div class="title-area">
      <h2>Ledger</h2>
      <span class="record-count">{filtered.length} of {ledgers.length} record{ledgers.length !== 1 ? 's' : ''}</span>
    </div>
    <div class="actions-area">
      <!-- Category Filter -->
      <select class="category-filter" bind:value={selectedCategory}>
        <option value="">All Categories</option>
        {#each categories as cat (cat.id)}
          <option value={cat.name}>{cat.name}</option>
        {/each}
      </select>

      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
        <input type="text" bind:value={searchQuery} placeholder="Search ledger..." />
      </div>
      <button class="btn-create" on:click={openCreateLedger}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Create Ledger
      </button>
      <button class="btn-create btn-employee" on:click={openCreateEmployee}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Create Employee
      </button>
    </div>
  </div>

  <div class="table-container">
    {#if loading}
      <div class="table-status">Loading ledgers...</div>
    {:else if error}
      <div class="table-status error">{error}</div>
    {:else if filtered.length === 0}
      <div class="table-status">{searchQuery || selectedCategory ? 'No ledgers match your filter' : 'No ledgers created yet'}</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Ledger Name</th>
            <th>Type</th>
            <th>Category</th>
            <th>Ref. Type</th>
            <th>Expense Cat.</th>
            <th>Bank Acct</th>
            <th>Opening Bal.</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as l, i (l.id)}
            <tr>
              <td class="num">{i + 1}</td>
              <td class="name-col">{l.ledger_name}</td>
              <td>{l.ledger_types?.name || '—'}</td>
              <td>
                {#if l.ledger_categories?.name}
                  <span class="cat-badge">{l.ledger_categories.name}</span>
                {:else}
                  —
                {/if}
              </td>
              <td>{l.reference_type ? l.reference_type.charAt(0).toUpperCase() + l.reference_type.slice(1) : '—'}</td>
              <td>{l.expense_categories?.name || '—'}</td>
              <td>{l.bank_account_number || '—'}</td>
              <td class="balance">{formatBalance(l.opening_balance)}</td>
              <td>
                <span class="status-badge {l.status || 'active'}">{(l.status || 'active').charAt(0).toUpperCase() + (l.status || 'active').slice(1)}</span>
              </td>
              <td class="actions">
                <button class="btn-edit" title="Edit" on:click={() => openEditLedger(l.id)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  Edit
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>

<style>
  .window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; }
  .top-controls { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; flex-wrap:wrap; gap:10px; }
  .title-area { display:flex; align-items:baseline; gap:10px; }
  .title-area h2 { margin:0; font-size:18px; font-weight:700; color:#111827; }
  .record-count { font-size:12px; color:#9ca3af; font-weight:500; }
  .actions-area { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }

  .category-filter { padding:7px 10px; border:1px solid #e5e7eb; border-radius:6px; font-size:13px; background:#f9fafb; color:#374151; outline:none; cursor:pointer; }
  .category-filter:focus { border-color:#C41E3A; }

  .search-box { display:flex; align-items:center; gap:6px; padding:6px 10px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:6px; }
  .search-box svg { color:#9ca3af; flex-shrink:0; }
  .search-box input { border:none; background:none; outline:none; font-size:13px; width:160px; color:#374151; }
  .btn-create { display:flex; align-items:center; gap:6px; padding:8px 16px; background:#C41E3A; color:white; border:none; border-radius:8px; font-size:13px; font-weight:600; cursor:pointer; transition:background .15s; white-space:nowrap; }
  .btn-create:hover { background:#C41E3A; }
  .btn-employee { background:#7c3aed; }
  .btn-employee:hover { background:#6d28d9; }

  .table-container { flex:1; overflow:auto; }
  .table-status { display:flex; align-items:center; justify-content:center; height:200px; color:#9ca3af; font-size:14px; }
  .table-status.error { color:#ef4444; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  thead { position:sticky; top:0; z-index:2; }
  th { background:#f9fafb; padding:10px; text-align:left; font-weight:600; color:#6b7280; font-size:11px; text-transform:uppercase; letter-spacing:.03em; border-bottom:1px solid #e5e7eb; white-space:nowrap; }
  td { padding:9px 10px; color:#374151; border-bottom:1px solid #f3f4f6; white-space:nowrap; }
  tr:hover td { background:#fffbf5; }
  .num { color:#9ca3af; width:36px; }
  .name-col { font-weight:600; color:#111827; }
  .balance { font-family:'Courier New',monospace; text-align:right; }

  .cat-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; background:#e0e7ff; color:#4338ca; }
  .status-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; }
  .status-badge.active { background:#dcfce7; color:#16a34a; }
  .status-badge.inactive { background:#fef2f2; color:#dc2626; }

  .actions { width:80px; }
  .btn-edit { display:inline-flex; align-items:center; gap:4px; padding:5px 10px; background:#fff7ed; border:1px solid #fed7aa; border-radius:5px; font-size:12px; font-weight:500; color:#C41E3A; cursor:pointer; transition:all .15s; }
  .btn-edit:hover { background:#C41E3A; color:white; border-color:#C41E3A; }
</style>
