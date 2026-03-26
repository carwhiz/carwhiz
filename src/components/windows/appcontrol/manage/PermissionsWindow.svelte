<!-- ============================================================
     APP CONTROL > MANAGE > PERMISSIONS WINDOW
     Purpose: Manage per-user permissions (view, create, edit, delete)
              per resource (window / feature) for each user
     Window ID: appcontrol-permissions
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { authStore } from '../../../../stores/authStore';
  import { clearUserPermissionCache } from '../../../../lib/services/permissionService';

  interface UserRow {
    id: string;
    email: string;
    role: string;
  }

  interface Permission {
    id: string;
    user_id: string;
    resource: string;
    can_view: boolean;
    can_create: boolean;
    can_edit: boolean;
    can_delete: boolean;
  }

  // All resources in the app — grouped for display
  const resourceGroups: { group: string; resources: { id: string; label: string }[] }[] = [
    {
      group: 'Finance — Manage',
      resources: [
        { id: 'finance-customers', label: 'Customers' },
        { id: 'finance-vendors', label: 'Vendors' },
        { id: 'finance-ledger', label: 'Ledger' },
        { id: 'finance-assets', label: 'Fixed Assets' },
        { id: 'finance-job-card', label: 'Job Card' },
        { id: 'finance-job-card-report', label: 'My Job Card' },
      ]
    },
    {
      group: 'Finance — Operations',
      resources: [
        { id: 'finance-sales', label: 'Sales' },
        { id: 'finance-purchase', label: 'Purchase' },
        { id: 'finance-sales-return', label: 'Sales Return' },
        { id: 'finance-purchase-return', label: 'Purchase Return' },
        { id: 'finance-receipt', label: 'Receipts' },
        { id: 'finance-payment', label: 'Payments' },
      ]
    },
    {
      group: 'Finance — Reports',
      resources: [
        { id: 'finance-sales-report', label: 'Sales Report' },
        { id: 'finance-purchase-report', label: 'Purchase Report' },
        { id: 'finance-ledger-balance', label: 'Ledger Balance' },
        { id: 'finance-day-book', label: 'Day Book' },
        { id: 'finance-trial-balance', label: 'Trial Balance' },
        { id: 'finance-profit-loss', label: 'Profit & Loss' },
        { id: 'finance-balance-sheet', label: 'Balance Sheet' },
      ]
    },
    {
      group: 'Product/Services',
      resources: [
        { id: 'products-vehicles', label: 'Vehicles' },
        { id: 'products-products', label: 'Product/Services' },
        { id: 'products-stock-management', label: 'Stock Management' },
        { id: 'products-stock-report', label: 'Stock Report' },
      ]
    },
    {
      group: 'App Control',
      resources: [
        { id: 'appcontrol-users', label: 'Users' },
        { id: 'appcontrol-permissions', label: 'Permissions' },
        { id: 'appcontrol-auditlog', label: 'Audit Logs' },
      ]
    },
    {
      group: 'HR — Management',
      resources: [
        { id: 'hr-manage-employee', label: 'Manage Employee' },
        { id: 'hr-manage-shift', label: 'Manage Shift' },
        { id: 'hr-salary-management', label: 'Salary Management' },
      ]
    },
    {
      group: 'HR — Operations',
      resources: [
        { id: 'hr-attendance-qr', label: 'Attendance QR' },
      ]
    },
    {
      group: 'HR — Reports',
      resources: [
        { id: 'hr-attendance-report', label: 'Attendance Report' },
      ]
    },
    {
      group: 'Mobile — Dashboard Cards',
      resources: [
        { id: 'mobile-dashboard-sales', label: 'Sales Card' },
        { id: 'mobile-dashboard-purchase', label: 'Purchase Card' },
        { id: 'mobile-dashboard-expense', label: 'Expense Card' },
        { id: 'mobile-dashboard-cash-balance', label: 'Cash Balance Card' },
        { id: 'mobile-dashboard-bank-balance', label: 'Bank Balance Card' },
        { id: 'mobile-dashboard-sales-balance', label: 'Sales Balance Card' },
        { id: 'mobile-dashboard-purchase-balance', label: 'Purchase Balance Card' },
        { id: 'mobile-create-job-card', label: 'Create Job Card' },
        { id: 'desktop-access', label: 'Desktop Access' },
      ]
    }
  ];

  let users: UserRow[] = [];
  let permissions: Permission[] = [];
  let selectedUserId = '';
  let loading = true;
  let saving = false;
  let error = '';
  let success = '';

  // Permission lookup: resource -> permission record
  let permMap: Record<string, Permission> = {};
  $: {
    permMap = {};
    for (const p of permissions) {
      if (p.user_id === selectedUserId) permMap[p.resource] = p;
    }
  }

  $: selectedUser = users.find(u => u.id === selectedUserId);

  onMount(() => { loadUsers(); });

  async function loadUsers() {
    loading = true;
    const { data } = await supabase.from('users').select('id, email, phone_number, role, created_at').order('email');
    users = (data as UserRow[]) || [];
    if (users.length > 0 && !selectedUserId) selectedUserId = users[0].id;
    if (selectedUserId) await loadPermissions();
    loading = false;
  }

  async function loadPermissions() {
    const { data } = await supabase.from('permissions').select('*').eq('user_id', selectedUserId);
    permissions = (data as Permission[]) || [];
  }

  async function selectUser(userId: string) {
    selectedUserId = userId;
    await loadPermissions();
  }

  function getPerm(resource: string): Permission {
    return permMap[resource] || { id: '', user_id: selectedUserId, resource, can_view: false, can_create: false, can_edit: false, can_delete: false };
  }

  async function togglePerm(resource: string, field: 'can_view' | 'can_create' | 'can_edit' | 'can_delete') {
    const existing = permMap[resource];
    const currentUserId = $authStore.user?.id || null;

    if (existing?.id) {
      const newVal = !(existing as any)[field];
      await supabase.from('permissions').update({
        [field]: newVal,
        updated_at: new Date().toISOString(),
        updated_by: currentUserId
      }).eq('id', existing.id);
    } else {
      await supabase.from('permissions').insert({
        user_id: selectedUserId,
        resource,
        can_view: field === 'can_view',
        can_create: field === 'can_create',
        can_edit: field === 'can_edit',
        can_delete: field === 'can_delete',
        created_by: currentUserId
      });
    }
    clearUserPermissionCache(selectedUserId);
    await loadPermissions();
  }

  async function toggleAllForResource(resource: string) {
    const perm = getPerm(resource);
    const allOn = perm.can_view && perm.can_create && perm.can_edit && perm.can_delete;
    const currentUserId = $authStore.user?.id || null;

    if (perm.id) {
      await supabase.from('permissions').update({
        can_view: !allOn, can_create: !allOn, can_edit: !allOn, can_delete: !allOn,
        updated_at: new Date().toISOString(), updated_by: currentUserId
      }).eq('id', perm.id);
    } else {
      await supabase.from('permissions').insert({
        user_id: selectedUserId, resource,
        can_view: !allOn, can_create: !allOn, can_edit: !allOn, can_delete: !allOn,
        created_by: currentUserId
      });
    }
    clearUserPermissionCache(selectedUserId);
    await loadPermissions();
  }

  async function grantAll(grant: boolean) {
    saving = true; error = ''; success = '';
    const currentUserId = $authStore.user?.id || null;
    const allResources = resourceGroups.flatMap(g => g.resources.map(r => r.id));

    console.log(`[PermissionsWindow] Starting ${grant ? 'GRANT ALL' : 'REVOKE ALL'} for user ${selectedUserId}`);
    console.log(`[PermissionsWindow] Total resources: ${allResources.length}`);

    const toUpdate: string[] = [];
    const toInsert: string[] = [];
    for (const res of allResources) {
      const existing = permMap[res];
      if (existing?.id) {
        toUpdate.push(existing.id);
      } else {
        toInsert.push(res);
      }
    }

    console.log(`[PermissionsWindow] Existing records to update: ${toUpdate.length}, New records to create: ${toInsert.length}`);

    if (toUpdate.length > 0) {
      console.log(`[PermissionsWindow] Updating ${toUpdate.length} existing records to ${grant}`);
      await supabase.from('permissions').update({
        can_view: grant, can_create: grant, can_edit: grant, can_delete: grant,
        updated_at: new Date().toISOString(), updated_by: currentUserId
      }).in('id', toUpdate);
      console.log(`[PermissionsWindow] Updated ${toUpdate.length} records`);
    }

    if (toInsert.length > 0) {
      console.log(`[PermissionsWindow] Creating ${toInsert.length} new permission records with grant=${grant}`);
      const rows = toInsert.map(res => ({
        user_id: selectedUserId, resource: res,
        can_view: grant, can_create: grant, can_edit: grant, can_delete: grant,
        created_by: currentUserId
      }));
      await supabase.from('permissions').insert(rows);
      console.log(`[PermissionsWindow] Created ${toInsert.length} new records`);
    }

    clearUserPermissionCache(selectedUserId);
    console.log(`[PermissionsWindow] Cleared permission cache for user ${selectedUserId}`);
    
    await loadPermissions();
    saving = false;
    success = grant ? 'All permissions granted' : 'All permissions revoked';
    console.log(`[PermissionsWindow] ${success}`);
    setTimeout(() => success = '', 2000);
  }
