<!-- ============================================================
     PRODUCTS > MANAGE > CREATE PRODUCT WINDOW
     Purpose: Full-page form to create a new product
     Section: Products > Manage > Create Product
     Window ID: products-create-product
     Logic:
       - Product Type = product → show applicability
         - Specific → show vehicle dropdown
         - Universal → no vehicle
       - Product Type = consumable → show unit/pricing directly
       - Product Type = service → reserved for later
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';
  import SearchableDropdown from '../../../shared/SearchableDropdown.svelte';
  import AddMasterDataPopup from '../../../shared/AddMasterDataPopup.svelte';
  import EditMasterDataPopup from '../../../shared/EditMasterDataPopup.svelte';

  // ---- Form state ----
  let product_name = '';
  let product_type = '';
  let applicability = '';
  let vehicle_id = '';
  let unit_id = '';
  let unit_qty: string = '';
  let current_cost: string = '';
  let sales_price: string = '';
  let first_level_discount: string = '';
  let second_level_discount: string = '';
  let third_level_discount: string = '';
  let barcode: string = '';
  let part_number: string = '';
  let brand_id = '';
  let expiry_date: string = '';
  let selectedFile: File | null = null;
  let fileInputEl: HTMLInputElement;

  // ---- Master data ----
  let units: { id: string; name: string }[] = [];
  let vehicles: { id: string; name: string }[] = [];
  let brands: { id: string; name: string }[] = [];

  // ---- Popup state (add unit / brand) ----
  let addPopupOpen = false;
  let addPopupTable = 'units';
  let addPopupTitle = 'Add Unit';

  // ---- Edit popup state ----
  let editPopupOpen = false;
  let editPopupTable = 'units';
  let editPopupTitle = 'Edit Unit';
  let editPopupItemId = '';
  let editPopupItemName = '';

  // ---- Save state ----
  let saving = false;
  let saveError = '';
  let saveSuccess = '';

  // ---- Computed: what to show ----
  $: showApplicability = product_type === 'product';
  $: showVehicle = product_type === 'product' && applicability === 'specific';
  $: showPricingFields = product_type === 'product' || product_type === 'consumable';
  $: showServiceMsg = product_type === 'service';

  // Reset dependent fields when product_type changes
  $: if (product_type !== 'product') {
    applicability = '';
    vehicle_id = '';
  }
  $: if (applicability !== 'specific') {
    vehicle_id = '';
  }

  onMount(() => {
    loadUnits();
    loadVehicles();
    loadBrands();
  });

  async function loadUnits() {
    const { data } = await supabase.from('units').select('id, name').order('name');
    units = (data as { id: string; name: string }[]) || [];
  }

  async function loadVehicles() {
    const { data } = await supabase.from('vehicles').select('id, model_name').order('model_name');
    vehicles = (data || []).map((v: any) => ({ id: v.id, name: v.model_name }));
  }

  async function loadBrands() {
    const { data } = await supabase.from('brands').select('id, name').order('name');
    brands = (data as { id: string; name: string }[]) || [];
  }

  function handleAddUnit() {
    addPopupTable = 'units';
    addPopupTitle = 'Add Unit';
    addPopupOpen = true;
  }

  function handleAddBrand() {
    addPopupTable = 'brands';
    addPopupTitle = 'Add Brand';
    addPopupOpen = true;
  }

  function handleMasterCreated() {
    addPopupOpen = false;
    if (addPopupTable === 'units') loadUnits();
    else loadBrands();
  }

  function handleEditUnit(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'units';
    editPopupTitle = 'Edit Unit';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleEditBrand(e: CustomEvent<{ id: string; name: string }>) {
    editPopupTable = 'brands';
    editPopupTitle = 'Edit Brand';
    editPopupItemId = e.detail.id;
    editPopupItemName = e.detail.name;
    editPopupOpen = true;
  }

  function handleMasterUpdated() {
    editPopupOpen = false;
    if (editPopupTable === 'units') loadUnits();
    else loadBrands();
  }

  function handleFileSelect() {
    const files = fileInputEl?.files;
    if (files && files.length > 0) {
      selectedFile = files[0];
    }
  }

  function removeFile() {
    selectedFile = null;
    if (fileInputEl) fileInputEl.value = '';
  }

  async function handleSave() {
    // Validate
    if (!product_name.trim()) {
      saveError = 'Product Name is required';
      return;
    }
    if (!product_type) {
      saveError = 'Product Type is required';
      return;
    }
    if (product_type === 'service') {
      saveError = 'Service type is reserved for future use';
      return;
    }

    saving = true;
    saveError = '';
    saveSuccess = '';

    // Upload file if selected
    let file_path: string | null = null;
    if (selectedFile) {
      const fileExt = selectedFile.name.split('.').pop();
      const fileName = `${crypto.randomUUID()}.${fileExt}`;
      const { error: uploadError } = await supabase.storage
        .from('product-files')
        .upload(fileName, selectedFile);

      if (uploadError) {
        saving = false;
        saveError = 'File upload failed: ' + uploadError.message;
        return;
      }
      file_path = fileName;
    }

    // Insert product
    const row: Record<string, any> = {
      product_name: product_name.trim(),
      product_type,
      applicability: product_type === 'product' ? applicability || null : null,
      vehicle_id: showVehicle && vehicle_id ? vehicle_id : null,
      unit_id: unit_id || null,
      unit_qty: unit_qty ? parseFloat(unit_qty) : null,
      current_cost: current_cost ? parseFloat(current_cost) : null,
      sales_price: sales_price ? parseFloat(sales_price) : null,
      first_level_discount: first_level_discount ? parseFloat(first_level_discount) : null,
      second_level_discount: second_level_discount ? parseFloat(second_level_discount) : null,
      third_level_discount: third_level_discount ? parseFloat(third_level_discount) : null,
      barcode: barcode.trim() || null,
      part_number: part_number.trim() || null,
      brand_id: brand_id || null,
      expiry_date: expiry_date || null,
      file_path,
    };

    const { error } = await supabase.from('products').insert(row);
    saving = false;

    if (error) {
      saveError = error.message;
      return;
    }

    saveSuccess = 'Product saved successfully!';
    // Reset form
    product_name = '';
    product_type = '';
    applicability = '';
    vehicle_id = '';
    unit_id = '';
    unit_qty = '';
    current_cost = '';
    sales_price = '';
    first_level_discount = '';
    second_level_discount = '';
    third_level_discount = '';
    barcode = '';
    part_number = '';
    brand_id = '';
    expiry_date = '';
    selectedFile = null;
    if (fileInputEl) fileInputEl.value = '';

    setTimeout(() => (saveSuccess = ''), 3000);
  }

  function handleCancel() {
    windowStore.close('products-create-product');
  }
</script>

<div class="create-product-window">
  <!-- ---- Header ---- -->
  <div class="form-header">
    <div class="header-left">
      <button class="back-btn" on:click={handleCancel} title="Back">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>
      <h2>Create Product</h2>
    </div>
  </div>

  <!-- ---- Form Body ---- -->
  <div class="form-body">
    {#if saveError}
      <div class="msg msg-error">{saveError}</div>
    {/if}
    {#if saveSuccess}
      <div class="msg msg-success">{saveSuccess}</div>
    {/if}

    <div class="form-card">
      <!-- Row 1: Product Name + Product Type -->
      <div class="form-row two-col">
        <div class="field">
          <label for="product-name">Product Name</label>
          <input id="product-name" type="text" bind:value={product_name} placeholder="Enter product name" />
        </div>
        <div class="field">
          <label for="product-type">Product Type</label>
          <select id="product-type" bind:value={product_type}>
            <option value="">Select type...</option>
            <option value="product">Product</option>
            <option value="service">Service</option>
            <option value="consumable">Consumable</option>
          </select>
        </div>
      </div>

      <!-- Service message -->
      {#if showServiceMsg}
        <div class="service-notice">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
            <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          <span>Service type is reserved for future use. Select Product or Consumable to continue.</span>
        </div>
      {/if}

      <!-- Applicability (only for product type) -->
      {#if showApplicability}
        <div class="form-row two-col">
          <div class="field">
            <label for="applicability">Applicability</label>
            <select id="applicability" bind:value={applicability}>
              <option value="">Select...</option>
              <option value="universal">Universal</option>
              <option value="specific">Specific</option>
            </select>
          </div>

          <!-- Vehicle (only for specific) -->
          {#if showVehicle}
            <div class="field">
              <SearchableDropdown
                items={vehicles}
                bind:value={vehicle_id}
                placeholder="Select Vehicle"
                label="Vehicle"
                on:add={() => {}}
              />
            </div>
          {:else}
            <div class="field"></div>
          {/if}
        </div>
      {/if}

      <!-- Pricing fields (product or consumable) -->
      {#if showPricingFields}
        <!-- Part Number + Barcode -->
        <div class="form-row two-col">
          <div class="field">
            <label for="part-number">Part Number</label>
            <input id="part-number" type="text" bind:value={part_number} placeholder="Enter part number" />
          </div>
          <div class="field">
            <label for="barcode">Barcode</label>
            <input id="barcode" type="text" bind:value={barcode} placeholder="Enter barcode" />
          </div>
        </div>

        <!-- Expiry Date + Brand -->
        <div class="form-row two-col">
          <div class="field">
            <label for="expiry-date">Expiry Date</label>
            <input id="expiry-date" type="date" bind:value={expiry_date} />
          </div>

          <div class="field">
            <SearchableDropdown
              items={brands}
              bind:value={brand_id}
              placeholder="Select Brand"
              label="Brand"
              on:add={handleAddBrand}
              on:edit={handleEditBrand}
            />
          </div>
        </div>

        <!-- Unit + Unit Qty -->
        <div class="form-row two-col">
          <div class="field">
            <SearchableDropdown
              items={units}
              bind:value={unit_id}
              placeholder="Select Unit"
              label="Unit"
              on:add={handleAddUnit}
              on:edit={handleEditUnit}
            />
          </div>
          <div class="field">
            <label for="unit-qty">Unit Quantity</label>
            <input id="unit-qty" type="number" step="0.01" bind:value={unit_qty} placeholder="0" />
          </div>
        </div>

        <!-- Cost + Sales Price -->
        <div class="form-row two-col">
          <div class="field">
            <label for="current-cost">Current Cost</label>
            <input id="current-cost" type="number" step="0.01" bind:value={current_cost} placeholder="0.00" />
          </div>
          <div class="field">
            <label for="sales-price">Sales Price</label>
            <input id="sales-price" type="number" step="0.01" bind:value={sales_price} placeholder="0.00" />
          </div>
        </div>

        <!-- Discount fields -->
        <div class="form-row three-col">
          <div class="field">
            <label for="d1">First Level Discount %</label>
            <input id="d1" type="number" step="0.01" bind:value={first_level_discount} placeholder="0" />
          </div>
          <div class="field">
            <label for="d2">Second Level Discount %</label>
            <input id="d2" type="number" step="0.01" bind:value={second_level_discount} placeholder="0" />
          </div>
          <div class="field">
            <label for="d3">Third Level Discount %</label>
            <input id="d3" type="number" step="0.01" bind:value={third_level_discount} placeholder="0" />
          </div>
        </div>

        <!-- File Upload -->
        <div class="form-row">
          <div class="field file-field">
            <label>Product File / Image</label>
            <div class="file-upload-area">
              <input
                bind:this={fileInputEl}
                type="file"
                on:change={handleFileSelect}
                class="file-input-hidden"
                id="product-file"
              />
              <label for="product-file" class="file-upload-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                  <polyline points="17 8 12 3 7 8"/>
                  <line x1="12" y1="3" x2="12" y2="15"/>
                </svg>
                Choose File
              </label>
              {#if selectedFile}
                <div class="file-info">
                  <span class="file-name">{selectedFile.name}</span>
                  <span class="file-size">({(selectedFile.size / 1024).toFixed(1)} KB)</span>
                  <button class="file-remove" on:click={removeFile}>&times;</button>
                </div>
              {:else}
                <span class="file-hint">No file selected — any file type allowed</span>
              {/if}
            </div>
          </div>
        </div>
      {/if}
    </div>
  </div>

  <!-- ---- Footer ---- -->
  <div class="form-footer">
    <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    {#if showPricingFields}
      <button class="btn-save" on:click={handleSave} disabled={saving}>
        {saving ? 'Saving...' : 'Save'}
      </button>
    {/if}
  </div>
</div>

<!-- Add Unit Popup -->
{#if addPopupOpen}
  <AddMasterDataPopup
    title={addPopupTitle}
    tableName={addPopupTable}
    on:close={() => (addPopupOpen = false)}
    on:created={handleMasterCreated}
  />
{/if}

<!-- Edit Popup -->
{#if editPopupOpen}
  <EditMasterDataPopup
    title={editPopupTitle}
    tableName={editPopupTable}
    itemId={editPopupItemId}
    itemName={editPopupItemName}
    on:close={() => (editPopupOpen = false)}
    on:updated={handleMasterUpdated}
  />
{/if}

<style>
  .create-product-window {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
  }

  /* ---- Header ---- */
  .form-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .back-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    cursor: pointer;
    color: #374151;
    transition: all 0.15s;
  }

  .back-btn:hover {
    background: #fff7ed;
    border-color: #F97316;
    color: #EA580C;
  }

  .form-header h2 {
    margin: 0;
    font-size: 17px;
    font-weight: 700;
    color: #111827;
  }

  /* ---- Body ---- */
  .form-body {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
  }

  .msg {
    padding: 10px 14px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    margin-bottom: 16px;
  }

  .msg-error {
    background: #fef2f2;
    color: #dc2626;
    border: 1px solid #fecaca;
  }

  .msg-success {
    background: #f0fdf4;
    color: #16a34a;
    border: 1px solid #bbf7d0;
  }

  .form-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 18px;
    max-width: 800px;
  }

  .form-row {
    display: flex;
    gap: 16px;
  }

  .two-col > .field {
    flex: 1;
  }

  .three-col > .field {
    flex: 1;
  }

  .field {
    display: flex;
    flex-direction: column;
  }

  .field label {
    font-size: 12px;
    font-weight: 600;
    color: #374151;
    margin-bottom: 4px;
  }

  .field input[type="text"],
  .field input[type="number"],
  .field select {
    padding: 9px 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 13px;
    outline: none;
    transition: border-color 0.15s;
    background: white;
  }

  .field input:focus,
  .field select:focus {
    border-color: #F97316;
    box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.1);
  }

  .service-notice {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 16px;
    background: #f3e8ff;
    border: 1px solid #e9d5ff;
    border-radius: 8px;
    color: #7c3aed;
    font-size: 13px;
    font-weight: 500;
  }

  /* ---- File Upload ---- */
  .file-field {
    flex: 1;
  }

  .file-upload-area {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .file-input-hidden {
    display: none;
  }

  .file-upload-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 14px;
    background: white;
    border: 1px solid #F97316;
    border-radius: 6px;
    color: #F97316;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }

  .file-upload-btn:hover {
    background: #F97316;
    color: white;
  }

  .file-info {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
  }

  .file-name {
    font-size: 13px;
    font-weight: 500;
    color: #374151;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .file-size {
    font-size: 11px;
    color: #9ca3af;
  }

  .file-remove {
    background: none;
    border: none;
    color: #ef4444;
    font-size: 16px;
    cursor: pointer;
    padding: 0 2px;
    line-height: 1;
  }

  .file-hint {
    font-size: 12px;
    color: #9ca3af;
  }

  /* ---- Footer ---- */
  .form-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    background: white;
    border-top: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .btn-cancel {
    padding: 9px 20px;
    background: #f3f4f6;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
  }

  .btn-cancel:hover {
    background: #e5e7eb;
  }

  .btn-save {
    padding: 9px 28px;
    background: #F97316;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    color: white;
    cursor: pointer;
    transition: background 0.15s;
  }

  .btn-save:hover {
    background: #EA580C;
  }

  .btn-save:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  @media (max-width: 700px) {
    .two-col,
    .three-col {
      flex-direction: column;
    }
  }
</style>
