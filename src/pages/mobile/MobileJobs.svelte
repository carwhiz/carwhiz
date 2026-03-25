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

  function handleMobileProductSearch() {
    // Search logic - implementation needed
  }

  function selectMobileProduct(product: any) {
    mjSelectedProduct = product;
    mjItemPrice = product.sales_price;
  }

  async function openMobileJobDetail(job: any) {
    mjLoadingDetail = true;
    mobileViewingJob = job;
    
    // Load job items
    const { data: items, error: itemsError } = await supabase
      .from('job_card_items')
      .select('id, item_id, qty, price, total, item_type, notes, products(product_name)')
      .eq('job_card_id', job.id);

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

    await supabase.from('job_card_items').insert({
      job_card_id: mobileViewingJob.id,
      product_id: mjSelectedProduct.id,
      quantity: mjItemQty,
      price: mjItemPrice,
      total: itemTotal,
      created_by: $authStore.user?.id || null
    });

    mjSelectedProduct = null;
    mjItemQty = 1;
    mjItemPrice = null;
    await openMobileJobDetail(mobileViewingJob);
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
  });

  function goToCreateJobCard() {
    setMobilePage('job-creation', 'Create Job Card');
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
                <span class="mj-item-name">{item.products?.name}</span>
                <span class="mj-item-qty">{item.quantity} × ${item.price.toFixed(2)}</span>
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
        <h4>Add Product</h4>
        <input type="text" placeholder="Search product..." bind:value={mjProductSearch} on:input={handleMobileProductSearch} />
        
        {#if mjSelectedProduct}
          <div class="mj-selected-product">
            {mjSelectedProduct.product_name} - ${mjSelectedProduct.sales_price}
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
        <button class="mj-job-card" on:click={() => openMobileJobDetail(job)}>
          <div class="mj-job-header">
            <span class="mj-job-ref">{job.job_card_no}</span>
            <span class="mj-job-status" class:open={job.status === 'Open'} class:inprogress={job.status === 'In Progress'} class:closed={job.status === 'Closed'}>
              {job.status}
            </span>
          </div>
          <div class="mj-job-customer">{job.customers?.name}</div>
          <div class="mj-job-vehicle">{job.vehicles?.model_name}</div>
        </button>
      {/each}
    {/if}
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

  .mj-job-card {
    display: block;
    width: 100%;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 1rem;
    margin-bottom: 1rem;
    cursor: pointer;
    text-align: left;
    transition: all 0.2s;
  }

  .mj-job-card:active {
    background: #f3f4f6;
    border-color: var(--brand-primary);
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
    gap: 0.5rem;
    padding: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .mj-item-info {
    flex: 1;
  }

  .mj-item-name {
    display: block;
    font-weight: 500;
  }

  .mj-item-qty {
    display: block;
    font-size: 0.85rem;
    color: #6b7280;
  }

  .mj-item-total {
    font-weight: 600;
    min-width: 60px;
    text-align: right;
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
  }

  .mj-add-item-form input {
    width: 100%;
    padding: 0.5rem;
    margin-bottom: 0.5rem;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    min-height: 48px;
    font-size: 1rem;
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
</style>
