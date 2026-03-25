<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { authStore } from '../../stores/authStore';
  import { supabase } from '../../lib/supabaseClient';
  import { setMobilePage } from '../../stores/mobilePageStore';

  const dispatch = createEventDispatcher();

  let mobileJobs: any[] = [];
  let mobileViewingJob: any = null;
  let mjLoading = false;
  let mjLoadingDetail = false;
  
  // Edit state
  let mjEditingJob: any = null;
  let mjEditCustomerId = '';
  let mjEditVehicleId = '';
  let mjEditPriority = 'Normal';
  let mjEditError = '';
  let mjEditSaving = false;
  let mjCustomers: any[] = [];
  let mjVehicles: any[] = [];

  // Product management
  let mjProducts: any[] = [];
  let mjProductSearch = '';
  let mjItems: any[] = [];
  let mjSelectedProduct: any = null;
  let mjItemQty = 1;
  let mjItemPrice: any = null;
  let mjNewNote = '';
  let mjUploadingPhotos = false;
  let mjDeletingItemId: string | null = null;

  async function loadMobileJobs() {
    mjLoading = true;
    const { data, error } = await supabase
      .from('job_cards')
      .select('id, job_card_no, customer_id, vehicle_id, status, created_at, created_by, customers(name), vehicles(model_name)')
      .eq('created_by', $authStore.user?.id)
      .in('status', ['Open', 'In Progress'])
      .order('created_at', { ascending: false });

    if (!error && data) {
      mobileJobs = data;
    }
    mjLoading = false;
  }

  async function loadMobileProducts() {
    const { data, error } = await supabase
      .from('products')
      .select('id, product_name, sales_price')
      .order('product_name', { ascending: true });

    if (!error && data) {
      mjProducts = data;
    }
  }

  async function loadCustomers() {
    const { data, error } = await supabase
      .from('customers')
      .select('id, name')
      .order('name', { ascending: true });

    if (!error && data) {
      mjCustomers = data;
    }
  }

  async function loadVehicles() {
    const { data, error } = await supabase
      .from('vehicles')
      .select('id, model_name')
      .order('model_name', { ascending: true });

    if (!error && data) {
      mjVehicles = data;
    }
  }

  function handleMobileProductSearch() {
    // Filter products based on search query
    // No need to do anything - filtering happens in template via computed value
  }

  function selectMobileProduct(product: any) {
    mjSelectedProduct = product;
    mjItemPrice = product.sales_price;
    mjProductSearch = ''; // Clear search after selection
  }

  // Computed filtered products
  $: mjFilteredProducts = mjProductSearch.trim() === '' 
    ? [] 
    : mjProducts.filter(p => 
        p.product_name.toLowerCase().includes(mjProductSearch.toLowerCase())
      );

  async function openMobileJobDetail(job: any) {
    mjLoadingDetail = true;
    mobileViewingJob = job;
    
    // Load job items
    const { data: items, error: itemsError } = await supabase
      .from('job_card_items')
      .select('id, product_id, qty, price, total, item_type, notes, products(product_name, sales_price)')
      .eq('job_card_id', job.id)
      .order('created_at', { ascending: false });

    if (!itemsError && items) {
      mjItems = items;
    }

    // Load notes
    const { data: notes } = await supabase
      .from('job_card_notes')
      .select('*')
      .eq('job_card_id', job.id)
      .order('created_at', { ascending: false });

    mjLoadingDetail = false;
  }

  function closeMobileJobDetail() {
    mobileViewingJob = null;
    mjItems = [];
    mjNewNote = '';
  }

  async function mjStartJob() {
    if (!mobileViewingJob || mobileViewingJob.status !== 'Open') return;

    const { error } = await supabase
      .from('job_cards')
      .update({ 
        status: 'In Progress', 
        updated_by: $authStore.user?.id || null, 
        updated_at: new Date().toISOString() 
      })
      .eq('id', mobileViewingJob.id);

    if (!error) {
      await supabase.from('job_card_logs').insert({ 
        job_card_id: mobileViewingJob.id, 
        action: 'Started', 
        from_status: 'Open', 
        to_status: 'In Progress', 
        note: 'Job started', 
        action_by: $authStore.user?.id || null, 
        created_by: $authStore.user?.id || null 
      });
      mobileViewingJob = { ...mobileViewingJob, status: 'In Progress' };
      await openMobileJobDetail(mobileViewingJob);
    }
  }

  async function mjCloseJob() {
    if (!mobileViewingJob || mobileViewingJob.status !== 'In Progress') return;

    const { error } = await supabase
      .from('job_cards')
      .update({ 
        status: 'Closed', 
        closed_by: $authStore.user?.id || null, 
        closed_at: new Date().toISOString(), 
        updated_by: $authStore.user?.id || null, 
        updated_at: new Date().toISOString() 
      })
      .eq('id', mobileViewingJob.id);

    if (!error) {
      await supabase.from('job_card_logs').insert({ 
        job_card_id: mobileViewingJob.id, 
        action: 'Closed', 
        from_status: 'In Progress', 
        to_status: 'Closed', 
        note: 'Job completed and closed', 
        action_by: $authStore.user?.id || null, 
        created_by: $authStore.user?.id || null 
      });
      mobileViewingJob = { ...mobileViewingJob, status: 'Closed' };
      await openMobileJobDetail(mobileViewingJob);
    }
  }

  async function mjAddNote() {
    if (!mjNewNote.trim() || !mobileViewingJob) return;

    await supabase.from('job_card_notes').insert({ 
      job_card_id: mobileViewingJob.id, 
      note: mjNewNote.trim(), 
      created_by: $authStore.user?.id || null 
    });

    await supabase.from('job_card_logs').insert({ 
      job_card_id: mobileViewingJob.id, 
      action: 'Note Added', 
      note: mjNewNote.trim().substring(0, 100), 
      action_by: $authStore.user?.id || null, 
      created_by: $authStore.user?.id || null 
    });

    mjNewNote = '';
    await openMobileJobDetail(mobileViewingJob);
  }

  async function mjAddItem() {
    if (!mobileViewingJob || !mjSelectedProduct || mjItemQty <= 0 || !mjItemPrice) {
      alert('Please fill all fields');
      return;
    }

    const itemTotal = mjItemQty * mjItemPrice;

    const { error } = await supabase.from('job_card_items').insert({
      job_card_id: mobileViewingJob.id,
      product_id: mjSelectedProduct.id,
      qty: mjItemQty,
      price: mjItemPrice,
      total: itemTotal,
      item_type: 'product',
      created_by: $authStore.user?.id || null,
      updated_by: $authStore.user?.id || null
    });

    if (!error) {
      mjSelectedProduct = null;
      mjItemQty = 1;
      mjItemPrice = null;
      await openMobileJobDetail(mobileViewingJob);
    } else {
      alert('Error adding item: ' + error.message);
    }
  }

  async function mjRemoveItem(itemId: string) {
    if (!confirm('Remove this item?')) return;

    mjDeletingItemId = itemId;
    await supabase.from('job_card_items').delete().eq('id', itemId);
    mjDeletingItemId = null;
    await openMobileJobDetail(mobileViewingJob);
  }

  onMount(() => {
    loadMobileJobs();
    loadMobileProducts();
    loadCustomers();
    loadVehicles();
  });

  function goToCreateJobCard() {
    setMobilePage('job-creation', 'Create Job Card');
  }

  function openEditJobCard(job: any) {
    mjEditingJob = { ...job };
    mjEditCustomerId = job.customer_id;
    mjEditVehicleId = job.vehicle_id;
    mjEditPriority = job.priority || 'Normal';
    mjEditError = '';
  }

  function closeEditJobCard() {
    mjEditingJob = null;
    mjEditError = '';
  }

  async function saveJobCardEdit() {
    if (!mjEditCustomerId.trim()) {
      mjEditError = 'Customer is required';
      return;
    }
    if (!mjEditVehicleId.trim()) {
      mjEditError = 'Vehicle is required';
      return;
    }

    mjEditSaving = true;
    mjEditError = '';

    const updateData: any = {
      customer_id: mjEditCustomerId,
      vehicle_id: mjEditVehicleId,
      priority: mjEditPriority,
      updated_by: $authStore.user?.id || null,
      updated_at: new Date().toISOString()
    };

    const { error } = await supabase
      .from('job_cards')
      .update(updateData)
      .eq('id', mjEditingJob.id);

    mjEditSaving = false;

    if (error) {
      mjEditError = error.message;
      return;
    }

    // Reload jobs and close edit
    await loadMobileJobs();
    closeEditJobCard();
  }
