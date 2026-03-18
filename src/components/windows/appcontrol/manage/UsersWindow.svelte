<!-- ============================================================
     APP CONTROL > MANAGE > USERS WINDOW
     Purpose: User management — list, create, edit, delete users
     Window ID: appcontrol-users
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { authStore } from '../../../../stores/authStore';

  interface UserRow {
    id: string;
    email: string;
    phone_number: string;
    role: string;
    created_at: string;
  }

  let users: UserRow[] = [];
  let loading = true;
  let error = '';
  let searchQuery = '';

  // Create form
  let showCreateForm = false;
  let formEmail = '';
  let formPhone = '';
  let formPassword = '';
  let formRole = 'user';
  let formSaving = false;
  let formError = '';
  let formSuccess = '';

  // Edit form
  let editUserId = '';
  let editEmail = '';
  let editPhone = '';
  let editRole = '';
  let editPassword = '';
  let editSaving = false;
  let editError = '';
  let editSuccess = '';

  $: filtered = searchQuery
    ? users.filter(u =>
        u.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
        u.phone_number.includes(searchQuery) ||
        u.role.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : users;

  onMount(() => { loadUsers(); });

  async function loadUsers() {
    loading = true;
    error = '';
    const { data, error: dbErr } = await supabase
      .from('users')
      .select('id, email, phone_number, role, created_at')
      .order('created_at', { ascending: false });

    loading = false;
    if (dbErr) { error = dbErr.message; return; }
    users = (data as UserRow[]) || [];
  }

  function formatDate(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    return `${dd}/${mm}/${d.getFullYear()}`;
  }

  // ---- CREATE ----
  function openCreateForm() {
    formEmail = ''; formPhone = ''; formPassword = ''; formRole = 'user';
    formError = ''; formSuccess = '';
    showCreateForm = true;
    editUserId = '';
  }

  async function handleCreate() {
    if (!formEmail.trim()) { formError = 'Email is required'; return; }
    if (!formPhone.trim()) { formError = 'Phone is required'; return; }
    if (!formPassword) { formError = 'Password is required'; return; }

    formSaving = true; formError = ''; formSuccess = '';

    const { data, error: rpcErr } = await supabase.rpc('register_user', {
      p_email: formEmail.trim(),
      p_phone_number: formPhone.trim(),
      p_password: formPassword,
      p_role: formRole
    });

    formSaving = false;

    if (rpcErr) { formError = rpcErr.message; return; }
    if (data?.error) { formError = data.error; return; }

    formSuccess = 'User created successfully!';
    setTimeout(() => { showCreateForm = false; formSuccess = ''; }, 1500);
    loadUsers();
  }

  // ---- EDIT ----
  function openEdit(user: UserRow) {
    showCreateForm = false;
    editUserId = user.id;
    editEmail = user.email;
    editPhone = user.phone_number;
    editRole = user.role;
    editPassword = '';
    editError = ''; editSuccess = '';
  }

  async function handleEdit() {
    if (!editEmail.trim()) { editError = 'Email is required'; return; }
    if (!editPhone.trim()) { editError = 'Phone is required'; return; }

    editSaving = true; editError = ''; editSuccess = '';

    const updateData: Record<string, any> = {
      email: editEmail.trim(),
      phone_number: editPhone.trim(),
      role: editRole,
      updated_at: new Date().toISOString(),
      updated_by: $authStore.user?.id || null
    };

    // If password provided, hash it via RPC (we update hash directly)
    if (editPassword) {
      const { data: hashData } = await supabase.rpc('hash_password', { p_password: editPassword });
      if (hashData) updateData.password_hash = hashData;
    }

    const { error: dbErr } = await supabase.from('users').update(updateData).eq('id', editUserId);
    editSaving = false;

    if (dbErr) { editError = dbErr.message; return; }

    editSuccess = 'User updated!';
    setTimeout(() => { editUserId = ''; editSuccess = ''; }, 1500);
    loadUsers();
  }

  function cancelEdit() { editUserId = ''; }

  // ---- DELETE ----
  async function handleDelete(userId: string, email: string) {
    if (userId === $authStore.user?.id) { error = 'Cannot delete your own account'; setTimeout(() => error = '', 3000); return; }
    if (!confirm(`Delete user "${email}"? This cannot be undone.`)) return;

    const { error: dbErr } = await supabase.from('users').delete().eq('id', userId);
    if (dbErr) { error = dbErr.message; return; }
    loadUsers();
  }
</script>

<div class="window">
  <div class="top-controls">
    <div class="title-area">
      <h2>Users</h2>
      <span class="record-count">{users.length} user{users.length !== 1 ? 's' : ''}</span>
    </div>
    <div class="actions-area">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
        <input type="text" bind:value={searchQuery} placeholder="Search users..." />
      </div>
      <button class="btn-create" on:click={openCreateForm}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Create User
      </button>
    </div>
  </div>

  <!-- CREATE FORM -->
  {#if showCreateForm}
    <div class="form-panel">
      <h3>Create New User</h3>
      {#if formError}<div class="msg msg-error">{formError}</div>{/if}
      {#if formSuccess}<div class="msg msg-success">{formSuccess}</div>{/if}
      <div class="form-grid">
        <label>Email <input type="email" bind:value={formEmail} placeholder="user@example.com" /></label>
        <label>Phone <input type="text" bind:value={formPhone} placeholder="+91..." /></label>
        <label>Password <input type="password" bind:value={formPassword} placeholder="Password" /></label>
        <label>Role
          <select bind:value={formRole}>
            <option value="user">User</option>
            {#if $authStore.user?.role === 'admin'}<option value="admin">Admin</option>{/if}
          </select>
        </label>
      </div>
      <div class="form-actions">
        <button class="btn-save" on:click={handleCreate} disabled={formSaving}>{formSaving ? 'Creating...' : 'Create User'}</button>
        <button class="btn-cancel" on:click={() => showCreateForm = false}>Cancel</button>
      </div>
    </div>
  {/if}

  <!-- EDIT FORM -->
  {#if editUserId}
    <div class="form-panel edit-panel">
      <h3>Edit User — {editEmail}</h3>
      {#if editError}<div class="msg msg-error">{editError}</div>{/if}
      {#if editSuccess}<div class="msg msg-success">{editSuccess}</div>{/if}
      <div class="form-grid">
        <label>Email <input type="email" bind:value={editEmail} /></label>
        <label>Phone <input type="text" bind:value={editPhone} /></label>
        <label>New Password <input type="password" bind:value={editPassword} placeholder="Leave blank to keep current" /></label>
        <label>Role
          <select bind:value={editRole}>
            <option value="user">User</option>
            {#if $authStore.user?.role === 'admin'}<option value="admin">Admin</option>{/if}
          </select>
        </label>
      </div>
      <div class="form-actions">
        <button class="btn-save" on:click={handleEdit} disabled={editSaving}>{editSaving ? 'Saving...' : 'Save Changes'}</button>
        <button class="btn-cancel" on:click={cancelEdit}>Cancel</button>
      </div>
    </div>
  {/if}

  <div class="table-container">
    {#if loading}
      <div class="table-status">Loading users...</div>
    {:else if error}
      <div class="table-status error">{error}</div>
    {:else if filtered.length === 0}
      <div class="table-status">{searchQuery ? 'No users match your search' : 'No users found'}</div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Email</th>
            <th>Phone</th>
            <th>Role</th>
            <th>Created</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as u, i (u.id)}
            <tr>
              <td class="num">{i + 1}</td>
              <td class="name-col">{u.email}</td>
              <td>{u.phone_number}</td>
              <td><span class="role-badge" class:admin={u.role === 'admin'}>{u.role}</span></td>
              <td>{formatDate(u.created_at)}</td>
              <td class="actions">
                <button class="btn-edit" on:click={() => openEdit(u)} title="Edit">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                </button>
                <button class="btn-delete" on:click={() => handleDelete(u.id, u.email)} title="Delete">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
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
  .top-controls { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; background:white; border-bottom:1px solid #e5e7eb; flex-shrink:0; }
  .title-area { display:flex; align-items:baseline; gap:10px; }
  .title-area h2 { margin:0; font-size:18px; font-weight:700; color:#111827; }
  .record-count { font-size:12px; color:#9ca3af; font-weight:500; }
  .actions-area { display:flex; align-items:center; gap:10px; }
  .search-box { display:flex; align-items:center; gap:6px; padding:6px 10px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:6px; }
  .search-box svg { color:#9ca3af; flex-shrink:0; }
  .search-box input { border:none; background:none; outline:none; font-size:13px; width:180px; color:#374151; }
  .btn-create { display:flex; align-items:center; gap:6px; padding:8px 16px; background:#F97316; color:white; border:none; border-radius:8px; font-size:13px; font-weight:600; cursor:pointer; transition:background .15s; white-space:nowrap; }
  .btn-create:hover { background:#EA580C; }

  /* Form panel */
  .form-panel { padding:16px 20px; background:#fff; border-bottom:1px solid #e5e7eb; }
  .form-panel h3 { margin:0 0 12px; font-size:15px; font-weight:700; color:#111827; }
  .form-grid { display:grid; grid-template-columns:1fr 1fr 1fr; gap:12px; }
  .form-grid label { display:flex; flex-direction:column; gap:4px; font-size:12px; font-weight:600; color:#6b7280; }
  .form-grid input, .form-grid select { padding:7px 10px; border:1px solid #e5e7eb; border-radius:6px; font-size:13px; color:#111827; background:#fafafa; }
  .form-grid input:focus, .form-grid select:focus { outline:none; border-color:#F97316; background:white; }
  .form-actions { display:flex; gap:8px; margin-top:14px; }
  .btn-save { padding:8px 20px; background:#F97316; color:white; border:none; border-radius:8px; font-size:13px; font-weight:600; cursor:pointer; }
  .btn-save:hover { background:#EA580C; }
  .btn-save:disabled { opacity:.6; cursor:not-allowed; }
  .btn-cancel { padding:8px 16px; background:#f3f4f6; color:#374151; border:1px solid #e5e7eb; border-radius:8px; font-size:13px; cursor:pointer; }
  .btn-cancel:hover { background:#e5e7eb; }
  .edit-panel { background:#fffbf5; border-left:3px solid #F97316; }
  .msg { padding:8px 12px; border-radius:6px; font-size:12px; margin-bottom:10px; }
  .msg-error { background:#fef2f2; color:#dc2626; border:1px solid #fecaca; }
  .msg-success { background:#f0fdf4; color:#16a34a; border:1px solid #bbf7d0; }

  /* Table */
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
  .role-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:600; background:#f3f4f6; color:#6b7280; }
  .role-badge.admin { background:#fef3c7; color:#d97706; }
  .actions { width:80px; display:flex; gap:6px; }
  .btn-edit { display:inline-flex; align-items:center; padding:5px 8px; background:#fff7ed; border:1px solid #fed7aa; border-radius:5px; color:#EA580C; cursor:pointer; transition:all .15s; }
  .btn-edit:hover { background:#F97316; color:white; border-color:#F97316; }
  .btn-delete { display:inline-flex; align-items:center; padding:5px 8px; background:#fef2f2; border:1px solid #fecaca; border-radius:5px; color:#dc2626; cursor:pointer; transition:all .15s; }
  .btn-delete:hover { background:#dc2626; color:white; border-color:#dc2626; }
</style>
