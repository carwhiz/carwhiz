<!-- ============================================================
     MOBILE > JOB CARD DETAIL MANAGEMENT PAGE
     Purpose: Full-page job card editor with products, photos, notes
     Replaces the modal popup with full-page navigation
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../lib/supabaseClient';
  import { authStore } from '../../stores/authStore';
  import { setMobilePage, mobilePageStore } from '../../stores/mobilePageStore';
  import MobilePageWrapper from '../../components/shared/MobilePageWrapper.svelte';

  let jobId = '';
  let mobilePageValue: any;

  interface JobDetail {
    id: string;
    job_card_no: string;
    customer_name: string;
    customer_place?: string;
    customer_gender?: string;
    customer_phones?: string[];
    vehicle_model: string;
    vehicle_make?: string;
    vehicle_number?: string;
    vehicle_generation?: string;
    vehicle_type?: string;
    vehicle_variant?: string;
    vehicle_gearbox?: string;
    vehicle_fuel?: string;
    vehicle_body?: string;
    status: string;
    priority: string;
    created_at: string;
    description: string;
    details?: string;
    expected_date?: string;
  }

  // Job data
  let job: JobDetail | null = null;
  let loading = true;
  let error: string | null = null;

  // Items management
  let items: any[] = [];
  let products: any[] = [];
  let filteredProducts: any[] = [];
  let productSearch = '';
  let showProductDropdown = false;
  let selectedProduct: any = null;
  let itemQty = 1;
  let itemPrice: number | null = null;
  let itemNotes = '';
  let itemError = '';
  let itemSaving = false;
  let deletingItemId: string | null = null;

  // Photos
  let photos: any[] = [];
  let photoUploading = false;
  let photoError = '';

  // Notes
  let notes: any[] = [];
  let newNote = '';
  let isAddingNote = false;
  let noteError = '';

  // Actions
  let actionLoading = false;
  let actionError = '';

  async function loadJobDetail() {
    loading = true;
    error = null;

    try {
      const { data: jobData, error: jobError } = await supabase
        .from('job_cards')
        .select(`
          id,
          job_card_no,
          status,
          priority,
          created_at,
          description,
          details,
          expected_date,
          customer_id,
          vehicle_id,
          vehicle_number,
          customers(name, place, gender),
          vehicles(model_name, makes(name), generations(name), generation_types(name), variants(name), gearboxes(name), fuel_types(name), body_sides(name))
        `)
        .eq('id', jobId)
        .maybeSingle();

      if (jobError || !jobData) {
        error = 'Failed to load job card';
        return;
      }

      // Fetch customer phones
      let customerPhones: string[] = [];
      if (jobData.customer_id) {
        const { data: phonesData } = await supabase
          .from('customer_phones')
          .select('phone')
          .eq('customer_id', jobData.customer_id);
        customerPhones = (phonesData || []).map(p => p.phone);
      }

      job = {
        id: jobData.id,
        job_card_no: jobData.job_card_no,
        customer_name: jobData.customers?.name || 'N/A',
        customer_place: jobData.customers?.place || 'N/A',
        customer_gender: jobData.customers?.gender || 'N/A',
        customer_phones: customerPhones,
        vehicle_model: jobData.vehicles?.model_name || 'N/A',
        vehicle_make: jobData.vehicles?.makes?.name || 'N/A',
        vehicle_number: jobData.vehicle_number || 'N/A',
        vehicle_generation: jobData.vehicles?.generations?.name || 'N/A',
        vehicle_type: jobData.vehicles?.generation_types?.name || 'N/A',
        vehicle_variant: jobData.vehicles?.variants?.name || 'N/A',
        vehicle_gearbox: jobData.vehicles?.gearboxes?.name || 'N/A',
        vehicle_fuel: jobData.vehicles?.fuel_types?.name || 'N/A',
        vehicle_body: jobData.vehicles?.body_sides?.name || 'N/A',
        status: jobData.status,
        priority: jobData.priority,
        created_at: jobData.created_at,
        description: jobData.description,
        details: jobData.details,
        expected_date: jobData.expected_date
      };

      await Promise.all([loadItems(), loadPhotos(), loadNotes(), loadProducts()]);
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load job details';
    } finally {
      loading = false;
    }
  }

  async function loadItems() {
    const { data, error: err } = await supabase
      .from('job_card_items')
      .select('id, item_id, qty, price, total, item_type, notes, products(product_name)')
      .eq('job_card_id', jobId)
      .order('created_at', { ascending: true });

    if (!err && data) {
      items = data;
    }
  }

  async function loadPhotos() {
    const { data, error: err } = await supabase
      .from('job_card_photos')
      .select('id, file_url, file_name, created_at, users:uploaded_by(email)')
      .eq('job_card_id', jobId)
      .order('created_at', { ascending: false });

    if (!err && data) {
      photos = data;
    }
  }

  async function loadNotes() {
    const { data, error: err } = await supabase
      .from('job_card_notes')
      .select('id, note, created_at, created_by, users(email)')
      .eq('job_card_id', jobId)
      .order('created_at', { ascending: false });

    if (!err && data) {
      notes = data;
    }
  }

  async function loadProducts() {
    const { data, error: err } = await supabase
      .from('products')
      .select('id, product_name, product_type, sales_price')
      .order('product_name');

    if (!err && data) {
      products = data;
    }
  }

  function handleProductSearch() {
    const q = productSearch.toLowerCase().trim();
    if (!q) {
      filteredProducts = [];
      showProductDropdown = false;
      return;
    }
    filteredProducts = products
      .filter(p => p.product_name.toLowerCase().includes(q))
      .slice(0, 8);
    showProductDropdown = filteredProducts.length > 0;
  }

  function selectProduct(p: any) {
    selectedProduct = p;
    itemPrice = p.sales_price || 0;
    productSearch = '';
    showProductDropdown = false;
  }

  function clearProductSelection() {
    selectedProduct = null;
    productSearch = '';
    itemQty = 1;
    itemPrice = null;
    itemNotes = '';
    itemError = '';
  }

  async function addItem() {
    if (!selectedProduct || itemQty <= 0 || itemPrice === null) {
      itemError = 'Please select a product and enter qty and price';
      return;
    }

    itemSaving = true;
    itemError = '';

    try {
      const { error: err } = await supabase.from('job_card_items').insert({
        job_card_id: jobId,
        item_type: selectedProduct.product_type || 'product',
        item_id: selectedProduct.id,
        name: selectedProduct.product_name,
        qty: itemQty,
        price: itemPrice,
        total: itemQty * itemPrice,
        discount: 0,
        notes: itemNotes || null,
        created_by: $authStore.user?.id
      });

      if (err) throw err;

      clearProductSelection();
      await loadItems();
    } catch (err) {
      itemError = err instanceof Error ? err.message : 'Failed to add item';
    } finally {
      itemSaving = false;
    }
  }

  async function removeItem(itemId: string) {
    if (!confirm('Remove this item?')) return;

    deletingItemId = itemId;
    try {
      const { error: err } = await supabase
        .from('job_card_items')
        .delete()
        .eq('id', itemId);

      if (err) throw err;
      await loadItems();
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to remove item');
    } finally {
      deletingItemId = null;
    }
  }

  async function handlePhotoUpload(e: Event) {
    const input = e.target as HTMLInputElement;
    const files = input.files;
    if (!files || files.length === 0) return;

    photoUploading = true;
    photoError = '';

    for (const file of Array.from(files)) {
      try {
        const ext = file.name.split('.').pop() || 'jpg';
        const fileName = `${jobId}/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;

        const { error: uploadErr } = await supabase.storage
          .from('job-card-photos')
          .upload(fileName, file);

        if (uploadErr) throw uploadErr;

        const { data: urlData } = supabase.storage
          .from('job-card-photos')
          .getPublicUrl(fileName);

        if (urlData?.publicUrl) {
          await supabase.from('job_card_photos').insert({
            job_card_id: jobId,
            file_url: urlData.publicUrl,
            file_name: file.name,
            uploaded_by: $authStore.user?.id,
            created_by: $authStore.user?.id
          });
        }
      } catch (err) {
        photoError = (err instanceof Error ? err.message : 'Upload failed') + '. ';
      }
    }

    photoUploading = false;
    input.value = '';
    await loadPhotos();
  }

  async function addNote() {
    if (!newNote.trim()) {
      noteError = 'Note cannot be empty';
      return;
    }

    isAddingNote = true;
    noteError = '';

    try {
      const { error: err } = await supabase.from('job_card_notes').insert({
        job_card_id: jobId,
        note: newNote.trim(),
        created_by: $authStore.user?.id
      });

      if (err) throw err;

      newNote = '';
      await loadNotes();
    } catch (err) {
      noteError = err instanceof Error ? err.message : 'Failed to add note';
    } finally {
      isAddingNote = false;
    }
  }

  async function startJob() {
    if (!job || job.status !== 'Open') return;

    actionLoading = true;
    actionError = '';

    try {
      const { error: err } = await supabase
        .from('job_cards')
        .update({
          status: 'In Progress',
          updated_by: $authStore.user?.id,
          updated_at: new Date().toISOString()
        })
        .eq('id', jobId);

      if (err) throw err;

      job.status = 'In Progress';
      await loadJobDetail();
    } catch (err) {
      actionError = err instanceof Error ? err.message : 'Failed to start job';
    } finally {
      actionLoading = false;
    }
  }

  async function closeJob() {
    if (!job || job.status === 'Closed') return;
    if (!confirm('Close this job card? This marks it as completed.')) return;

    actionLoading = true;
    actionError = '';

    try {
      const { error: err } = await supabase
        .from('job_cards')
        .update({
          status: 'Closed',
          closed_by: $authStore.user?.id,
          closed_at: new Date().toISOString(),
          updated_by: $authStore.user?.id,
          updated_at: new Date().toISOString()
        })
        .eq('id', jobId);

      if (err) throw err;

      job.status = 'Closed';
      await loadJobDetail();
    } catch (err) {
      actionError = err instanceof Error ? err.message : 'Failed to close job';
    } finally {
      actionLoading = false;
    }
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  function formatDateTime(dateStr: string): string {
    return new Date(dateStr).toLocaleString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function getStatusColor(status: string): string {
    const colors: Record<string, string> = {
      'Open': '#FF6B6B',
      'In Progress': '#4ECDC4',
      'Closed': '#95E1D3',
      'Billed': '#A8E6CF'
    };
    return colors[status] || '#CCCCCC';
  }

  function goBack() {
    setMobilePage('my-jobs', 'My Jobs');
  }

  onMount(() => {
    const unsubscribe = mobilePageStore.subscribe(value => {
      mobilePageValue = value;
      jobId = value.selectedJobId || '';
    });
    
    setMobilePage('job-detail', 'Job Card Details', jobId);
    loadJobDetail();
    
    return unsubscribe;
  });
</script>

<MobilePageWrapper>
  {#if loading}
    <div class="loading-state">
      <p>Loading job details...</p>
    </div>
  {:else if error}
    <div class="error-state">
      <p>{error}</p>
      <button on:click={goBack} class="btn-back">← Go Back</button>
    </div>
  {:else if job}
    <div class="job-detail-page">
      <!-- Job Header -->
      <div class="job-header">
        <div class="job-info-top">
          <h2>{job.job_card_no}</h2>
          <div class="status-badge" style="background-color: {getStatusColor(job.status)}">
            {job.status}
          </div>
        </div>
        <div class="job-info-summary">
          <div class="info-item">
            <span class="label">Priority:</span>
            <span class="value">{job.priority}</span>
          </div>
        </div>
        {#if job.description}
          <div class="description">
            <strong>Description:</strong>
            <p>{job.description}</p>
          </div>
        {/if}
      </div>

      <!-- Customer Details Section -->
      <div class="details-section">
        <h3>Customer Details</h3>
        <div class="details-grid">
          <div class="detail-item">
            <span class="label">Name</span>
            <span class="value">{job.customer_name}</span>
          </div>
          <div class="detail-item">
            <span class="label">Location</span>
            <span class="value">{job.customer_place}</span>
          </div>
          <div class="detail-item">
            <span class="label">Gender</span>
            <span class="value">{job.customer_gender}</span>
          </div>
          {#if job.customer_phones && job.customer_phones.length > 0}
            <div class="detail-item">
              <span class="label">Phone</span>
              <div class="phone-list">
                {#each job.customer_phones as phone}
                  <span class="phone-value">{phone}</span>
                {/each}
              </div>
            </div>
          {/if}
        </div>
      </div>

      <!-- Vehicle Details Section -->
      <div class="details-section">
        <h3>Vehicle Details</h3>
        <div class="details-grid">
          <div class="detail-item">
            <span class="label">Registration #</span>
            <span class="value"><strong>{job.vehicle_number}</strong></span>
          </div>
          <div class="detail-item">
            <span class="label">Model</span>
            <span class="value">{job.vehicle_model}</span>
          </div>
          <div class="detail-item">
            <span class="label">Make</span>
            <span class="value">{job.vehicle_make}</span>
          </div>
          <div class="detail-item">
            <span class="label">Generation</span>
            <span class="value">{job.vehicle_generation}</span>
          </div>
          <div class="detail-item">
            <span class="label">Type</span>
            <span class="value">{job.vehicle_type}</span>
          </div>
          <div class="detail-item">
            <span class="label">Variant</span>
            <span class="value">{job.vehicle_variant}</span>
          </div>
          <div class="detail-item">
            <span class="label">Gearbox</span>
            <span class="value">{job.vehicle_gearbox}</span>
          </div>
          <div class="detail-item">
            <span class="label">Fuel Type</span>
            <span class="value">{job.vehicle_fuel}</span>
          </div>
          <div class="detail-item">
            <span class="label">Body</span>
            <span class="value">{job.vehicle_body}</span>
          </div>
        </div>
      </div>
      <div class="action-buttons">
        {#if actionError}
          <div class="error-msg">{actionError}</div>
        {/if}
        {#if job.status === 'Open'}
          <button class="btn btn-primary" on:click={startJob} disabled={actionLoading}>
            {actionLoading ? 'Starting...' : 'Start Job'}
          </button>
        {/if}
        {#if job.status === 'In Progress'}
          <button class="btn btn-success" on:click={closeJob} disabled={actionLoading}>
            {actionLoading ? 'Closing...' : 'Close Job'}
          </button>
        {/if}
      </div>

      <!-- Items Section -->
      <div class="section">
        <h3>Products & Services ({items.length})</h3>

        {#if job.status !== 'Closed'}
          <div class="add-item-form">
            <div class="form-field">
              <label>Search & Select Product</label>
              <div class="search-box">
                <input
                  type="text"
                  placeholder="Search product..."
                  bind:value={productSearch}
                  on:input={handleProductSearch}
                  on:focus={handleProductSearch}
                />
                {#if showProductDropdown}
                  <div class="dropdown">
                    {#each filteredProducts as p}
                      <button class="dropdown-item" on:click={() => selectProduct(p)}>
                        <strong>{p.product_name}</strong>
                        <span class="product-type">{p.product_type}</span>
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>
            </div>

            {#if selectedProduct}
              <div class="selected-product">
                <div class="product-name">{selectedProduct.product_name}</div>
                <div class="form-row">
                  <div class="form-field">
                    <label>Qty</label>
                    <input type="number" min="1" step="0.01" bind:value={itemQty} />
                  </div>
                  <div class="form-field">
                    <label>Price (₹)</label>
                    <input type="number" min="0" step="0.01" bind:value={itemPrice} />
                  </div>
                </div>
                <div class="form-field">
                  <label>Notes (optional)</label>
                  <input type="text" placeholder="Add notes..." bind:value={itemNotes} />
                </div>
                {#if itemError}
                  <div class="error-msg">{itemError}</div>
                {/if}
                <div class="button-group">
                  <button class="btn btn-small btn-add-item" on:click={addItem} disabled={itemSaving}>
                    {itemSaving ? 'Adding...' : '+ Add Item'}
                  </button>
                  <button class="btn btn-small btn-cancel" on:click={clearProductSelection}>
                    Cancel
                  </button>
                </div>
              </div>
            {/if}
          </div>
        {/if}

        {#if items.length > 0}
          <div class="items-list">
            {#each items as item (item.id)}
              <div class="item-card">
                <div class="item-header">
                  <div class="item-name">{item.products?.product_name || item.name}</div>
                  <div class="item-type-tag">{item.item_type}</div>
                </div>
                <div class="item-details">
                  <div class="detail-row">
                    <span>Qty: {item.qty}</span>
                    <span>Price: ₹{parseFloat(item.price).toFixed(2)}</span>
                    <span>Total: ₹{parseFloat(item.total).toFixed(2)}</span>
                  </div>
                  {#if item.notes}
                    <div class="item-notes">{item.notes}</div>
                  {/if}
                </div>
                {#if job.status !== 'Closed'}
                  <button
                    class="btn btn-remove-item"
                    on:click={() => removeItem(item.id)}
                    disabled={deletingItemId === item.id}
                  >
                    {deletingItemId === item.id ? 'Removing...' : '✕ Remove'}
                  </button>
                {/if}
              </div>
            {/each}
          </div>
        {:else}
          <div class="empty-message">No items added yet</div>
        {/if}
      </div>

      <!-- Photos Section -->
      <div class="section">
        <h3>Photos ({photos.length})</h3>

        {#if job.status !== 'Closed'}
          <div class="photo-upload-section">
            <input
              type="file"
              multiple
              accept="image/*"
              on:change={handlePhotoUpload}
              disabled={photoUploading}
              id="photo-input"
            />
            <label for="photo-input" class="btn btn-upload" class:uploading={photoUploading}>
              {photoUploading ? 'Uploading...' : '📷 Add Photos'}
            </label>
            {#if photoError}
              <div class="error-msg">{photoError}</div>
            {/if}
          </div>
        {/if}

        {#if photos.length > 0}
          <div class="photos-grid">
            {#each photos as photo (photo.id)}
              <div class="photo-card">
                <img src={photo.file_url} alt={photo.file_name} />
                <div class="photo-meta">
                  <small>{photo.file_name}</small>
                  <small>{formatDateTime(photo.created_at)}</small>
                </div>
              </div>
            {/each}
          </div>
        {:else}
          <div class="empty-message">No photos yet</div>
        {/if}
      </div>

      <!-- Notes Section -->
      <div class="section">
        <h3>Notes ({notes.length})</h3>

        {#if job.status !== 'Closed'}
          <div class="notes-form">
            <input
              type="text"
              placeholder="Add a note..."
              bind:value={newNote}
              on:keydown={e => e.key === 'Enter' && addNote()}
            />
            <button class="btn btn-small btn-add-note" on:click={addNote} disabled={isAddingNote || !newNote.trim()}>
              {isAddingNote ? '...' : 'Add'}
            </button>
            {#if noteError}
              <div class="error-msg">{noteError}</div>
            {/if}
          </div>
        {/if}

        {#if notes.length > 0}
          <div class="notes-list">
            {#each notes as note (note.id)}
              <div class="note-card">
                <div class="note-header">
                  <strong>{note.users?.email || 'Unknown'}</strong>
                  <small>{formatDateTime(note.created_at)}</small>
                </div>
                <div class="note-text">{note.note}</div>
              </div>
            {/each}
          </div>
        {:else}
          <div class="empty-message">No notes yet</div>
        {/if}
      </div>
    </div>
  {/if}
</MobilePageWrapper>

<style>
  .loading-state, .error-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: 20px;
    padding: 20px;
    text-align: center;
  }

  .error-state {
    background: #ffebee;
    color: #d32f2f;
  }

  .job-detail-page {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 12px;
    overflow-y: auto;
    height: 100%;
  }

  .job-header {
    background: white;
    border-radius: 8px;
    padding: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .job-info-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }

  .job-info-top h2 {
    margin: 0;
    font-size: 18px;
    color: #333;
  }

  .status-badge {
    padding: 4px 12px;
    border-radius: 16px;
    color: white;
    font-size: 11px;
    font-weight: 600;
    min-width: 70px;
    text-align: center;
  }

  .job-info-summary {
    display: grid;
    grid-template-columns: 1fr;
    gap: 12px;
    margin-bottom: 12px;
    font-size: 13px;
  }

  .info-item {
    display: flex;
    flex-direction: column;
  }

  .info-item .label {
    color: #666;
    font-weight: 600;
    margin-bottom: 2px;
  }

  .info-item .value {
    color: #333;
  }

  .description {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #e0e0e0;
    font-size: 13px;
  }

  .description strong {
    display: block;
    margin-bottom: 6px;
    color: #666;
  }

  .description p {
    margin: 0;
    color: #333;
    line-height: 1.4;
  }

  .action-buttons {
    display: flex;
    gap: 8px;
  }

  .btn {
    flex: 1;
    padding: 10px 16px;
    border: none;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s;
  }

  .btn-primary {
    background: #2196F3;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: #1976D2;
  }

  .btn-success {
    background: #4CAF50;
    color: white;
  }

  .btn-success:hover:not(:disabled) {
    background: #388E3C;
  }

  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .section {
    background: white;
    border-radius: 8px;
    padding: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .section h3 {
    margin: 0 0 12px;
    font-size: 15px;
    color: #333;
    border-bottom: 2px solid #C41E3A;
    padding-bottom: 8px;
  }

  /* Add Item Form */
  .add-item-form {
    margin-bottom: 12px;
  }

  .form-field {
    margin-bottom: 10px;
  }

  .form-field label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #666;
    margin-bottom: 4px;
  }

  .form-field input {
    width: 100%;
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
    box-sizing: border-box;
  }

  .search-box {
    position: relative;
  }

  .dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #ddd;
    border-top: none;
    border-radius: 0 0 4px 4px;
    max-height: 200px;
    overflow-y: auto;
    z-index: 10;
  }

  .dropdown-item {
    width: 100%;
    padding: 10px;
    border: none;
    background: white;
    text-align: left;
    cursor: pointer;
    font-size: 13px;
    border-bottom: 1px solid #f0f0f0;
  }

  .dropdown-item:hover {
    background: #f5f5f5;
  }

  .dropdown-item strong {
    display: block;
  }

  .product-type {
    font-size: 11px;
    color: #999;
    margin-top: 2px;
  }

  .selected-product {
    background: #f9f9f9;
    padding: 12px;
    border-radius: 4px;
    margin-bottom: 12px;
    border-left: 3px solid #C41E3A;
  }

  .product-name {
    font-weight: 600;
    margin-bottom: 10px;
    color: #333;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-bottom: 10px;
  }

  .button-group {
    display: flex;
    gap: 8px;
    margin-top: 10px;
  }

  .btn-small {
    padding: 6px 12px;
    font-size: 12px;
  }

  .btn-add-item {
    background: #4CAF50;
    color: white;
    flex: 1;
  }

  .btn-cancel {
    background: #f0f0f0;
    color: #333;
  }

  /* Items List */
  .items-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .item-card {
    background: #f9f9f9;
    padding: 12px;
    border-radius: 6px;
    border-left: 3px solid #2196F3;
  }

  .item-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }

  .item-name {
    font-weight: 600;
    color: #333;
    font-size: 13px;
  }

  .item-type-tag {
    background: #E3F2FD;
    color: #1976D2;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
  }

  .item-details {
    font-size: 12px;
    color: #666;
    margin-bottom: 8px;
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
  }

  .item-notes {
    font-size: 11px;
    color: #999;
    margin-top: 4px;
    font-style: italic;
  }

  .btn-remove-item {
    width: 100%;
    padding: 6px;
    background: #ffebee;
    color: #d32f2f;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    cursor: pointer;
  }

  .btn-remove-item:hover:not(:disabled) {
    background: #ffcdd2;
  }

  /* Photos Section */
  .photo-upload-section {
    margin-bottom: 12px;
  }

  #photo-input {
    display: none;
  }

  .btn-upload {
    display: block;
    width: 100%;
    background: #E91E63;
    color: white;
  }

  .btn-upload:hover:not(.uploading) {
    background: #C2185B;
  }

  .photos-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
  }

  .photo-card {
    position: relative;
    border-radius: 6px;
    overflow: hidden;
    background: #f0f0f0;
    aspect-ratio: 1;
  }

  .photo-card img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .photo-meta {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    background: linear-gradient(transparent, rgba(0,0,0,0.7));
    color: white;
    padding: 8px;
    font-size: 10px;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
  }

  /* Notes Section */
  .notes-form {
    display: flex;
    gap: 8px;
    margin-bottom: 12px;
  }

  .notes-form input {
    flex: 1;
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
  }

  .btn-add-note {
    background: #FF9800;
    color: white;
  }

  .notes-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .note-card {
    background: #FFF3E0;
    padding: 10px;
    border-radius: 6px;
    border-left: 3px solid #FF9800;
  }

  .note-header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 6px;
    font-size: 12px;
  }

  .note-header strong {
    color: #333;
  }

  .note-header small {
    color: #999;
  }

  .note-text {
    font-size: 13px;
    color: #333;
    line-height: 1.4;
  }

  /* Empty and Error Messages */
  .empty-message {
    text-align: center;
    color: #999;
    font-size: 13px;
    padding: 16px;
  }

  .error-msg {
    background: #ffebee;
    color: #d32f2f;
    padding: 8px;
    border-radius: 4px;
    font-size: 12px;
    margin: 8px 0;
  }

  .btn-back {
    background: #ddd;
    padding: 10px 20px;
  }

  /* Details Sections */
  .details-section {
    background: white;
    border-radius: 8px;
    padding: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .details-section h3 {
    margin: 0 0 12px;
    font-size: 15px;
    color: #333;
    border-bottom: 2px solid #C41E3A;
    padding-bottom: 8px;
  }

  .details-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .detail-item {
    display: flex;
    flex-direction: column;
  }

  .detail-item .label {
    font-size: 12px;
    font-weight: 600;
    color: #666;
    margin-bottom: 4px;
  }

  .detail-item .value {
    font-size: 13px;
    color: #333;
    font-weight: 500;
    word-wrap: break-word;
  }

  .phone-list {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .phone-value {
    font-size: 13px;
    color: #0066cc;
    text-decoration: none;
  }
</style>