</script>

<div class="window">
  <div class="top-controls">
    <div class="title-area">
      <h2>Permissions</h2>
      <span class="record-count">{users.length} user{users.length !== 1 ? 's' : ''}</span>
    </div>
  </div>

  {#if error}<div class="msg msg-error" style="margin:10px 20px">{error}</div>{/if}
  {#if success}<div class="msg msg-success" style="margin:10px 20px">{success}</div>{/if}

  <div class="perm-layout">
    <!-- Left: user list -->
    <div class="user-list">
      <div class="user-list-header">Users</div>
      {#each users as user (user.id)}
        <div
          class="user-item"
          class:active={selectedUserId === user.id}
          on:click={() => selectUser(user.id)}
          on:keydown={(e) => e.key === 'Enter' && selectUser(user.id)}
          role="button"
          tabindex="0"
        >
          <span class="user-email">{user.user_name || user.email}</span>
          {#if user.role === 'admin'}<span class="admin-badge">Admin</span>{/if}
        </div>
      {/each}
    </div>

    <!-- Right: permissions grid -->
    <div class="perm-grid-container">
      {#if loading}
        <div class="table-status">Loading...</div>
      {:else if !selectedUserId}
        <div class="table-status">Select a user to manage permissions</div>
      {:else}
        <div class="perm-toolbar">
          <span class="perm-user-label">Permissions for <strong>{selectedUser?.user_name || selectedUser?.email}</strong></span>
          <div class="perm-toolbar-btns">
            <button class="btn-grant" on:click={() => grantAll(true)} disabled={saving}>Grant All</button>
            <button class="btn-revoke" on:click={() => grantAll(false)} disabled={saving}>Revoke All</button>
          </div>
        </div>

        <div class="perm-table-scroll">
          <table>
            <thead>
              <tr>
                <th class="res-col">Resource</th>
                <th class="perm-col">View</th>
                <th class="perm-col">Create</th>
                <th class="perm-col">Edit</th>
                <th class="perm-col">Delete</th>
                <th class="perm-col">All</th>
              </tr>
            </thead>
            <tbody>
              {#each resourceGroups as group}
                <tr class="group-row"><td colspan="6">{group.group}</td></tr>
                {#each group.resources as res}
                  {@const perm = permMap[res.id] || { id: '', can_view: false, can_create: false, can_edit: false, can_delete: false }}
                  <tr>
                    <td class="res-label">{res.label}</td>
                    <td class="perm-cell">
                      <label class="toggle"><input type="checkbox" checked={permMap[res.id]?.can_view || false} on:change={() => togglePerm(res.id, 'can_view')} /><span class="slider"></span></label>
                    </td>
                    <td class="perm-cell">
                      <label class="toggle"><input type="checkbox" checked={permMap[res.id]?.can_create || false} on:change={() => togglePerm(res.id, 'can_create')} /><span class="slider"></span></label>
                    </td>
                    <td class="perm-cell">
                      <label class="toggle"><input type="checkbox" checked={permMap[res.id]?.can_edit || false} on:change={() => togglePerm(res.id, 'can_edit')} /><span class="slider"></span></label>
                    </td>
                    <td class="perm-cell">
                      <label class="toggle"><input type="checkbox" checked={permMap[res.id]?.can_delete || false} on:change={() => togglePerm(res.id, 'can_delete')} /><span class="slider"></span></label>
                    </td>
                    <td class="perm-cell">
                      <label class="toggle"><input type="checkbox" checked={permMap[res.id]?.can_view && permMap[res.id]?.can_create && permMap[res.id]?.can_edit && permMap[res.id]?.can_delete || false} on:change={() => toggleAllForResource(res.id)} /><span class="slider"></span></label>
                    </td>
                  </tr>
                {/each}
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .window { width:100%; height:100%; display:flex; flex-direction:column; background:#fafafa; box-sizing:border-box; }
  .top-controls { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .title-area { display:flex; align-items:baseline; gap:10px; }
  .title-area h2 { margin:0; font-size:18px; font-weight:700; color:#111827; }
  .record-count { font-size:12px; color:#9ca3af; font-weight:500; }
  .msg { padding:8px 12px; border-radius:6px; font-size:12px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }

  /* Layout */
  .perm-layout { flex:1; display:flex; overflow:hidden; width:100%; box-sizing:border-box; }

  /* User list */
  .user-list { width:200px; background:#fff; border-right:1px solid #e5e7eb; display:flex; flex-direction:column; overflow-y:auto; flex-shrink:0; }
  .user-list-header { padding:10px 14px; font-size:11px; font-weight:700; text-transform:uppercase; color:#9ca3af; letter-spacing:.04em; border-bottom:1px solid #f3f4f6; }
  .user-item { display:flex; align-items:center; gap:6px; padding:10px 14px; border:none; background:none; text-align:left; cursor:pointer; font-size:13px; color:#374151; border-bottom:1px solid #f3f4f6; transition:background .1s; }
  .user-item:hover { background:#fffbf5; }
  .user-item.active { background:#fff7ed; border-left:3px solid #C41E3A; font-weight:600; color:#111827; }
  .user-email { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .admin-badge { font-size:9px; padding:2px 6px; background:#fef3c7; color:#d97706; border-radius:8px; font-weight:600; flex-shrink:0; }

  /* Perm grid */
  .perm-grid-container { flex:1; display:flex; flex-direction:column; overflow:hidden; }
  .perm-toolbar { display:flex; align-items:center; justify-content:space-between; padding:10px 16px; background:#fff; border-bottom:1px solid #e5e7eb; }
  .perm-user-label { font-size:13px; color:#374151; }
  .perm-toolbar-btns { display:flex; gap:6px; }
  .btn-grant { padding:5px 12px; background:#f0fdf4; border:1px solid #bbf7d0; border-radius:6px; font-size:12px; font-weight:600; color:#16a34a; cursor:pointer; }
  .btn-grant:hover { background:#16a34a; color:white; border-color:#16a34a; }
  .btn-revoke { padding:5px 12px; background:#fef2f2; border:1px solid #fecaca; border-radius:6px; font-size:12px; font-weight:600; color:#dc2626; cursor:pointer; }
  .btn-revoke:hover { background:#dc2626; color:white; border-color:#dc2626; }
  .btn-grant:disabled, .btn-revoke:disabled { opacity:.5; cursor:not-allowed; }

  .perm-table-scroll { flex:1; overflow:auto; }
  .table-status { display:flex; align-items:center; justify-content:center; height:200px; color:#9ca3af; font-size:14px; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  thead { position:sticky; top:0; z-index:2; }
  th { background:#f9fafb; padding:10px; text-align:center; font-weight:600; color:#6b7280; font-size:11px; text-transform:uppercase; letter-spacing:.03em; border-bottom:1px solid #e5e7eb; border-right:1px solid #e5e7eb; }
  td { border-right:1px solid #e5e7eb; }
  th.res-col { text-align:left; width:220px; }
  th.perm-col { width:70px; }
  .group-row td { background:#f3f4f6; padding:8px 14px; font-size:11px; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:.04em; }
  .res-label { padding:8px 14px 8px 28px; color:#374151; }
  .perm-cell { text-align:center; padding:6px; }

  /* Toggle switch */
  .toggle { position:relative; display:inline-block; width:34px; height:18px; }
  .toggle input { opacity:0; width:0; height:0; }
  .slider { position:absolute; cursor:pointer; top:0; left:0; right:0; bottom:0; background:#e5e7eb; border-radius:18px; transition:.2s; }
  .slider::before { content:''; position:absolute; height:14px; width:14px; left:2px; bottom:2px; background:white; border-radius:50%; transition:.2s; }
  .toggle input:checked + .slider { background:#C41E3A; }
  .toggle input:checked + .slider::before { transform:translateX(16px); }
</style>
