<!-- ============================================================
     FINANCE > MANAGE > VENDORS WINDOW
     Purpose: Vendor listing page with table and Create button
     Window ID: finance-vendors
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface VendorRow {
    id: string;
    name: string;
    state: string | null;
    district: string | null;
    place: string | null;
    pin_code: string | null;
    address_detail: string | null;
    email: string | null;
    created_at: string;
    vendor_phones: { phone: string }[];
  }

  let vendors: VendorRow[] = [];
  let loading = true;
  let error = '';
  let searchQuery = '';

  $: filtered = searchQuery
    ? vendors.filter(v =>
        v.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (v.place || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
        (v.email || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
        v.vendor_phones.some(p => p.phone.includes(searchQuery))
      )
    : vendors;

  onMount(() => { loadVendors(); });

  async function loadVendors() {
    loading = true;
    error = '';
    const { data, error: dbErr } = await supabase
      .from('vendors')
      .select(`
        id, name, state, district, place, pin_code, address_detail, email, created_at,
        vendor_phones ( phone )
      `)
      .order('created_at', { ascending: false });

    loading = false;
    if (dbErr) { error = dbErr.message; return; }
    vendors = (data as unknown as VendorRow[]) || [];
  }

  function openCreate() {
    windowStore.open('finance-create-vendor', 'Create Vendor');
  }

  export { loadVendors };
</script>

<div class="window">
  <div class="top-controls">
    <div class="title-area">
      <h2>Vendors</h2>
      <span class="record-count">{vendors.length} record{vendors.length !== 1 ? 's' : ''}</span>
    </div>
    <div class="actions-area">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
        <input type="text" bind:value={searchQuery} placeholder="Search vendors..." />
      </div>
      <button class="btn-create" on:click={openCreate}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Create Vendor
      </button>
    </div>
  </div>

  <div class="table-container">
    {#if loading}
      <div class="table-status">Loading vendors...</div>
    {:else if error}
      <div class="table-status error">{error}</div>
    {:else if filtered.length === 0}
      <div class="table-status">{searchQuery ? 'No vendors match your search' : 'No vendors created yet'}</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Name</th>
            <th>Phone(s)</th>
            <th>Email</th>
            <th>Place</th>
            <th>District</th>
            <th>State</th>
            <th>Pin Code</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as v, i (v.id)}
            <tr>
              <td class="num">{i + 1}</td>
              <td class="name-col">{v.name}</td>
              <td>{v.vendor_phones.map(p => p.phone).join(', ') || '—'}</td>
              <td>{v.email || '—'}</td>
              <td>{v.place || '—'}</td>
              <td>{v.district || '—'}</td>
              <td>{v.state || '—'}</td>
              <td>{v.pin_code || '—'}</td>
              <td class="actions">
                <button class="btn-edit" title="Edit">
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
  .window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .top-controls { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .title-area { display:flex; align-items:baseline; gap:10px; }
  .title-area h2 { margin:0; font-size:18px; font-weight:700; color:#111827; }
  .record-count { font-size:12px; color:#9ca3af; font-weight:500; }
  .actions-area { display:flex; align-items:center; gap:10px; }
  .search-box { display:flex; align-items:center; gap:6px; padding:6px 10px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:6px; }
  .search-box svg { color:#9ca3af; flex-shrink:0; }
  .search-box input { border:none; background:none; outline:none; font-size:13px; width:180px; color:#374151; }
  .btn-create { display:flex; align-items:center; gap:6px; padding:8px 16px; background:#C41E3A; color:white; border:none; border-radius:8px; font-size:13px; font-weight:600; cursor:pointer; transition:background .15s; white-space:nowrap; }
  .btn-create:hover { background:#C41E3A; }
  .table-container { flex:1; overflow:auto; width:100%; box-sizing:border-box; }
  .table-status { display:flex; align-items:center; justify-content:center; height:200px; color:#9ca3af; font-size:14px; }
  .table-status.error { color:#ef4444; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  thead { position:sticky; top:0; z-index:2; }
  th { background:#f9fafb; padding:10px; text-align:left; font-weight:600; color:#6b7280; font-size:11px; text-transform:uppercase; letter-spacing:.03em; border-bottom:1px solid #e5e7eb; border-right:1px solid #e5e7eb; white-space:nowrap; }
  td { padding:9px 10px; color:#374151; border-bottom:1px solid #f3f4f6; border-right:1px solid #e5e7eb; white-space:nowrap; }
  tr:hover td { background:#fffbf5; }
  .num { color:#9ca3af; width:36px; }
  .name-col { font-weight:600; color:#111827; }
  .actions { width:80px; }
  .btn-edit { display:inline-flex; align-items:center; gap:4px; padding:5px 10px; background:#fff7ed; border:1px solid #fed7aa; border-radius:5px; font-size:12px; font-weight:500; color:#C41E3A; cursor:pointer; transition:all .15s; }
  .btn-edit:hover { background:#C41E3A; color:white; border-color:#C41E3A; }
</style>
