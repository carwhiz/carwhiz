<!-- ============================================================
     FINANCE > REPORTS > JOB CARD REPORT WINDOW
     Purpose: List all job cards with filters, view, edit, delete
     Window ID: finance-job-card-report
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import { authStore } from '../../../../stores/authStore';
  import { canUserViewResource, canUserEditResource, canUserDeleteResource } from '../../../../lib/services/permissionService';

  let jobCards: any[] = [];
  let loading = true;
  let permView = true;
  let permEdit = true;
  let permDelete = true;

  // Filters
  let fromDate = '';
  let toDate = '';
  let statusFilter = '';
  let customerSearch = '';
  let userFilter = '';
  let users: any[] = [];

  // View/Edit mode
  let viewMode: 'list' | 'view' | 'edit' = 'list';
  let selectedJC: any = null;
  let jcItems: any[] = [];
  let jcPhotos: any[] = [];
  let jcNotes: any[] = [];
  let jcLogs: any[] = [];

  // Edit fields
  let editDescription = '';
  let editDetails = '';
  let editPriority = '';
  let editAssignedUserId = '';
  let editExpectedDate = '';
  let editSaving = false;
  let editError = '';

  // Add items in edit mode
  let allProducts: any[] = [];
  let productSearch = '';
  let filteredProducts: any[] = [];
  let showProductDropdown = false;
  let selectedProduct: any = null;
  let itemQty = 1;
  let itemPrice = '';
  let itemDiscount = 0;
  let itemNotes = '';
  let addingItem = false;
  let itemError = '';

  $: filteredJobs = applyFilters(jobCards, fromDate, toDate, statusFilter, customerSearch, userFilter);

  onMount(async () => {
    const userId = $authStore.user?.id;
    if (userId) {
      const [v, e, d] = await Promise.all([
        canUserViewResource(userId, 'finance-job-card-report'),
        canUserEditResource(userId, 'finance-job-card-report'),
        canUserDeleteResource(userId, 'finance-job-card-report'),
      ]);
      permView = v; permEdit = e; permDelete = d;
      if (!permView) { loading = false; return; }
    }
    await Promise.all([loadJobCards(), loadUsers(), loadProducts()]);
  });

  function formatDate(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    return `${dd}/${mm}/${d.getFullYear()}`;
  }

  function formatDateTime(dt: string): string {
    if (!dt) return '—';
    const d = new Date(dt);
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    let h = d.getHours(); const min = String(d.getMinutes()).padStart(2, '0');
    const ampm = h >= 12 ? 'PM' : 'AM'; h = h % 12 || 12;
    return `${dd}/${mm}/${d.getFullYear()} ${h}:${min} ${ampm}`;
  }

  async function loadJobCards() {
    loading = true;
    const { data } = await supabase
      .from('job_cards')
      .select('id, job_card_no, status, priority, description, expected_date, created_at, customer_id, vehicle_id, assigned_user_id, customers(name), vehicles(model_name), users:assigned_user_id(email)')
      .order('created_at', { ascending: false });
    jobCards = (data || []).map((j: any) => ({
      ...j,
      customer_name: j.customers?.name || '—',
      vehicle_name: j.vehicles?.model_name || '—',
      assigned_name: j.users?.email || '—',
    }));
    loading = false;
  }

  async function loadUsers() {
    const { data } = await supabase.from('users').select('id, email, phone_number, role, created_at').order('email');
    users = data || [];
  }

  async function loadProducts() {
    const { data } = await supabase.from('products').select('id, product_name, product_type, sales_price').order('product_name');
    allProducts = data || [];
  }

  function handleProductSearch() {
    const q = productSearch.toLowerCase().trim();
    if (!q) { filteredProducts = []; showProductDropdown = false; return; }
    filteredProducts = allProducts.filter(p =>
      p.product_name.toLowerCase().includes(q)
    ).slice(0, 10);
    showProductDropdown = filteredProducts.length > 0;
  }

  function selectProduct(p: any) {
    selectedProduct = p;
    itemPrice = (p.sales_price || 0).toString();
    productSearch = '';
    showProductDropdown = false;
    itemError = '';
  }

  async function addItemToJobCard() {
    if (!selectedProduct) { itemError = 'Please select a product'; return; }
    if (itemQty <= 0) { itemError = 'Quantity must be greater than 0'; return; }
    
    const price = parseFloat(itemPrice) || 0;
    const discount = itemDiscount || 0;
    const total = (itemQty * price) - discount;

    addingItem = true;
    itemError = '';

    const { error } = await supabase.from('job_card_items').insert([{
      job_card_id: selectedJC.id,
      item_type: selectedProduct.product_type || 'product',
      item_id: selectedProduct.id,
      name: selectedProduct.product_name,
      qty: itemQty,
      price: price,
      discount: discount,
      total: total,
      notes: itemNotes,
      created_by: $authStore.user?.id || null,
      updated_by: $authStore.user?.id || null,
    }]);

    if (error) {
      itemError = 'Failed to add item: ' + error.message;
      addingItem = false;
      return;
    }

    // Reset form
    selectedProduct = null;
    itemQty = 1;
    itemPrice = '';
    itemDiscount = 0;
    itemNotes = '';
    addingItem = false;

    // Reload items
    const { data } = await supabase.from('job_card_items').select('*').eq('job_card_id', selectedJC.id).order('created_at');
    jcItems = data || [];
  }

  async function removeItemFromJobCard(itemId: string) {
    if (!confirm('Remove this item from the job card?')) return;

    const { error } = await supabase.from('job_card_items').delete().eq('id', itemId);
    if (error) {
      alert('Failed to remove item: ' + error.message);
      return;
    }

    const { data } = await supabase.from('job_card_items').select('*').eq('job_card_id', selectedJC.id).order('created_at');
    jcItems = data || [];
  }

  function applyFilters(list: any[], from: string, to: string, status: string, search: string, user: string) {
    let result = list;
    if (from) result = result.filter(r => r.created_at >= from);
    if (to) result = result.filter(r => r.created_at <= to + 'T23:59:59');
    if (status) result = result.filter(r => r.status === status);
    if (user) result = result.filter(r => r.assigned_user_id === user);
    if (search.trim()) {
      const q = search.toLowerCase().trim();
      result = result.filter(r =>
        r.customer_name.toLowerCase().includes(q) ||
        r.vehicle_name.toLowerCase().includes(q) ||
        (r.job_card_no || '').toLowerCase().includes(q)
      );
    }
    return result;
  }

  function clearFilters() { fromDate = ''; toDate = ''; statusFilter = ''; customerSearch = ''; userFilter = ''; }

  async function viewJobCard(jc: any) {
    selectedJC = jc;
    viewMode = 'view';
    await loadJobCardDetails(jc.id);
  }

  async function editJobCard(jc: any) {
    if (jc.status === 'Closed' || jc.status === 'Billed') return;
    selectedJC = jc;
    editDescription = jc.description || '';
    editDetails = jc.details || '';
    editPriority = jc.priority || 'Normal';
    editAssignedUserId = jc.assigned_user_id || '';
    editExpectedDate = jc.expected_date || '';
    editError = '';
    viewMode = 'edit';
    await loadJobCardDetails(jc.id);
  }

  async function loadJobCardDetails(id: string) {
    const [itemsRes, photosRes, notesRes, logsRes] = await Promise.all([
      supabase.from('job_card_items').select('*').eq('job_card_id', id).order('created_at'),
      supabase.from('job_card_photos').select('*').eq('job_card_id', id).order('created_at'),
      supabase.from('job_card_notes').select('*, users:created_by(email)').eq('job_card_id', id).order('created_at', { ascending: false }),
      supabase.from('job_card_logs').select('*, users:action_by(email)').eq('job_card_id', id).order('created_at', { ascending: false }),
    ]);
    jcItems = itemsRes.data || [];
    jcPhotos = photosRes.data || [];
    jcNotes = (notesRes.data || []).map((n: any) => ({ ...n, by_name: n.users?.email || '—' }));
    jcLogs = (logsRes.data || []).map((l: any) => ({ ...l, by_name: l.users?.email || '—' }));
  }

  function goBackToList() { viewMode = 'list'; selectedJC = null; jcItems = []; jcPhotos = []; jcNotes = []; jcLogs = []; }

  async function handleEditSave() {
    if (!editDescription.trim()) { editError = 'Description is required'; return; }
    if (!editAssignedUserId) { editError = 'Assigned user is required'; return; }
    editSaving = true;
    editError = '';

    const { error } = await supabase.from('job_cards').update({
      description: editDescription.trim(),
      details: editDetails.trim() || null,
      priority: editPriority,
      assigned_user_id: editAssignedUserId,
      expected_date: editExpectedDate || null,
      updated_by: $authStore.user?.id || null,
      updated_at: new Date().toISOString(),
    }).eq('id', selectedJC.id);

    if (error) { editError = 'Failed to update: ' + error.message; editSaving = false; return; }

    await supabase.from('job_card_logs').insert({
      job_card_id: selectedJC.id,
      action: 'Edited',
      note: 'Job card details updated',
      action_by: $authStore.user?.id || null,
      created_by: $authStore.user?.id || null,
    });

    editSaving = false;
    await loadJobCards();
    goBackToList();
  }

  async function handleDelete(jc: any) {
    if (jc.status !== 'Open') return;
    if (!confirm(`Delete job card ${jc.job_card_no}? This cannot be undone.`)) return;

    await supabase.from('job_cards').delete().eq('id', jc.id);
    await loadJobCards();
  }

  function getStatusClass(s: string): string {
    const map: Record<string, string> = { 'Open': 'status-open', 'In Progress': 'status-progress', 'Closed': 'status-closed', 'Billed': 'status-billed', 'Cancelled': 'status-cancelled' };
    return map[s] || '';
  }

  function getPriorityClass(p: string): string {
    const map: Record<string, string> = { 'Low': 'pri-low', 'Normal': 'pri-normal', 'High': 'pri-high', 'Urgent': 'pri-urgent' };
    return map[p] || '';
  }
