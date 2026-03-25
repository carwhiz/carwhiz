<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '../../stores/authStore';
  import { supabase } from '../../lib/supabaseClient';
  import { setMobilePage } from '../../stores/mobilePageStore';

  let jobToEdit: any = null;
  let editAssignedUser = '';
  let currentUserEmail = '';
  let editPriority = 'Normal';
  let editExpectedDate = '';
  let editMechanicalInspection = '';
  let editBodyInspection = '';

  let jobItems: any[] = [];
  let products: any[] = [];
  let users: any[] = [];
  
  let selectedProduct: any = null;
  let itemQty = 1;
  let itemPrice: any = null;
  let itemDiscount = 0;
  let productSearch = '';

  let saving = false;
  let error = '';

  onMount(async () => {
    // Get job from sessionStorage
    const jobData = sessionStorage.getItem('mobileEditingJob');
    if (!jobData) {
      goBack();
      return;
    }

    jobToEdit = JSON.parse(jobData);
    
    // Initialize form fields with job data
    editAssignedUser = jobToEdit.assigned_user_id || '';
    currentUserEmail = jobToEdit.assigned_user_email || '';
    editPriority = jobToEdit.priority || 'Normal';
    // Format date to YYYY-MM-DD for input[type=date]
    if (jobToEdit.expected_date) {
      editExpectedDate = jobToEdit.expected_date.split('T')[0];
    }
    editMechanicalInspection = jobToEdit.mechanical_inspection || '';
    editBodyInspection = jobToEdit.body_inspection || '';

    // Load data
    await Promise.all([
      loadJobItems(),
      loadProducts(),
      loadUsers()
    ]);
  });

  async function loadJobItems() {
    if (!jobToEdit) return;
    const { data, error: err } = await supabase
      .from('job_card_items')
      .select('*')
      .eq('job_card_id', jobToEdit.id)
      .order('created_at', { ascending: true });

    if (!err && data) {
      jobItems = data;
    }
  }

  async function loadProducts() {
    const { data, error: err } = await supabase
      .from('products')
      .select('id, product_name, sales_price')
      .order('product_name', { ascending: true });

    if (!err && data) {
      products = data;
    }
  }

  async function loadUsers() {
    const { data, error: err } = await supabase
      .from('users')
      .select('id, email, phone_number')
      .order('email', { ascending: true });

    if (!err && data) {
      users = data;
    }
  }

  function goBack() {
    sessionStorage.removeItem('mobileEditingJob');
    setMobilePage('jobs', 'Jobs');
  }

  function selectProduct(product: any) {
    selectedProduct = product;
    itemPrice = product.sales_price;
    productSearch = '';
  }

  // Computed filtered products based on search
  $: filteredProducts = productSearch.trim() === ''
    ? products
    : products.filter(p => 
        p.product_name.toLowerCase().includes(productSearch.toLowerCase())
      );

  function addItem() {
    if (!selectedProduct || !itemQty) {
      error = 'Please select a product and enter quantity';
      return;
    }

    const newItem = {
      job_card_id: jobToEdit.id,
      item_type: 'product',
      item_id: selectedProduct.id,
      name: selectedProduct.product_name,
      qty: itemQty,
      price: itemPrice || 0,
      discount: itemDiscount || 0,
      total: (itemQty * (itemPrice || 0)) - (itemDiscount || 0),
      notes: ''
    };

    jobItems = [...jobItems, newItem];
    selectedProduct = null;
    itemQty = 1;
    itemPrice = null;
    itemDiscount = 0;
    error = '';
  }

  function removeItem(index: number) {
    jobItems = jobItems.filter((_, i) => i !== index);
  }

  async function saveJobCard() {
    saving = true;
    error = '';

    try {
      // Update job card
      const { error: updateError } = await supabase
        .from('job_cards')
        .update({
          assigned_user_id: editAssignedUser,
          priority: editPriority,
          expected_date: editExpectedDate || null,
          mechanical_inspection: editMechanicalInspection,
          body_inspection: editBodyInspection,
          notes: editNotes,
          updated_by: $authStore.user?.id,
          updated_at: new Date().toISOString()
        })
        .eq('id', jobToEdit.id);

      if (updateError) throw updateError;

      // Handle items (simple approach - delete old ones and insert new ones)
      await supabase
        .from('job_card_items')
        .delete()
        .eq('job_card_id', jobToEdit.id);

      if (jobItems.length > 0) {
        const itemsToInsert = jobItems.map(item => ({
          job_card_id: jobToEdit.id,
          item_type: item.item_type || 'product',
          item_id: item.item_id,
          name: item.name,
          qty: item.qty,
          price: item.price,
          discount: item.discount,
          total: item.total,
          notes: item.notes || '',
          created_by: $authStore.user?.id,
          updated_by: $authStore.user?.id
        }));

        const { error: itemsError } = await supabase
          .from('job_card_items')
          .insert(itemsToInsert);

        if (itemsError) throw itemsError;
      }

      goBack();
    } catch (err: any) {
      error = err.message || 'Failed to save job card';
    } finally {
      saving = false;
    }
  }