</script>

{#if mobileViewingJob}
  <!-- Job Detail View -->
  <div class="mobileJobDetail">
    <div class="mjd-header">
      <button class="mjd-back-btn" on:click={closeMobileJobDetail}>←</button>
      <div>
        <h3>{mobileViewingJob.job_card_no}</h3>
        <p>{mobileViewingJob.customers?.name}</p>
      </div>
      <span class="mjd-status" class:open={mobileViewingJob.status === 'Open'} class:inprogress={mobileViewingJob.status === 'In Progress'} class:closed={mobileViewingJob.status === 'Closed'}>
        {mobileViewingJob.status}
      </span>
    </div>

    <!-- Items Section -->
    {#if mjItems.length > 0}
      <div class="mj-items-section">
        <h4>Items</h4>
        <div class="mj-items-list">
          {#each mjItems as item (item.id)}
            <div class="mj-item-row">
              <div class="mj-item-info">
                <span class="mj-item-name">{item.products?.product_name}</span>
                <span class="mj-item-qty">{item.qty} × ${item.price?.toFixed(2) || '0.00'}</span>
              </div>
              <div class="mj-item-total">${item.total?.toFixed(2) || '0.00'}</div>
              {#if mobileViewingJob.status !== 'Closed'}
                <button class="mj-item-delete" on:click={() => mjRemoveItem(item.id)} disabled={mjDeletingItemId === item.id}>
                  ✕
                </button>
              {/if}
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Add Item Form -->
    {#if mobileViewingJob.status !== 'Closed'}
      <div class="mj-add-item-form">
        <h4>Add Product & Services</h4>
        <input type="text" placeholder="Search product..." bind:value={mjProductSearch} on:input={handleMobileProductSearch} />
        
        <!-- Product Dropdown List -->
        {#if mjProductSearch.trim() && mjFilteredProducts.length > 0}
          <div class="mj-product-list">
            {#each mjFilteredProducts as product (product.id)}
              <button class="mj-product-item" on:click={() => selectMobileProduct(product)}>
                <div class="product-name">{product.product_name}</div>
                <div class="product-price">${product.sales_price.toFixed(2)}</div>
              </button>
            {/each}
          </div>
        {/if}

        {#if mjSelectedProduct}
          <div class="mj-selected-product">
            <strong>{mjSelectedProduct.product_name}</strong> - ${mjSelectedProduct.sales_price.toFixed(2)}
          </div>
        {/if}

        <input type="number" placeholder="Qty" bind:value={mjItemQty} min="1" />
        <input type="number" placeholder="Price" bind:value={mjItemPrice} min="0" step="0.01" />
        <button on:click={mjAddItem} class="mj-add-btn">Add Item</button>
      </div>
    {/if}

    <!-- Notes Section -->
    <div class="mj-notes-section">
      <h4>Notes</h4>
      {#if mobileViewingJob.status !== 'Closed'}
        <div class="mj-note-input">
          <textarea placeholder="Add a note..." bind:value={mjNewNote}></textarea>
          <button on:click={mjAddNote} class="mj-note-btn">Add Note</button>
        </div>
      {/if}
    </div>

    <!-- Action Buttons -->
    <div class="mj-actions">
      {#if mobileViewingJob.status === 'Open'}
        <button on:click={mjStartJob} class="mj-action-btn start">Start Job</button>
      {:else if mobileViewingJob.status === 'In Progress'}
        <button on:click={mjCloseJob} class="mj-action-btn close">Close Job</button>
      {/if}
    </div>
  </div>
{:else}
  <!-- Job List View -->
  <div class="mj-list">
    <div class="mj-header-actions">
      <button class="btn-create" on:click={goToCreateJobCard}>
        ➕ Create Job Card
      </button>
    </div>
    {#if mjLoading}
      <p>Loading jobs...</p>
    {:else if mobileJobs.length === 0}
      <p class="no-jobs">No jobs assigned</p>
    {:else}
      {#each mobileJobs as job (job.id)}
        <div class="mj-job-card">
          <button class="mj-job-main-btn" on:click={() => openMobileJobDetail(job)}>
            <div class="mj-job-header">
              <span class="mj-job-ref">{job.job_card_no}</span>
              <span class="mj-job-status" class:open={job.status === 'Open'} class:inprogress={job.status === 'In Progress'} class:closed={job.status === 'Closed'}>
                {job.status}
              </span>
            </div>
            <div class="mj-job-customer">{job.customers?.name}</div>
            <div class="mj-job-vehicle">{job.vehicles?.model_name}</div>
          </button>
          <button class="mj-job-edit-btn" on:click={() => openEditJobCard(job)} title="Edit Job Card">
            ✎
          </button>
        </div>
      {/each}
    {/if}
  </div>
{/if}

<!-- Edit Job Card Modal -->
{#if mjEditingJob}
  <div class="mj-edit-modal" on:click={closeEditJobCard}>
    <div class="mj-edit-panel" on:click={(e) => e.stopPropagation()}>
      <div class="mj-edit-header">
        <h3>Edit Job Card</h3>
        <button class="mj-edit-close-btn" on:click={closeEditJobCard}>✕</button>
      </div>
      <div class="mj-edit-content">
        {#if mjEditError}
          <div class="mj-edit-error">{mjEditError}</div>
        {/if}
        
        <div class="mj-edit-field">
          <label for="edit-customer">Customer</label>
          <select id="edit-customer" bind:value={mjEditCustomerId} disabled={mjEditSaving}>
            <option value="">Select Customer</option>
            {#each mjCustomers as customer (customer.id)}
              <option value={customer.id}>{customer.name}</option>
            {/each}
          </select>
        </div>

        <div class="mj-edit-field">
          <label for="edit-vehicle">Vehicle</label>
          <select id="edit-vehicle" bind:value={mjEditVehicleId} disabled={mjEditSaving}>
            <option value="">Select Vehicle</option>
            {#each mjVehicles as vehicle (vehicle.id)}
              <option value={vehicle.id}>{vehicle.model_name} ({vehicle.registration_number})</option>
            {/each}
          </select>
        </div>

        <div class="mj-edit-field">
          <label for="edit-priority">Priority</label>
          <select id="edit-priority" bind:value={mjEditPriority} disabled={mjEditSaving}>
            <option value="Low">Low</option>
            <option value="Normal">Normal</option>
            <option value="High">High</option>
            <option value="Urgent">Urgent</option>
          </select>
        </div>

        <div class="mj-edit-actions">
          <button class="save" on:click={saveJobCardEdit} disabled={mjEditSaving}>
            {mjEditSaving ? 'Saving...' : 'Save Changes'}
          </button>
          <button class="cancel" on:click={closeEditJobCard} disabled={mjEditSaving}>
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .mj-list {
    padding: 1rem;
  }

  .mj-header-actions {
    margin-bottom: 1.5rem;
  }

  .btn-create {
    width: 100%;
    padding: 0.75rem 1rem;
    background: var(--brand-primary);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .btn-create:active {
    background: var(--brand-secondary);
    transform: translateY(2px);
  }

  .mj-job-card-wrapper {
    display: flex;
    gap: 0.75rem;
    align-items: stretch;
    margin-bottom: 1rem;
  }

  .mj-job-card {
    position: relative;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    margin-bottom: 1rem;
    padding: 1rem;
    overflow: visible;
  }

  .mj-job-main-btn {
    display: block;
    width: 100%;
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    text-align: left;
    transition: all 0.2s;
  }

  .mj-job-main-btn:active {
    background: #f3f4f6;
  }

  .mj-job-edit-btn {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    padding: 0.6rem 0.8rem;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.2s;
    z-index: 20;
    min-height: 44px;
    min-width: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
  }

  .mj-job-edit-btn:active {
    background: #1d4ed8;
    transform: scale(0.95);
  }

  .mj-job-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  .mj-job-ref {
    font-weight: 600;
    color: #1f2937;
  }

  .mj-job-status {
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
  }

  .mj-job-status.open {
    background: #dbeafe;
    color: #1e40af;
  }

  .mj-job-status.inprogress {
    background: #fef3c7;
    color: #b45309;
  }

  .mj-job-status.closed {
    background: #d1fae5;
    color: #065f46;
  }

  .mj-job-customer {
    font-size: 0.9rem;
    color: #4b5563;
    margin-bottom: 0.25rem;
  }

  .mj-job-vehicle {
    font-size: 0.85rem;
    color: #9ca3af;
  }

  .no-jobs {
    text-align: center;
    color: #9ca3af;
    padding: 2rem 1rem;
  }

  .mobileJobDetail {
    padding: 1rem;
  }

  .mjd-header {
    display: flex;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1.5rem;
    padding: 1rem;
    background: white;
    border-radius: 8px;
  }

  .mjd-back-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    min-width: 48px;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mjd-status {
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
  }

  .mjd-status.closed {
    background: #d1fae5;
    color: #065f46;
  }

  .mj-items-section {
    margin-bottom: 1.5rem;
  }

  .mj-items-list {
    background: white;
    border-radius: 8px;
    overflow: hidden;
  }

  .mj-item-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1rem;
    border-bottom: 1px solid #e5e7eb;
    min-height: 60px;
  }

  .mj-item-info {
    flex: 1;
    min-width: 0;
  }

  .mj-item-name {
    display: block;
    font-weight: 600;
    color: #111827;
    word-break: break-word;
    line-height: 1.3;
    margin-bottom: 0.25rem;
  }

  .mj-item-qty {
    display: block;
    font-size: 0.9rem;
    color: #6b7280;
    font-weight: 500;
  }

  .mj-item-total {
    font-weight: 700;
    min-width: 70px;
    text-align: right;
    color: #059669;
    font-size: 1rem;
  }

  .mj-item-delete {
    background: #fee2e2;
    border: none;
    color: #C41E3A;
    width: 48px;
    height: 48px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1.2rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mj-add-item-form {
    background: white;
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    position: relative;
  }

  .mj-add-item-form h4 {
    margin: 0 0 1rem 0;
    font-size: 1rem;
    color: #111827;
  }

  .mj-add-item-form input {
    width: 100%;
    padding: 0.75rem;
    margin-bottom: 0.75rem;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    min-height: 48px;
    font-size: 1rem;
    box-sizing: border-box;
    -webkit-appearance: none;
    appearance: none;
  }

  .mj-add-item-form input[type="number"] {
    font-size: 1rem;
  }

  .mj-product-list {
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    max-height: 250px;
    overflow-y: auto;
    margin-bottom: 0.5rem;
    z-index: 10;
    -webkit-overflow-scrolling: touch;
  }

  .mj-product-item {
    width: 100%;
    padding: 0.75rem;
    border: none;
    border-bottom: 1px solid #e5e7eb;
    background: white;
    text-align: left;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    font-size: 0.95rem;
    transition: all 0.15s;
    min-height: 56px;
    justify-content: center;
  }

  .mj-product-item:last-child {
    border-bottom: none;
  }

  .mj-product-item:active {
    background: #f0fdf4;
    border-left: 4px solid var(--brand-primary);
  }

  .product-name {
    font-weight: 500;
    color: #111827;
    flex: 1;
    word-break: break-word;
    line-height: 1.3;
  }

  .product-price {
    color: #059669;
    font-weight: 600;
    white-space: nowrap;
    font-size: 0.85rem;
  }

  .mj-selected-product {
    padding: 0.5rem;
    background: #f0fdf4;
    color: #166534;
    border-radius: 4px;
    margin-bottom: 0.5rem;
    font-size: 0.9rem;
  }

  .mj-add-btn {
    width: 100%;
    padding: 0.5rem;
    background: var(--brand-primary);
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    min-height: 48px;
    font-size: 1rem;
    font-weight: 600;
  }

  .mj-notes-section {
    margin-bottom: 1.5rem;
  }

  .mj-note-input {
    background: white;
    padding: 1rem;
    border-radius: 8px;
  }

  .mj-note-input textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    font-family: inherit;
    resize: vertical;
    min-height: 80px;
    font-size: 1rem;
  }

  .mj-note-btn {
    width: 100%;
    margin-top: 0.5rem;
    padding: 0.5rem;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    min-height: 48px;
    font-size: 1rem;
    font-weight: 600;
  }

  .mj-actions {
    display: flex;
    gap: 1rem;
  }

  .mj-action-btn {
    flex: 1;
    padding: 0.75rem;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
    font-size: 1rem;
    color: white;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mj-action-btn.start {
    background: #10b981;
  }

  .mj-action-btn.close {
    background: #ef4444;
  }

  .mj-edit-modal {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    z-index: 1000;
    animation: slideUp 0.3s ease-out;
  }

  @keyframes slideUp {
    from {
      transform: translateY(100%);
    }
    to {
      transform: translateY(0);
    }
  }

  .mj-edit-panel {
    background: white;
    border-radius: 12px 12px 0 0;
    max-height: 80vh;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    animation: slideUp 0.3s ease-out;
  }

  .mj-edit-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #e5e7eb;
    position: sticky;
    top: 0;
    background: white;
    border-radius: 12px 12px 0 0;
  }

  .mj-edit-header h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #111827;
  }

  .mj-edit-close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    min-width: 48px;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mj-edit-content {
    padding: 1rem;
  }

  .mj-edit-field {
    margin-bottom: 1rem;
  }

  .mj-edit-field label {
    display: block;
    font-size: 0.85rem;
    font-weight: 600;
    color: #4b5563;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .mj-edit-field select {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    font-size: 1rem;
    box-sizing: border-box;
    min-height: 48px;
    -webkit-appearance: none;
    appearance: none;
    background-image: url("data:image/svg+xml;charset=UTF-8,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3e%3cpolyline points='6 9 12 15 18 9'%3e%3c/polyline%3e%3c/svg%3e");
    background-repeat: no-repeat;
    background-position: right 0.75rem center;
    background-size: 1.2em;
    padding-right: 2.5rem;
  }

  .mj-edit-actions {
    display: flex;
    gap: 1rem;
    margin-top: 1.5rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
  }

  .mj-edit-actions button {
    flex: 1;
    padding: 0.75rem;
    border: none;
    border-radius: 4px;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mj-edit-actions button.save {
    background: #10b981;
    color: white;
  }

  .mj-edit-actions button.cancel {
    background: #e5e7eb;
    color: #4b5563;
  }

  .mj-edit-error {
    background: #fee2e2;
    color: #C41E3A;
    padding: 0.75rem;
    border-radius: 4px;
    margin-bottom: 1rem;
    font-size: 0.9rem;
  }
</style>