</script>

<div class="report-window">
  {#if !permView}
    <div class="perm-denied"><p>You do not have permission to view job card reports.</p></div>
  {:else if viewMode === 'list'}
    <!-- ===== LIST VIEW ===== -->
    <div class="report-header">
      <div class="header-left">
        <button class="back-btn" on:click={() => windowStore.close('finance-job-card-report')} title="Close">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>Job Cards Report</h2>
      </div>
      <div class="header-actions">
        <button class="btn-create" on:click={() => windowStore.open('finance-job-card', 'Job Card')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
          New Job Card
        </button>
        <button class="btn-refresh" on:click={loadJobCards}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="15" height="15"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="filters-bar">
      <div class="filter-group">
        <label>From</label>
        <input type="date" bind:value={fromDate} />
      </div>
      <div class="filter-group">
        <label>To</label>
        <input type="date" bind:value={toDate} />
      </div>
      <div class="filter-group">
        <label>Status</label>
        <select bind:value={statusFilter}>
          <option value="">All</option>
          <option value="Open">Open</option>
          <option value="In Progress">In Progress</option>
          <option value="Closed">Closed</option>
          <option value="Billed">Billed</option>
          <option value="Cancelled">Cancelled</option>
        </select>
      </div>
      <div class="filter-group">
        <label>Assigned To</label>
        <select bind:value={userFilter}>
          <option value="">All</option>
          {#each users as u}
            <option value={u.id}>{u.email}</option>
          {/each}
        </select>
      </div>
      <div class="filter-group search-group">
        <label>Search</label>
        <input type="text" placeholder="Customer / Vehicle / Job #" bind:value={customerSearch} />
      </div>
      <button class="btn-clear" on:click={clearFilters}>Clear</button>
    </div>

    <!-- Summary -->
    <div class="summary-cards">
      <div class="s-card"><span class="s-label">Total</span><span class="s-val">{filteredJobs.length}</span></div>
      <div class="s-card open"><span class="s-label">Open</span><span class="s-val">{filteredJobs.filter(j => j.status === 'Open').length}</span></div>
      <div class="s-card progress"><span class="s-label">In Progress</span><span class="s-val">{filteredJobs.filter(j => j.status === 'In Progress').length}</span></div>
      <div class="s-card closed"><span class="s-label">Closed</span><span class="s-val">{filteredJobs.filter(j => j.status === 'Closed').length}</span></div>
      <div class="s-card billed"><span class="s-label">Billed</span><span class="s-val">{filteredJobs.filter(j => j.status === 'Billed').length}</span></div>
    </div>

    <!-- Table -->
    <div class="table-wrap">
      {#if loading}
        <div class="loading-msg">Loading job cards...</div>
      {:else if filteredJobs.length === 0}
        <div class="empty-msg">No job cards found.</div>
      {:else}
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Job No</th>
              <th>Date</th>
              <th>Customer</th>
              <th>Vehicle</th>
              <th>Assigned To</th>
              <th>Priority</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {#each filteredJobs as jc, idx (jc.id)}
              <tr>
                <td>{idx + 1}</td>
                <td class="mono">{jc.job_card_no}</td>
                <td>{formatDate(jc.created_at)}</td>
                <td>{jc.customer_name}</td>
                <td>{jc.vehicle_name}</td>
                <td>{jc.assigned_name}</td>
                <td><span class="pri-badge {getPriorityClass(jc.priority)}">{jc.priority}</span></td>
                <td><span class="status-badge {getStatusClass(jc.status)}">{jc.status}</span></td>
                <td class="actions-cell">
                  <button class="action-btn view" on:click={() => viewJobCard(jc)} title="View">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                  </button>
                  {#if jc.status !== 'Closed' && jc.status !== 'Billed' && permEdit}
                    <button class="action-btn edit" on:click={() => editJobCard(jc)} title="Edit">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                    </button>
                  {/if}
                  {#if jc.status === 'Open' && permDelete}
                    <button class="action-btn delete" on:click={() => handleDelete(jc)} title="Delete">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                    </button>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

  {:else if viewMode === 'view' && selectedJC}
    <!-- ===== VIEW DETAILS ===== -->
    <div class="detail-view">
      <div class="detail-header">
        <button class="back-btn" on:click={goBackToList}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>Job Card: {selectedJC.job_card_no}</h2>
        <span class="status-badge {getStatusClass(selectedJC.status)}">{selectedJC.status}</span>
      </div>

      <div class="detail-body">
        <div class="detail-section">
          <div class="info-grid">
            <div class="info-item"><span class="info-label">Customer</span><span>{selectedJC.customer_name}</span></div>
            <div class="info-item"><span class="info-label">Vehicle</span><span>{selectedJC.vehicle_name}</span></div>
            <div class="info-item"><span class="info-label">Assigned To</span><span>{selectedJC.assigned_name}</span></div>
            <div class="info-item"><span class="info-label">Priority</span><span class="pri-badge {getPriorityClass(selectedJC.priority)}">{selectedJC.priority}</span></div>
            <div class="info-item"><span class="info-label">Created</span><span>{formatDateTime(selectedJC.created_at)}</span></div>
            {#if selectedJC.expected_date}<div class="info-item"><span class="info-label">Expected</span><span>{formatDate(selectedJC.expected_date)}</span></div>{/if}
          </div>
          {#if selectedJC.description}<div class="desc-block"><strong>Description:</strong> {selectedJC.description}</div>{/if}
          {#if selectedJC.details}<div class="desc-block"><strong>Notes:</strong> {selectedJC.details}</div>{/if}
        </div>

        <!-- Items -->
        <div class="detail-section">
          <h4>Items ({jcItems.length})</h4>
          {#if jcItems.length > 0}
            <table class="detail-table">
              <thead><tr><th>#</th><th>Type</th><th>Name</th><th class="num">Qty</th><th class="num">Price</th><th class="num">Discount</th><th class="num">Total</th><th>Notes</th></tr></thead>
              <tbody>
                {#each jcItems as it, idx}
                  <tr>
                    <td>{idx+1}</td>
                    <td><span class="type-tag" class:service={it.item_type === 'service'} class:consumable={it.item_type === 'consumable'}>{it.item_type}</span></td>
                    <td>{it.name}</td>
                    <td class="num">{it.qty}</td>
                    <td class="num">₹{(it.price || 0).toFixed(2)}</td>
                    <td class="num">₹{(it.discount || 0).toFixed(2)}</td>
                    <td class="num"><strong>₹{(it.total || 0).toFixed(2)}</strong></td>
                    <td>{it.notes || '—'}</td>
                  </tr>
                {/each}
              </tbody>
              <tfoot><tr><td colspan="6" class="num"><strong>Total</strong></td><td class="num"><strong>₹{jcItems.reduce((s: number, i: any) => s + (i.total || 0), 0).toFixed(2)}</strong></td><td></td></tr></tfoot>
            </table>
          {:else}
            <p class="empty-text">No items.</p>
          {/if}
        </div>

        <!-- Photos -->
        {#if jcPhotos.length > 0}
          <div class="detail-section">
            <h4>Photos ({jcPhotos.length})</h4>
            <div class="photo-grid">
              {#each jcPhotos as photo}
                <div class="photo-thumb">
                  <img src={photo.file_url} alt={photo.file_name || 'Photo'} />
                  <span class="photo-name">{photo.file_name || ''}</span>
                </div>
              {/each}
            </div>
          </div>
        {/if}

        <!-- Notes -->
        {#if jcNotes.length > 0}
          <div class="detail-section">
            <h4>Notes ({jcNotes.length})</h4>
            {#each jcNotes as note}
              <div class="note-card">
                <p>{note.note}</p>
                <span class="note-meta">{note.by_name} — {formatDateTime(note.created_at)}</span>
              </div>
            {/each}
          </div>
        {/if}

        <!-- Logs -->
        {#if jcLogs.length > 0}
          <div class="detail-section">
            <h4>Activity Log</h4>
            <div class="log-list">
              {#each jcLogs as log}
                <div class="log-entry">
                  <span class="log-action">{log.action}</span>
                  {#if log.from_status && log.to_status}
                    <span class="log-transition">{log.from_status} → {log.to_status}</span>
                  {/if}
                  {#if log.note}<span class="log-note">{log.note}</span>{/if}
                  <span class="log-meta">{log.by_name} — {formatDateTime(log.created_at)}</span>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </div>

  {:else if viewMode === 'edit' && selectedJC}
    <!-- ===== EDIT VIEW ===== -->
    <div class="detail-view">
      <div class="detail-header">
        <button class="back-btn" on:click={goBackToList}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <h2>Edit: {selectedJC.job_card_no}</h2>
      </div>

      <div class="detail-body">
        {#if editError}<div class="msg msg-error">{editError}</div>{/if}

        <div class="edit-form">
          <div class="form-grid">
            <div class="form-field">
              <label>Assigned To *</label>
              <select bind:value={editAssignedUserId}>
                <option value="">Select</option>
                {#each users as u}<option value={u.id}>{u.email}</option>{/each}
              </select>
            </div>
            <div class="form-field">
              <label>Priority</label>
              <select bind:value={editPriority}>
                <option value="Low">Low</option>
                <option value="Normal">Normal</option>
                <option value="High">High</option>
                <option value="Urgent">Urgent</option>
              </select>
            </div>
            <div class="form-field">
              <label>Expected Date</label>
              <input type="date" bind:value={editExpectedDate} />
            </div>
          </div>
          <div class="form-field">
            <label>Description *</label>
            <textarea bind:value={editDescription} rows="3"></textarea>
          </div>
          <div class="form-field">
            <label>Notes</label>
            <textarea bind:value={editDetails} rows="2"></textarea>
          </div>
          <div class="form-actions">
            <button class="btn-primary" on:click={handleEditSave} disabled={editSaving}>{editSaving ? 'Saving...' : 'Save Changes'}</button>
            <button class="btn-ghost" on:click={goBackToList}>Cancel</button>
          </div>
        </div>

        <!-- Items -->
        <div class="detail-section">
          <h4>Items ({jcItems.length})</h4>
          
          <!-- Add Item Form -->
          <div class="add-item-form">
            {#if itemError}<div class="form-error">{itemError}</div>{/if}

            <!-- Product Search -->
            <div class="form-row">
              <div class="form-field">
                <label>Product / Service *</label>
                <div class="search-box">
                  <input type="text" placeholder="Search product or service..." bind:value={productSearch} on:input={handleProductSearch} on:focus={handleProductSearch} />
                  {#if showProductDropdown}
                    <div class="dropdown">
                      {#each filteredProducts as p}
                        <button class="dd-item" on:click={() => selectProduct(p)}>
                          <strong>{p.product_name}</strong>
                          <span class="type-tag" class:service={p.product_type === 'service'} class:consumable={p.product_type === 'consumable'}>{p.product_type}</span>
                          <span>₹{(p.sales_price || 0).toFixed(2)}</span>
                        </button>
                      {/each}
                    </div>
                  {/if}
                </div>
                {#if selectedProduct}
                  <div class="selected-product">✓ {selectedProduct.product_name}</div>
                {/if}
              </div>
              <div class="form-field">
              <button class="btn-create-product" on:click={() => windowStore.open('products-create-product', 'Create Product/Services')} title="Create new product or service">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
                Create Product/Services
                </button>
              </div>
            </div>

            <!-- Item Details -->
            <div class="form-row">
              <div class="form-field">
                <label>Qty *</label>
                <input type="number" bind:value={itemQty} min="1" step="1" />
              </div>
              <div class="form-field">
                <label>Price *</label>
                <input type="number" bind:value={itemPrice} min="0" step="0.01" />
              </div>
              <div class="form-field">
                <label>Discount</label>
                <input type="number" bind:value={itemDiscount} min="0" step="0.01" />
              </div>
              <div class="form-field">
                <label>Notes</label>
                <input type="text" bind:value={itemNotes} placeholder="Notes..." />
              </div>
            </div>

            <button class="btn-add-item" on:click={addItemToJobCard} disabled={addingItem || !selectedProduct}>
              {addingItem ? 'Adding...' : '+ Add Item'}
            </button>
          </div>

          <!-- Items Table -->
          {#if jcItems.length > 0}
            <table class="detail-table">
              <thead><tr><th>#</th><th>Type</th><th>Name</th><th class="num">Qty</th><th class="num">Price</th><th class="num">Discount</th><th class="num">Total</th><th></th></tr></thead>
              <tbody>
                {#each jcItems as it, idx}
                  <tr>
                    <td>{idx+1}</td>
                    <td>{it.item_type}</td>
                    <td>{it.name}</td>
                    <td class="num">{it.qty}</td>
                    <td class="num">₹{(it.price||0).toFixed(2)}</td>
                    <td class="num">₹{(it.discount||0).toFixed(2)}</td>
                    <td class="num"><strong>₹{(it.total||0).toFixed(2)}</strong></td>
                    <td><button class="btn-remove" on:click={() => removeItemFromJobCard(it.id)} title="Remove">×</button></td>
                  </tr>
                {/each}
              </tbody>
              <tfoot><tr><td colspan="6" class="num"><strong>Total</strong></td><td class="num"><strong>₹{jcItems.reduce((s, i) => s + (i.total || 0), 0).toFixed(2)}</strong></td><td></td></tr></tfoot>
            </table>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .report-window { display: flex; flex-direction: column; height: 100%; background: #fafafa; }
  .perm-denied { display: flex; align-items: center; justify-content: center; height: 100%; color: #991b1b; font-size: 15px; font-weight: 500; }

  .report-header { display: flex; align-items: center; justify-content: space-between; padding: 12px 20px; background: white; border-bottom: 1px solid #e5e7eb; flex-shrink: 0; }
  .header-left { display: flex; align-items: center; gap: 10px; }
  .header-left h2 { font-size: 16px; font-weight: 700; color: #111827; }
  .header-actions { display: flex; gap: 8px; }
  .back-btn { background: none; border: none; cursor: pointer; color: #6b7280; padding: 4px; border-radius: 6px; display: flex; }
  .back-btn:hover { background: #f3f4f6; color: #111827; }

  .btn-create { display: inline-flex; align-items: center; gap: 4px; padding: 6px 14px; background: #C41E3A; color: white; border: none; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; }
  .btn-create:hover { background: #a71830; }
  .btn-refresh { display: inline-flex; align-items: center; gap: 4px; padding: 6px 14px; background: #f3f4f6; color: #374151; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; }
  .btn-refresh:hover { background: #e5e7eb; }

  /* Filters */
  .filters-bar { display: flex; flex-wrap: wrap; gap: 10px; padding: 10px 20px; background: white; border-bottom: 1px solid #f3f4f6; align-items: flex-end; }
  .filter-group { display: flex; flex-direction: column; gap: 3px; }
  .filter-group label { font-size: 11px; font-weight: 600; color: #6b7280; }
  .filter-group input, .filter-group select { padding: 6px 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; }
  .filter-group input:focus, .filter-group select:focus { border-color: #C41E3A; outline: none; }
  .search-group { flex: 1; min-width: 160px; }
  .search-group input { width: 100%; box-sizing: border-box; }
  .btn-clear { padding: 6px 12px; background: none; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; cursor: pointer; color: #6b7280; align-self: flex-end; }
  .btn-clear:hover { background: #f3f4f6; }

  /* Summary cards */
  .summary-cards { display: flex; gap: 10px; padding: 10px 20px; flex-wrap: wrap; }
  .s-card { background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 8px 16px; display: flex; flex-direction: column; align-items: center; min-width: 80px; }
  .s-label { font-size: 11px; color: #6b7280; }
  .s-val { font-size: 18px; font-weight: 700; color: #111827; }
  .s-card.open .s-val { color: #2563eb; }
  .s-card.progress .s-val { color: #d97706; }
  .s-card.closed .s-val { color: #16a34a; }
  .s-card.billed .s-val { color: #7c3aed; }

  /* Table */
  .table-wrap { flex: 1; overflow: auto; padding: 0 20px 20px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  thead { position: sticky; top: 0; z-index: 2; }
  th { background: #f9fafb; padding: 8px 10px; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb; white-space: nowrap; }
  td { padding: 8px 10px; border-bottom: 1px solid #f3f4f6; }
  .num { text-align: right; }
  .mono { font-family: 'SF Mono', 'Cascadia Code', monospace; font-size: 12px; color: #C41E3A; font-weight: 600; }
  .loading-msg, .empty-msg { text-align: center; color: #9ca3af; padding: 40px; font-size: 14px; }

  /* Status badges */
  .status-badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  .status-open { background: #dbeafe; color: #1d4ed8; }
  .status-progress { background: #fef3c7; color: #d97706; }
  .status-closed { background: #dcfce7; color: #16a34a; }
  .status-billed { background: #f3e8ff; color: #7c3aed; }
  .status-cancelled { background: #fee2e2; color: #dc2626; }

  /* Priority badges */
  .pri-badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
  .pri-low { background: #f3f4f6; color: #6b7280; }
  .pri-normal { background: #dbeafe; color: #1d4ed8; }
  .pri-high { background: #fef3c7; color: #d97706; }
  .pri-urgent { background: #fee2e2; color: #dc2626; }

  /* Action buttons */
  .actions-cell { display: flex; gap: 4px; }
  .action-btn { width: 28px; height: 28px; border: none; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
  .action-btn.view { background: #dbeafe; color: #1d4ed8; }
  .action-btn.edit { background: #fef3c7; color: #d97706; }
  .action-btn.delete { background: #fee2e2; color: #dc2626; }
  .action-btn:hover { opacity: 0.8; }

  /* Detail view */
  .detail-view { display: flex; flex-direction: column; height: 100%; }
  .detail-header { display: flex; align-items: center; gap: 10px; padding: 12px 20px; background: white; border-bottom: 1px solid #e5e7eb; flex-shrink: 0; }
  .detail-header h2 { font-size: 16px; font-weight: 700; }
  .detail-body { flex: 1; overflow-y: auto; padding: 16px 20px; }
  .detail-section { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 16px; margin-bottom: 12px; }
  .detail-section h4 { font-size: 14px; font-weight: 700; margin-bottom: 10px; color: #111827; }

  .info-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 10px; margin-bottom: 12px; }
  .info-item { display: flex; flex-direction: column; gap: 2px; }
  .info-label { font-size: 11px; font-weight: 600; color: #6b7280; }
  .info-item span:last-child { font-size: 14px; color: #111827; }
  .desc-block { font-size: 13px; color: #374151; margin-bottom: 6px; line-height: 1.5; }

  .detail-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .detail-table th { background: #f9fafb; padding: 6px 10px; text-align: left; font-weight: 600; border-bottom: 2px solid #e5e7eb; }
  .detail-table td { padding: 6px 10px; border-bottom: 1px solid #f3f4f6; }
  .detail-table tfoot td { border-top: 2px solid #e5e7eb; background: #f9fafb; }

  .type-tag { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; background: #dbeafe; color: #1d4ed8; text-transform: capitalize; }
  .type-tag.service { background: #f3e8ff; color: #7c3aed; }
  .type-tag.consumable { background: #dcfce7; color: #16a34a; }

  /* Add item form */
  .add-item-form { background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 8px; padding: 12px; margin-bottom: 12px; }
  .form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-bottom: 10px; }
  .form-field { display: flex; flex-direction: column; gap: 4px; }
  .form-field label { font-size: 12px; font-weight: 600; color: #374151; }
  .form-field input { padding: 6px 8px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; outline: none; }
  .form-field input:focus { border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1); }
  .search-box { position: relative; }
  .search-box input { width: 100%; }
  .dropdown { position: absolute; top: 100%; left: 0; right: 0; background: white; border: 1px solid #d1d5db; border-radius: 6px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); max-height: 200px; overflow-y: auto; z-index: 10; }
  .dd-item { display: block; width: 100%; padding: 8px 10px; text-align: left; border: none; background: none; cursor: pointer; font-size: 12px; display: flex; justify-content: space-between; align-items: center; }
  .dd-item:hover { background: #f3f4f6; }
  .dd-item strong { font-weight: 600; }
  .dd-item span { font-size: 11px; color: #6b7280; }
  .selected-product { margin-top: 4px; padding: 6px 8px; background: #dbeafe; color: #1d4ed8; border-radius: 4px; font-size: 12px; font-weight: 600; }
  .btn-add-item { padding: 8px 16px; background: #2563eb; color: white; border: none; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; }
  .btn-add-item:hover:not(:disabled) { background: #1d4ed8; }
  .btn-add-item:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-remove { background: none; border: none; color: #dc2626; font-size: 18px; cursor: pointer; padding: 0 4px; line-height: 1; }
  .btn-remove:hover { color: #991b1b; }
  .form-error { color: #dc2626; font-size: 12px; padding: 8px; background: #fee2e2; border-radius: 4px; margin-bottom: 8px; }
  .btn-create-product { display: inline-flex; align-items: center; gap: 6px; padding: 8px 14px; background: #C41E3A; color: white; border: none; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; margin-top: 24px; }
  .btn-create-product:hover { background: #a71830; }
  .btn-ghost { padding: 8px 16px; background: none; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer; color: #374151; }
  .btn-ghost:hover { background: #f3f4f6; }

  /* Photo grid */
  .photo-grid { display: flex; gap: 10px; flex-wrap: wrap; }
  .photo-thumb { width: 100px; height: 100px; border-radius: 8px; overflow: hidden; border: 1px solid #e5e7eb; position: relative; }
  .photo-thumb img { width: 100%; height: 100%; object-fit: cover; }
  .photo-name { position: absolute; bottom: 0; left: 0; right: 0; background: rgba(0,0,0,0.6); color: white; font-size: 10px; padding: 2px 4px; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; }

  /* Notes */
  .note-card { background: #f9fafb; border-radius: 8px; padding: 10px 14px; margin-bottom: 8px; }
  .note-card p { font-size: 13px; color: #111827; margin: 0 0 4px; }
  .note-meta { font-size: 11px; color: #9ca3af; }

  /* Logs */
  .log-list { display: flex; flex-direction: column; gap: 6px; }
  .log-entry { display: flex; align-items: center; gap: 8px; font-size: 12px; padding: 6px 0; border-bottom: 1px solid #f3f4f6; flex-wrap: wrap; }
  .log-action { font-weight: 600; color: #111827; }
  .log-transition { color: #6b7280; }
  .log-note { color: #374151; }
  .log-meta { color: #9ca3af; font-size: 11px; margin-left: auto; }
  .empty-text { color: #9ca3af; font-size: 13px; }

  /* Edit form */
  .edit-form { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 16px; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; margin-bottom: 12px; }
  .form-field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 8px; }
  .form-field label { font-size: 12px; font-weight: 600; color: #374151; }
  .form-field input, .form-field select, .form-field textarea { padding: 8px 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 13px; outline: none; box-sizing: border-box; }
  .form-field input:focus, .form-field select:focus, .form-field textarea:focus { border-color: #C41E3A; box-shadow: 0 0 0 3px rgba(196, 30, 58, 0.1); }
  .form-field textarea { resize: vertical; font-family: inherit; }

  .btn-primary { display: inline-flex; align-items: center; gap: 6px; padding: 8px 20px; background: #C41E3A; color: white; border: none; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; }
  .btn-primary:hover:not(:disabled) { background: #a71830; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-ghost { display: inline-flex; align-items: center; gap: 4px; padding: 8px 16px; background: none; border: none; color: #6b7280; font-size: 13px; font-weight: 500; cursor: pointer; }
  .btn-ghost:hover { color: #111827; }

  .msg { padding: 10px 16px; border-radius: 8px; font-size: 13px; margin-bottom: 12px; }
  .msg-error { background: #fef2f2; color: #dc2626; border: 1px solid #fca5a5; }
</style>