</script>

<div class="mje-container">
  <div class="mje-header">
    <button class="mje-back-btn" on:click={goBack}>← Back</button>
    <h1 class="mje-title">Edit Job Card</h1>
  </div>

  {#if error}
    <div class="mje-error">{error}</div>
  {/if}

  <div class="mje-content">
    <!-- Assigned To -->
    <div class="mje-field">
      <label for="assigned-user">Assigned To *</label>
      {#if currentUserEmail}
        <div class="mje-current-value">Currently: <strong>{currentUserEmail}</strong></div>
      {/if}
      <select id="assigned-user" bind:value={editAssignedUser} disabled={saving}>
        <option value="">Select Technician</option>
        {#each users as user (user.id)}
          <option value={user.id}>{user.user_name || user.email}</option>
        {/each}
      </select>
    </div>

    <!-- Priority -->
    <div class="mje-field">
      <label for="priority">Priority</label>
      <select id="priority" bind:value={editPriority} disabled={saving}>
        <option value="Low">Low</option>
        <option value="Normal">Normal</option>
        <option value="High">High</option>
        <option value="Urgent">Urgent</option>
      </select>
    </div>

    <!-- Expected Date -->
    <div class="mje-field">
      <label for="expected-date">Expected Date</label>
      {#if editExpectedDate}
        <div class="mje-current-value">Currently: <strong>{editExpectedDate}</strong></div>
      {/if}
      <input type="date" id="expected-date" bind:value={editExpectedDate} disabled={saving} />
    </div>

    <!-- Mechanical Inspection -->
    <div class="mje-field">
      <label for="mechanical-inspection">Mechanical Inspection</label>
      {#if editMechanicalInspection}
        <div class="mje-current-value"><strong>Current:</strong> {editMechanicalInspection}</div>
      {/if}
      <textarea id="mechanical-inspection" rows="3" bind:value={editMechanicalInspection} disabled={saving} placeholder="Engine, transmission, brakes, suspension..."></textarea>
    </div>

    <!-- Body Inspection -->
    <div class="mje-field">
      <label for="body-inspection">Body Inspection</label>
      {#if editBodyInspection}
        <div class="mje-current-value"><strong>Current:</strong> {editBodyInspection}</div>
      {/if}
      <textarea id="body-inspection" rows="3" bind:value={editBodyInspection} disabled={saving} placeholder="Paint, dents, rust, interior condition..."></textarea>
    </div>

    <!-- Items Section -->
    <div class="mje-section">
      <h3>Items ({jobItems.length})</h3>

      <!-- Add Item Form -->
      <div class="mje-add-item">
        <div class="mje-field">
          <label for="product-search">Product / Service *</label>
          <div class="product-search-container">
            <input 
              type="text" 
              id="product-search" 
              placeholder="Search products/services..." 
              bind:value={productSearch}
              disabled={saving}
            />
            <button type="button" class="create-product-btn" disabled={saving} title="Create new product">
              + Create
            </button>
          </div>

          {#if productSearch.trim() && !selectedProduct}
            <div class="product-list-dropdown">
              {#if filteredProducts.length > 0}
                {#each filteredProducts as product (product.id)}
                  <button 
                    type="button"
                    class="product-item" 
                    on:click={() => selectProduct(product)}
                    disabled={saving}
                  >
                    <div class="product-item-name">{product.product_name}</div>
                    <div class="product-item-price">₹{product.sales_price}</div>
                  </button>
                {/each}
              {:else}
                <div class="product-not-found">
                  No products found. <button type="button" class="link-btn">Create new?</button>
                </div>
              {/if}
            </div>
          {/if}
        </div>

        {#if selectedProduct}
          <div class="mje-selected">
            <strong>{selectedProduct.product_name}</strong> - ₹{selectedProduct.sales_price}
          </div>

          <div class="mje-item-inputs">
            <div class="mje-field">
              <label for="qty">Qty *</label>
              <input type="number" id="qty" bind:value={itemQty} min="1" step="0.01" disabled={saving} />
            </div>
            <div class="mje-field">
              <label for="price">Price *</label>
              <input type="number" id="price" bind:value={itemPrice} step="0.01" disabled={saving} />
            </div>
            <div class="mje-field">
              <label for="discount">Discount</label>
              <input type="number" id="discount" bind:value={itemDiscount} step="0.01" disabled={saving} />
            </div>
          </div>

          <button class="mje-btn-add" on:click={addItem} disabled={saving}>+ Add Item</button>
        {/if}
      </div>

      <!-- Items List -->
      {#if jobItems.length > 0}
        <div class="mje-items-list">
          {#each jobItems as item, idx (idx)}
            <div class="mje-item">
              <div class="item-name">{item.name}</div>
              <div class="item-details">
                <span>Qty: {item.qty}</span>
                <span>₹{item.price}</span>
                <span class="item-total">Total: ₹{item.total}</span>
              </div>
              <button class="mje-btn-remove" on:click={() => removeItem(idx)} disabled={saving}>Remove</button>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Action Buttons -->
    <div class="mje-actions">
      <button class="mje-btn-save" on:click={saveJobCard} disabled={saving}>
        {saving ? 'Saving...' : 'Save Changes'}
      </button>
      <button class="mje-btn-cancel" on:click={goBack} disabled={saving}>
        Cancel
      </button>
    </div>
  </div>
</div>

<style>
  .mje-container {
    height: 100vh;
    display: flex;
    flex-direction: column;
    background: #f9fafb;
  }

  .mje-header {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .mje-back-btn {
    background: none;
    border: none;
    font-size: 1.2rem;
    cursor: pointer;
    padding: 0.5rem;
    min-width: 48px;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #3b82f6;
    font-weight: 600;
  }

  .mje-title {
    margin: 0;
    flex: 1;
    font-size: 1.2rem;
    color: #111827;
  }

  .mje-error {
    background: #fee2e2;
    color: #C41E3A;
    padding: 0.75rem 1rem;
    margin: 1rem;
    border-radius: 6px;
    font-size: 0.9rem;
  }

  .mje-content {
    flex: 1;
    overflow-y: auto;
    padding: 1rem;
    -webkit-overflow-scrolling: touch;
  }

  .mje-field {
    margin-bottom: 1.5rem;
  }

  .mje-section {
    margin-bottom: 2rem;
    background: white;
    padding: 1rem;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
  }

  .mje-section h3 {
    margin: 0 0 1rem 0;
    font-size: 1rem;
    color: #111827;
    font-weight: 600;
  }

  label {
    display: block;
    font-size: 0.85rem;
    font-weight: 600;
    color: #4b5563;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .mje-current-value {
    background: #f0f9ff;
    border: 1px solid #bfdbfe;
    color: #1e40af;
    padding: 0.75rem;
    border-radius: 4px;
    margin-bottom: 0.75rem;
    font-size: 0.9rem;
    line-height: 1.4;
    word-break: break-word;
  }

  .mje-current-value strong {
    font-weight: 600;
  }

  select,
  input[type="text"],
  input[type="number"],
  input[type="date"],
  textarea {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 1rem;
    font-family: inherit;
    box-sizing: border-box;
    -webkit-appearance: none;
    appearance: none;
  }

  textarea {
    resize: vertical;
    min-height: 80px;
    line-height: 1.4;
  }

  input:disabled,
  select:disabled,
  textarea:disabled {
    background: #f3f4f6;
    cursor: not-allowed;
  }

  .mje-add-item {
    background: #f9fafb;
    padding: 1rem;
    border-radius: 6px;
    margin-bottom: 1.5rem;
  }

  .mje-product-list {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    max-height: 200px;
    overflow-y: auto;
    margin-top: 0.5rem;
    -webkit-overflow-scrolling: touch;
  }

  .mje-product-item {
    width: 100%;
    padding: 0.75rem;
    border: none;
    border-bottom: 1px solid #f3f4f6;
    background: white;
    text-align: left;
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.9rem;
  }

  .mje-product-item:last-child {
    border-bottom: none;
  }

  .mje-product-item:active {
    background: #f0fdf4;
  }

  .product-search-container {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    position: relative;
  }

  .product-search-container input {
    flex: 1;
    padding: 0.75rem;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 1rem;
  }

  .product-search-container input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .create-product-btn {
    padding: 0.75rem 1rem;
    background: #10b981;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    min-height: 44px;
    transition: all 0.2s;
  }

  .create-product-btn:active:not(:disabled) {
    background: #059669;
    transform: scale(0.95);
  }

  .create-product-btn:disabled {
    background: #d1d5db;
    cursor: not-allowed;
  }

  .product-list-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #e5e7eb;
    border-top: none;
    border-radius: 0 0 6px 6px;
    max-height: 250px;
    overflow-y: auto;
    z-index: 100;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    -webkit-overflow-scrolling: touch;
  }

  .product-item {
    width: 100%;
    padding: 0.75rem 1rem;
    border: none;
    border-bottom: 1px solid #f3f4f6;
    background: white;
    text-align: left;
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.9rem;
    transition: all 0.15s;
  }

  .product-item:last-child {
    border-bottom: none;
  }

  .product-item:active:not(:disabled) {
    background: #f0fdf4;
  }

  .product-item:disabled {
    cursor: not-allowed;
    opacity: 0.6;
  }

  .product-item-name {
    flex: 1;
    font-weight: 500;
    color: #111827;
  }

  .product-item-price {
    color: #059669;
    font-weight: 600;
    font-size: 0.85rem;
    margin-left: 1rem;
  }

  .product-not-found {
    padding: 1rem;
    text-align: center;
    color: #6b7280;
    font-size: 0.9rem;
  }

  .link-btn {
    background: none;
    border: none;
    color: #3b82f6;
    cursor: pointer;
    font-weight: 600;
    padding: 0;
    text-decoration: underline;
  }

  .link-btn:active {
    color: #1d4ed8;
  }

  .product-name {
    font-weight: 500;
    flex: 1;
  }

  .product-price {
    color: #059669;
    font-weight: 600;
    white-space: nowrap;
  }

  .mje-selected {
    background: #f0fdf4;
    padding: 0.75rem;
    border-radius: 4px;
    margin-bottom: 1rem;
    color: #166534;
    font-size: 0.9rem;
  }

  .mje-item-inputs {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .mje-btn-add {
    width: 100%;
    padding: 0.75rem;
    background: #10b981;
    color: white;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    cursor: pointer;
    min-height: 44px;
    font-size: 0.95rem;
  }

  .mje-btn-add:active {
    background: #059669;
    transform: scale(0.98);
  }

  .mje-items-list {
    margin-bottom: 1rem;
  }

  .mje-item {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    padding: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .item-name {
    font-weight: 600;
    color: #111827;
    margin-bottom: 0.5rem;
  }

  .item-details {
    display: flex;
    gap: 1rem;
    font-size: 0.85rem;
    color: #6b7280;
    margin-bottom: 0.75rem;
  }

  .item-total {
    font-weight: 600;
    color: #059669;
  }

  .mje-btn-remove {
    width: 100%;
    padding: 0.5rem;
    background: #fee2e2;
    color: #C41E3A;
    border: none;
    border-radius: 4px;
    font-weight: 600;
    cursor: pointer;
    font-size: 0.85rem;
  }

  .mje-actions {
    display: flex;
    gap: 0.75rem;
    margin-top: 1rem;
    padding-bottom: 2rem;
  }

  .mje-actions button {
    flex: 1;
    padding: 1rem;
    border: none;
    border-radius: 6px;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    min-height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mje-btn-save {
    background: #10b981;
    color: white;
  }

  .mje-btn-save:active {
    background: #059669;
    transform: scale(0.98);
  }

  .mje-btn-cancel {
    background: #e5e7eb;
    color: #4b5563;
  }

  .mje-btn-cancel:active {
    background: #d1d5db;
  }

  .mje-btn-save:disabled,
  .mje-btn-cancel:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .create-product-btn {
    width: 100%;
    padding: 0.75rem 1rem;
    margin-top: 0.5rem;
    background: #059669;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .create-product-btn:active {
    background: #047857;
    transform: scale(0.98);
  }

  .create-product-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  @media (max-width: 600px) {
    .mje-header {
      padding: 0.75rem;
    }

    .mje-item-inputs {
      grid-template-columns: 1fr;
    }
  }
</style>
